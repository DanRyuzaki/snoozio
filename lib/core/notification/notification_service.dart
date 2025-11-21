import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:snoozio/core/background/alarm_sound_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snoozio/core/background/background_service_manager.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('🔔 Initializing Notification Service...');

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationTapped,
    );

    await _requestPermissions();

    await _createNotificationChannels();

    _initialized = true;
    debugPrint('✅ Notification Service initialized');
  }

  static Future<void> _requestPermissions() async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final notificationGranted = await androidImplementation
        ?.requestNotificationsPermission();
    debugPrint('📬 Notification permission: $notificationGranted');

    final alarmGranted = await androidImplementation
        ?.requestExactAlarmsPermission();
    debugPrint('⏰ Exact alarm permission: $alarmGranted');
  }

  static Future<void> _createNotificationChannels() async {
    const activityChannel = AndroidNotificationChannel(
      'activity_reminders',
      'Activity Reminders',
      description: 'Reminders for daily sleep activities',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );

    const foregroundChannel = AndroidNotificationChannel(
      'foreground_service',
      'Background Service',
      description: 'Keeps app running for scheduled notifications',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(activityChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(foregroundChannel);

    debugPrint('✅ Notification channels created');
  }

  static Future<void> showForegroundNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'foreground_service',
      'Background Service',
      channelDescription: 'Keeps app running for scheduled notifications',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );

    await _notifications.show(
      888,
      'Snoozio',
      'Sleep reminders are active',
      const NotificationDetails(android: androidDetails),
    );

    debugPrint('✅ Foreground service notification shown');
  }

  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');

    if (userId != null) {
      debugPrint('✅ Got userId from SharedPreferences: $userId');
      return userId;
    }

    userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      debugPrint(
        '⚠️ Got userId from FirebaseAuth (SharedPreferences was null): $userId',
      );

      await prefs.setString('userId', userId);
      return userId;
    }

    debugPrint('❌ No userId found in SharedPreferences or FirebaseAuth');
    return null;
  }

  static Future<bool> scheduleActivityReminder({
    required String activityId,
    required String activityName,
    required String time,
    required int dayNumber,
  }) async {
    try {
      final ok = await BackgroundServiceManager.scheduleActivityReminder(
        activityId: activityId,
        activityName: activityName,
        time: time,
        dayNumber: dayNumber,
      );
      if (ok) {
        final notificationId = activityId.hashCode.abs();
        await _storeScheduledNotification(notificationId, activityId);
        debugPrint(
          '✅ SCHEDULED (AlarmManager): $activityName at $time (ID: $notificationId)',
        );
      } else {
        debugPrint(
          '❌ Failed to schedule via AlarmManager: $activityName at $time',
        );
      }
      return ok;
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling (AlarmManager): $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  static Future<void> cancelActivityReminder(String activityId) async {
    try {
      await BackgroundServiceManager.cancelActivityReminder(activityId);
      final notificationId = activityId.hashCode.abs();
      await _removeScheduledNotification(notificationId);
      debugPrint('🚫 Cancelled reminder (AlarmManager): $activityId');
    } catch (e) {
      debugPrint('❌ Error cancelling reminder: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await BackgroundServiceManager.cancelAllReminders();
      await _notifications.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('scheduled_notifications');
      debugPrint('🚫 All reminders and notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling all reminders/notifications: $e');
    }
  }

  static Future<void> scheduleAllRemindersForToday() async {
    try {
      final userId = await _getUserId();

      if (userId == null) {
        debugPrint('❌ Cannot schedule reminders: No user ID found');
        return;
      }

      debugPrint('📅 Scheduling reminders for user: $userId');

      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        debugPrint('❌ User document not found for: $userId');
        return;
      }

      final userData = userDoc.data()!;
      final currentDay = userData['currentDay'] ?? 0;
      final currentDayDate = (userData['currentDayDate'] as Timestamp?)
          ?.toDate();

      if (currentDay == 0) {
        debugPrint('ℹ️ User on Day 0, no reminders to schedule');
        return;
      }

      if (currentDayDate != null) {
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final dayDateMidnight = DateTime(
          currentDayDate.year,
          currentDayDate.month,
          currentDayDate.day,
        );

        if (todayMidnight.isBefore(dayDateMidnight)) {
          debugPrint('⏳ Day $currentDay not ready yet - NOT scheduling');
          debugPrint('📅 Day starts on: $dayDateMidnight');
          return;
        }
      }

      final assessment = userData['assessment'] ?? 4;
      final carePlan = _getCarePlan(assessment);

      debugPrint('📅 Scheduling reminders for Day $currentDay ($carePlan)');

      final dayDoc = await firestore
          .collection('care_plans')
          .doc(carePlan)
          .collection('v1')
          .doc('day_$currentDay')
          .get();

      if (!dayDoc.exists) {
        debugPrint('❌ Day document not found: day_$currentDay in $carePlan');
        return;
      }

      final activities = dayDoc.data()!['activities'] as List;
      int scheduledCount = 0;
      int skippedCount = 0;

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
          final scheduled = await scheduleActivityReminder(
            activityId: activityId,
            activityName: activity['activity'],
            time: activity['time'],
            dayNumber: currentDay,
          );

          if (scheduled) {
            scheduledCount++;
          } else {
            skippedCount++;
          }
        } else {
          debugPrint('⏭️ Skipped (disabled): ${activity['activity']}');
          skippedCount++;
        }
      }

      debugPrint('✅ Scheduled $scheduledCount reminders for today');
      if (skippedCount > 0) {
        debugPrint(
          '⏭️ Skipped $skippedCount reminders (disabled or time passed)',
        );
      }

      final pending = await getPendingNotifications();
      debugPrint('📋 Total pending notifications: ${pending.length}');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling reminders: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  static Future<void> logPendingNotifications() async {
    final pending = await getPendingNotifications();
    debugPrint('📋 Pending notifications: ${pending.length}');
    for (final notification in pending) {
      debugPrint('  - ID: ${notification.id}, Title: ${notification.title}');
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

  static Future<void> _storeScheduledNotification(
    int notificationId,
    String activityId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduled = prefs.getStringList('scheduled_notifications') ?? [];
    scheduled.add('$notificationId:$activityId');
    await prefs.setStringList('scheduled_notifications', scheduled);
  }

  static Future<void> _removeScheduledNotification(int notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduled = prefs.getStringList('scheduled_notifications') ?? [];
    scheduled.removeWhere((item) => item.startsWith('$notificationId:'));
    await prefs.setStringList('scheduled_notifications', scheduled);
  }

  static Future<void> _onNotificationTapped(
    NotificationResponse response,
  ) async {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    await AlarmSoundService.stopAlarmSound();
    debugPrint('✅ Alarm sound stopped via AlarmSoundService');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Background notification tapped: ${response.payload}');
  }
}
