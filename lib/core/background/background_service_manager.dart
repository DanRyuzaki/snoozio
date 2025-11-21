import 'dart:typed_data';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:isolate';
import 'dart:ui';
import 'package:vibration/vibration.dart';
import 'package:snoozio/core/background/alarm_sound_service.dart';

class BackgroundServiceManager {
  static const String _portName = 'snoozio_isolate_port';
  static const int _midnightCheckAlarmId = 0;
  static const int _activityReminderBaseId = 1000;
  static const int _testAlarmId = 4242;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      debugPrint('🔥 === INITIALIZING BACKGROUND SERVICES ===');

      await AndroidAlarmManager.initialize();
      debugPrint('✅ Alarm Manager initialized');

      await _initializeNotifications();
      debugPrint('✅ Notifications initialized');

      await _createForegroundServiceNotification();
      debugPrint('✅ Foreground service notification active');

      await _scheduleMidnightCheck();
      debugPrint('✅ Midnight check scheduled');

      await _scheduleAllRemindersForToday();
      debugPrint('✅ Today\'s reminders scheduled');

      debugPrint('🎉 === BACKGROUND SERVICES READY ===');
    } catch (e, stackTrace) {
      debugPrint('❌ Initialize error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
    );

    const activityChannel = AndroidNotificationChannel(
      'activity_reminders_sound',
      'Activity Reminders',
      description: 'Reminders for daily sleep activities',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );

    const alarmChannel = AndroidNotificationChannel(
      'alarms_channel',
      'Alarms',
      description: 'Full-screen alarms with snooze and dismiss',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      showBadge: false,
      enableLights: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(activityChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannel);

    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  static Future<void> _createForegroundServiceNotification() async {
    try {
      const serviceChannel = AndroidNotificationChannel(
        'background_service',
        'Background Service',
        description: 'Keeps reminders running in background',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(serviceChannel);

      const androidDetails = AndroidNotificationDetails(
        'background_service',
        'Background Service',
        channelDescription: 'Keeps reminders running in background',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        styleInformation: DefaultStyleInformation(true, true),
      );

      await _notificationsPlugin.show(
        888,
        'Snoozio',
        'Sleep reminders are active',
        const NotificationDetails(android: androidDetails),
      );

      debugPrint('✅ Foreground service notification created');
    } catch (e) {
      debugPrint('❌ Error creating foreground notification: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) async {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    debugPrint('Action ID: ${response.actionId}');

    final payload = response.payload ?? '';

    if (payload.startsWith('alarm:')) {
      final activityId = payload.substring('alarm:'.length);
      debugPrint('⏰ Alarm notification detected: $activityId');

      try {
        await AlarmSoundService.stopAlarmSound();
        debugPrint('✅ Alarm sound stopped via AlarmSoundService');
      } catch (e) {
        debugPrint('❌ Error stopping alarm sound: $e');
      }

      try {
        if (await Vibration.hasVibrator()) {
          await Vibration.cancel();
          debugPrint('✅ Vibration stopped');
        }
      } catch (e) {
        debugPrint('❌ Error stopping vibration: $e');
      }

      try {
        final notificationId = activityId.hashCode.abs();
        await _notificationsPlugin.cancel(notificationId);
        debugPrint('✅ Notification cancelled: $notificationId');
      } catch (e) {
        debugPrint('❌ Error cancelling notification: $e');
      }

      try {
        final alarmId =
            _activityReminderBaseId + activityId.hashCode.abs() % 10000;
        await AndroidAlarmManager.cancel(alarmId);
        debugPrint('✅ Alarm schedule cancelled: $alarmId');
      } catch (e) {
        debugPrint('❌ Error cancelling alarm schedule: $e');
      }

      debugPrint('🛑 Alarm fully dismissed: $activityId');
    } else {
      debugPrint("it doesn't start with alarm: else, it is $payload");
    }
  }

  static Future<void> _scheduleMidnightCheck() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);

    await AndroidAlarmManager.oneShotAt(
      midnight,
      _midnightCheckAlarmId,
      midnightCheckCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );

    debugPrint('⏰ Midnight check scheduled for: $midnight');
  }

  static Future<void> _scheduleAllRemindersForToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        debugPrint('⚠️ No userId, skipping');
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final currentDay = userData['currentDay'] ?? 0;
      final currentDayDate = (userData['currentDayDate'] as Timestamp?)
          ?.toDate();

      if (currentDay == 0) return;

      if (currentDayDate != null) {
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final dayDateMidnight = DateTime(
          currentDayDate.year,
          currentDayDate.month,
          currentDayDate.day,
        );

        if (todayMidnight.isBefore(dayDateMidnight)) {
          debugPrint(
            '⏳ Day $currentDay not ready yet. Scheduled for: $dayDateMidnight',
          );
          return;
        }
      }

      final assessment = userData['assessment'] ?? 4;
      String carePlan = _getCarePlan(assessment);

      debugPrint('📅 Scheduling reminders for Day $currentDay ($carePlan)');

      final dayDoc = await firestore
          .collection('care_plans')
          .doc(carePlan)
          .collection('v1')
          .doc('day_$currentDay')
          .get();

      if (!dayDoc.exists) {
        debugPrint('⚠️ Day document not found');
        return;
      }

      final activities = dayDoc.data()!['activities'] as List;
      int scheduledCount = 0;

      for (int i = 0; i < activities.length; i++) {
        final activity = activities[i];
        final activityId = 'day_${currentDay}_$i';

        final statusDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('activity_status')
            .doc(activityId)
            .get();

        final notificationEnabled = statusDoc.exists
            ? (statusDoc.data()?['notificationEnabled'] ?? true)
            : true;

        if (notificationEnabled) {
          await _scheduleActivityAlarm(
            activityId: activityId,
            activityName: activity['activity'],
            time: activity['time'],
            dayNumber: currentDay,
          );
          scheduledCount++;
        }
      }

      debugPrint('✅ Scheduled $scheduledCount reminders');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling reminders: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<void> _scheduleActivityAlarm({
    required String activityId,
    required String activityName,
    required String time,
    required int dayNumber,
    bool isManualToggle = false,
  }) async {
    try {
      final scheduledTime = _parseTimeString(time);

      if (scheduledTime == null) {
        debugPrint('⚠️ Could not parse time: $time');
        return;
      }

      final now = DateTime.now();

      if (scheduledTime.isBefore(now)) {
        if (!isManualToggle) {
          debugPrint('⏭️ Time passed: $activityName at $time');
        }
        return;
      }

      final alarmId =
          _activityReminderBaseId + activityId.hashCode.abs() % 10000;

      final scheduled = await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        alarmId,
        activityReminderCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
        params: {
          'activityId': activityId,
          'activityName': activityName,
          'dayNumber': dayNumber,
        },
      );

      if (scheduled) {
        final prefs = await SharedPreferences.getInstance();
        final alarmIds = prefs.getStringList('scheduled_alarm_ids') ?? [];
        if (!alarmIds.contains(alarmId.toString())) {
          alarmIds.add(alarmId.toString());
          await prefs.setStringList('scheduled_alarm_ids', alarmIds);
        }

        debugPrint(
          '✅ SCHEDULED: $activityName at $scheduledTime (ID: $alarmId)',
        );
        debugPrint(
          '⏰ Time until alarm: ${scheduledTime.difference(now).inMinutes} min',
        );
      } else {
        debugPrint('❌ Failed to schedule: $activityName');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static DateTime? _parseTimeString(String timeStr) {
    try {
      final match = RegExp(
        r'(\d+):(\d+)\s*(am|pm)',
        caseSensitive: false,
      ).firstMatch(timeStr);
      if (match == null) return null;

      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final isPM = match.group(3)!.toLowerCase() == 'pm';

      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  static String _getCarePlan(int assessment) {
    switch (assessment) {
      case 1:
        return 'mild';
      case 2:
        return 'moderate';
      case 3:
        return 'severe';
      case 0:
        return 'normal';
      default:
        return 'unassigned';
    }
  }

  static Future<bool> scheduleActivityReminder({
    required String activityId,
    required String activityName,
    required String time,
    required int dayNumber,
  }) async {
    final scheduledTime = _parseTimeString(time);
    if (scheduledTime == null) return false;
    if (scheduledTime.isBefore(DateTime.now())) return false;

    await _scheduleActivityAlarm(
      activityId: activityId,
      activityName: activityName,
      time: time,
      dayNumber: dayNumber,
      isManualToggle: true,
    );

    return true;
  }

  static Future<bool> scheduleAlarm({
    required String activityId,
    required String activityName,
    required String time,
    required int dayNumber,
    int snoozeMinutes = 5,
  }) async {
    try {
      final scheduledTime = _parseTimeString(time);
      if (scheduledTime == null) return false;
      if (scheduledTime.isBefore(DateTime.now())) return false;

      final alarmId =
          _activityReminderBaseId + activityId.hashCode.abs() % 10000;
      final ok = await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        alarmId,
        alarmTriggerCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
        params: {
          'activityId': activityId,
          'activityName': activityName,
          'dayNumber': dayNumber,
          'type': 'alarm',
          'snoozeMinutes': snoozeMinutes,
        },
      );
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        final alarmIds = prefs.getStringList('scheduled_alarm_ids') ?? [];
        if (!alarmIds.contains(alarmId.toString())) {
          alarmIds.add(alarmId.toString());
          await prefs.setStringList('scheduled_alarm_ids', alarmIds);
        }
        debugPrint('⏰ Scheduled ALARM $activityName at $scheduledTime');
        return true;
      }
      return false;
    } catch (e, st) {
      debugPrint('❌ scheduleAlarm error: $e');
      debugPrint('Stack: $st');
      return false;
    }
  }

  static Future<void> cancelActivityReminder(String activityId) async {
    try {
      final alarmId =
          _activityReminderBaseId + activityId.hashCode.abs() % 10000;
      await AndroidAlarmManager.cancel(alarmId);

      final notificationId = activityId.hashCode.abs();
      await _notificationsPlugin.cancel(notificationId);

      final prefs = await SharedPreferences.getInstance();
      final alarmIds = prefs.getStringList('scheduled_alarm_ids') ?? [];
      alarmIds.remove(alarmId.toString());
      await prefs.setStringList('scheduled_alarm_ids', alarmIds);

      debugPrint('🚫 Cancelled: $activityId');
    } catch (e) {
      debugPrint('❌ Cancel error: $e');
    }
  }

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    debugPrint('✅ User ID saved: $userId');
  }

  static void registerIsolatePort(ReceivePort port) {
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(port.sendPort, _portName);
  }

  static Future<void> cancelAllReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmIds = prefs.getStringList('scheduled_alarm_ids') ?? [];

      for (final idStr in alarmIds) {
        try {
          await AndroidAlarmManager.cancel(int.parse(idStr));
        } catch (e) {
          debugPrint('⚠️ Error cancelling $idStr: $e');
        }
      }

      await prefs.remove('scheduled_alarm_ids');
      debugPrint('✅ Cancelled ${alarmIds.length} reminders');
    } catch (e) {
      debugPrint('❌ Cancel all error: $e');
    }
  }

  static Future<void> scheduleAllRemindersForToday(
    String carePlan,
    int currentDay,
  ) async {
    await _scheduleAllRemindersForToday();
  }

  static Future<void> scheduleOneShotTest({int secondsFromNow = 60}) async {
    try {
      final when = DateTime.now().add(Duration(seconds: secondsFromNow));
      final ok = await AndroidAlarmManager.oneShotAt(
        when,
        _testAlarmId,
        activityReminderCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
        params: {
          'activityId': 'test_alarm',
          'activityName': 'Test Heads-up',
          'dayNumber': 0,
        },
      );
      debugPrint('⏳ Test alarm scheduled=$ok at $when (in ${secondsFromNow}s)');
    } catch (e, stackTrace) {
      debugPrint('❌ scheduleOneShotTest error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<void> dumpPermissionsAndSettings() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final androidImpl = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final enabled = await androidImpl?.areNotificationsEnabled();
      final notifGranted = await androidImpl?.requestNotificationsPermission();
      final exactGranted = await androidImpl?.requestExactAlarmsPermission();
      final pending = await plugin.pendingNotificationRequests();

      debugPrint('🔧 Notifications enabled (system): $enabled');
      debugPrint('🔧 Notifications permission (request): $notifGranted');
      debugPrint('🔧 Exact alarms permission (request): $exactGranted');
      debugPrint('🔧 Pending notifications count: ${pending.length}');
    } catch (e, stackTrace) {
      debugPrint('❌ dumpPermissionsAndSettings error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}

@pragma('vm:entry-point')
Future<void> alarmTriggerCallback(
  int alarmId,
  Map<String, dynamic> params,
) async {
  debugPrint('⏰ ⏰ ⏰ ALARM TRIGGERED! ID: $alarmId ⏰ ⏰ ⏰');

  try {
    final activityId = params['activityId'] as String;
    final activityName = (params['activityName'] as String?) ?? 'Alarm';

    try {
      final sendPort = IsolateNameServer.lookupPortByName('alarm_sound_port');
      if (sendPort != null) {
        sendPort.send({'action': 'play', 'alarmId': activityId});
        debugPrint('🎵 Alarm sound play request sent to main isolate');
      } else {
        debugPrint('⚠️ Alarm sound port not found - sound will not play');
      }
    } catch (e) {
      debugPrint('❌ Error sending alarm sound request: $e');
    }

    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 1000, 500], repeat: -1);
        debugPrint('📳 Vibration started (single pattern)');
      }
    } catch (e) {
      debugPrint('❌ Error starting vibration: $e');
    }

    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    await notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse:
          BackgroundServiceManager._onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          BackgroundServiceManager._onNotificationTapped,
    );
    debugPrint('✅ Notifications plugin initialized');

    const alarmChannel = AndroidNotificationChannel(
      'alarms_channel',
      'Alarms',
      description: 'Full-screen alarms',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(alarmChannel);
    debugPrint('✅ Notification channel created');

    final androidDetails = AndroidNotificationDetails(
      'alarms_channel',
      'Alarms',
      channelDescription: 'Full-screen alarms',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableVibration: false,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      enableLights: true,
      ledColor: const Color(0xFFFF0000),
      ledOnMs: 1000,
      ledOffMs: 500,
      actions: const [
        AndroidNotificationAction(
          'alarm_dismiss',
          'DISMISS',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
      styleInformation: BigTextStyleInformation(
        '🔔 Tap to dismiss alarm',
        contentTitle: '⏰ $activityName',
        summaryText: 'Alarm ringing',
        htmlFormatBigText: true,
      ),
    );

    final notificationId = activityId.hashCode.abs();

    await notificationsPlugin.show(
      notificationId,
      '⏰ $activityName',
      'Tap to dismiss',
      NotificationDetails(android: androidDetails),
      payload: 'alarm:$activityId',
    );

    debugPrint('✅ Alarm notification shown with ID: $notificationId');
    debugPrint('🎵 Alarm sound & vibration looping until dismissed');
  } catch (e, st) {
    debugPrint('❌ Alarm trigger error: $e');
    debugPrint('Stack: $st');
  }
}

@pragma('vm:entry-point')
Future<void> activityReminderCallback(
  int alarmId,
  Map<String, dynamic> params,
) async {
  debugPrint('🔔 🔔 🔔 ALARM TRIGGERED! ID: $alarmId 🔔 🔔 🔔');

  try {
    final activityId = params['activityId'] as String;
    final activityName = params['activityName'] as String;
    final dayNumber = params['dayNumber'] as int;

    final notificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    await notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    const activityChannel = AndroidNotificationChannel(
      'activity_reminders_sound',
      'Activity Reminders',
      description: 'Reminders for daily sleep activities',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(activityChannel);

    final androidDetails = AndroidNotificationDetails(
      'activity_reminders_sound',
      'Activity Reminders',
      channelDescription: 'Reminders for daily sleep activities',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([
        0,
        500,
        200,
        500,
        200,
        500,
        200,
        500,
      ]),
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      fullScreenIntent: false,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: '🌙 Time for your sleep activity!',
      ongoing: false,
      autoCancel: false,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      channelShowBadge: true,
      onlyAlertOnce: false,
      enableLights: true,
      ledColor: const Color(0xFF6C5CE7),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(
        activityName,
        contentTitle: '🌙 Day $dayNumber - Snoozio Activity',
        summaryText: 'Snoozio Reminder',
      ),
      actions: const [
        AndroidNotificationAction(
          'open_app',
          'View Activity',
          showsUserInterface: true,
        ),
      ],
    );

    final notificationId = activityId.hashCode.abs();

    await notificationsPlugin.show(
      notificationId,
      '🌙 Day $dayNumber - Sleep Activity',
      activityName,
      NotificationDetails(android: androidDetails),
      payload: 'activity:$activityId',
    );

    debugPrint('✅ ✅ ✅ NOTIFICATION SHOWN: $activityName');
    debugPrint('Notification ID: $notificationId');
  } catch (e, stackTrace) {
    debugPrint('❌ Activity reminder error: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

@pragma('vm:entry-point')
Future<void> midnightCheckCallback() async {
  debugPrint('🌙 Midnight check triggered');

  try {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);

    await AndroidAlarmManager.oneShotAt(
      midnight,
      0,
      midnightCheckCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );

    debugPrint('✅ Rescheduled midnight check for: $midnight');
  } catch (e, stackTrace) {
    debugPrint('❌ Midnight check error: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}
