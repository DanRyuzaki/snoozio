import 'dart:isolate';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snoozio/core/background/background_service_manager.dart';
import 'package:snoozio/core/background/background_service_manager.dart' as bg;
import 'package:snoozio/core/background/alarm_sound_service.dart';
import 'package:snoozio/core/notification/notification_debug_helper.dart';
import 'package:snoozio/core/notification/notification_service.dart';
import 'package:snoozio/firebase_options.dart';
import 'package:snoozio/app.dart';
import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:snoozio/features/splashauth/logic/service/auth_service.dart';
import 'package:snoozio/features/main/logic/music/music_player_controller.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 === SNOOZIO APP STARTING ===');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Firebase initialized');

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  await _requestAllPermissions();

  await _initializeNotificationsWithActions();
  debugPrint('Notifications with actions initialized');

  await BackgroundServiceManager.initialize();
  debugPrint('Background services initialized');

  await NotificationService.initialize();
  debugPrint('Notifications initialized');

  await NotificationService.showForegroundNotification();
  debugPrint('Foreground service active');

  _setupAlarmSoundIsolate();
  debugPrint('Alarm sound isolate setup');

  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      debugPrint('👤 User logged in: ${user.uid}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.uid);
      debugPrint('User ID saved: ${user.uid}');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final currentDay = data['currentDay'] ?? 0;
        final currentDayDate = (data['currentDayDate'] as Timestamp?)?.toDate();

        if (currentDay > 0 && currentDayDate != null) {
          final now = DateTime.now();
          final todayMidnight = DateTime(now.year, now.month, now.day);
          final dayDateMidnight = DateTime(
            currentDayDate.year,
            currentDayDate.month,
            currentDayDate.day,
          );

          if (!todayMidnight.isBefore(dayDateMidnight)) {
            await bg.BackgroundServiceManager.scheduleAllRemindersForToday(
              'auto',
              0,
            );
            debugPrint('Reminders scheduled (day is active)');
          } else {
            debugPrint('⏳ Day not ready yet - reminders NOT scheduled');
          }
        }
      }

      await NotificationDebugHelper.printDebugInfo();
    } else {
      debugPrint('👤 No user logged in');
    }
  });

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', currentUser.uid);
    debugPrint('Initial user ID saved: ${currentUser.uid}');
  }

  final musicController = MusicPlayerController();
  musicController.initialize();

  debugPrint('=== SNOOZIO APP READY ===');

  runApp(
    EasyDynamicThemeWidget(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => GoogleAuthService()..initialize(),
          ),
          ChangeNotifierProvider.value(value: musicController),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

Future<void> _initializeNotificationsWithActions() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onNotificationAction,
    onDidReceiveBackgroundNotificationResponse: _onNotificationAction,
  );
}

@pragma('vm:entry-point')
void _onNotificationAction(NotificationResponse response) async {
  debugPrint('Notification action: ${response.actionId}');
  debugPrint('Payload: ${response.payload}');

  final payload = response.payload ?? '';

  if (payload.startsWith('alarm:')) {
    final activityId = payload.substring('alarm:'.length);
    debugPrint('Alarm notification - stopping sound and vibration');

    try {
      await AlarmSoundService.stopAlarmSound();
      debugPrint('Alarm sound stopped via AlarmSoundService');
    } catch (e) {
      debugPrint(' Error stopping alarm sound: $e');

      try {
        const MethodChannel platform = MethodChannel('com.snoozio.app/alarm');
        await platform.invokeMethod('stopAlarmSound');
        debugPrint('Alarm sound stopped via direct method channel');
      } catch (e2) {
        debugPrint(' Error with direct method channel: $e2');
      }
    }

    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.cancel();
        debugPrint('Vibration cancelled');

        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.cancel();
        debugPrint('Vibration double-cancelled (safety)');
      }
    } catch (e) {
      debugPrint(' Error stopping vibration: $e');
    }

    try {
      final notificationId = activityId.hashCode.abs();
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      debugPrint('Notification cancelled: $notificationId');
    } catch (e) {
      debugPrint(' Error cancelling notification: $e');
    }
    Restart.restartApp();
    debugPrint(' Alarm fully dismissed');
  }
}

Future<void> _requestAllPermissions() async {
  debugPrint('=== REQUESTING PERMISSIONS ===');

  if (await Permission.notification.isDenied) {
    final notificationStatus = await Permission.notification.request();
    debugPrint('Notification: $notificationStatus');

    if (notificationStatus.isPermanentlyDenied) {
      debugPrint('Notifications permanently denied. Opening settings...');
      await openAppSettings();
    }
  }

  if (await Permission.scheduleExactAlarm.isDenied) {
    final alarmStatus = await Permission.scheduleExactAlarm.request();
    debugPrint('Exact Alarm: $alarmStatus');

    if (alarmStatus.isPermanentlyDenied) {
      debugPrint('Exact alarms permanently denied. Opening settings...');
      await openAppSettings();
    }
  }

  if (await Permission.ignoreBatteryOptimizations.isDenied) {
    final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
    debugPrint('Battery Optimization: $batteryStatus');
  }

  if (await Permission.systemAlertWindow.isDenied) {
    final drawStatus = await Permission.systemAlertWindow.request();
    debugPrint('🪟 Draw Over Apps: $drawStatus');

    if (drawStatus.isDenied || drawStatus.isPermanentlyDenied) {
      debugPrint('Draw over apps denied - heads-up notifications may not work');
    }
  }

  debugPrint('All permissions requested');
  await _logPermissionStatus();
}

Future<void> _logPermissionStatus() async {
  debugPrint('=== PERMISSION STATUS ===');
  debugPrint('Notification: ${await Permission.notification.status}');
  debugPrint('Exact Alarm: ${await Permission.scheduleExactAlarm.status}');
  debugPrint('Battery: ${await Permission.ignoreBatteryOptimizations.status}');
  debugPrint('Draw Over: ${await Permission.systemAlertWindow.status}');
}

void _setupAlarmSoundIsolate() {
  final receivePort = ReceivePort();
  IsolateNameServer.registerPortWithName(
    receivePort.sendPort,
    'alarm_sound_port',
  );

  receivePort.listen((message) {
    if (message is Map<String, dynamic>) {
      final action = message['action'];
      final alarmId = message['alarmId'];

      if (action == 'play') {
        AlarmSoundService.playAlarmSound(alarmId);
      } else if (action == 'stop') {
        AlarmSoundService.stopAlarmSound();
      }
    }
  });
}
