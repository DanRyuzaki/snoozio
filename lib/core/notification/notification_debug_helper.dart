import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snoozio/core/notification/notification_service.dart';

class NotificationDebugHelper {
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> debugInfo = {
      'timestamp': DateTime.now().toString(),
      'user': {
        'authenticated': user != null,
        'uid': user?.uid,
        'email': user?.email,
      },
      'sharedPreferences': {
        'userId': prefs.getString('userId'),
        'scheduledNotifications': prefs.getStringList(
          'scheduled_notifications',
        ),
      },
      'pendingNotifications': [],
      'userDocument': {},
      'todayActivities': [],
    };

    try {
      final pending = await NotificationService.getPendingNotifications();
      debugInfo['pendingNotifications'] = pending
          .map(
            (n) => {
              'id': n.id,
              'title': n.title,
              'body': n.body,
              'payload': n.payload,
            },
          )
          .toList();
    } catch (e) {
      debugInfo['pendingNotificationsError'] = e.toString();
    }

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          debugInfo['userDocument'] = {
            'currentDay': data['currentDay'],
            'assessment': data['assessment'],
            'programStartDate': (data['programStartDate'] as Timestamp?)
                ?.toDate()
                .toString(),
            'currentDayDate': (data['currentDayDate'] as Timestamp?)
                ?.toDate()
                .toString(),
          };

          final currentDay = data['currentDay'] ?? 0;
          final assessment = data['assessment'] ?? 4;
          final carePlan = _getCarePlan(assessment);

          if (currentDay > 0) {
            final dayDoc = await FirebaseFirestore.instance
                .collection('care_plans')
                .doc(carePlan)
                .collection('v1')
                .doc('day_$currentDay')
                .get();

            if (dayDoc.exists) {
              final activities = dayDoc.data()!['activities'] as List;

              for (int i = 0; i < activities.length; i++) {
                final activity = activities[i];
                final activityId = 'day_${currentDay}_$i';

                final statusDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('activity_status')
                    .doc(activityId)
                    .get();

                final notificationEnabled = statusDoc.exists
                    ? (statusDoc.data()?['notificationEnabled'] ?? true)
                    : true;

                debugInfo['todayActivities'].add({
                  'index': i,
                  'activityId': activityId,
                  'name': activity['activity'],
                  'time': activity['time'],
                  'notificationEnabled': notificationEnabled,
                  'status': statusDoc.exists
                      ? statusDoc.data() != null
                            ? ['status']
                            : 'pending'
                      : 'error',
                  'shouldBeScheduled':
                      notificationEnabled && !_isTimePassed(activity['time']),
                });
              }
            }
          }
        }
      } catch (e) {
        debugInfo['userDocumentError'] = e.toString();
      }
    }

    return debugInfo;
  }

  static Future<void> printDebugInfo() async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('🔍 NOTIFICATION DEBUG INFO');
    debugPrint('═══════════════════════════════════════════');

    final info = await getDebugInfo();

    debugPrint('');
    debugPrint('⏰ Timestamp: ${info['timestamp']}');
    debugPrint('');

    debugPrint('👤 USER INFO:');
    debugPrint('  - Authenticated: ${info['user']['authenticated']}');
    debugPrint('  - UID: ${info['user']['uid']}');
    debugPrint('  - Email: ${info['user']['email']}');
    debugPrint('');

    debugPrint('💾 SHARED PREFERENCES:');
    debugPrint('  - userId: ${info['sharedPreferences']['userId']}');
    debugPrint(
      '  - Scheduled count: ${(info['sharedPreferences']['scheduledNotifications'] as List?)?.length ?? 0}',
    );
    debugPrint('');

    debugPrint('🔔 PENDING NOTIFICATIONS:');
    final pending = info['pendingNotifications'] as List;
    if (pending.isEmpty) {
      debugPrint('  ⚠️ NO PENDING NOTIFICATIONS!');
    } else {
      debugPrint('  ✅ Total pending: ${pending.length}');
      for (final notif in pending) {
        debugPrint('    - ID: ${notif['id']} | ${notif['title']}');
      }
    }
    debugPrint('');

    debugPrint('📄 USER DOCUMENT:');
    if (info['userDocumentError'] != null) {
      debugPrint('  ❌ Error: ${info['userDocumentError']}');
    } else {
      final doc = info['userDocument'] as Map<String, dynamic>;
      debugPrint('  - Current Day: ${doc['currentDay']}');
      debugPrint('  - Assessment: ${doc['assessment']}');
      debugPrint('  - Current Day Date: ${doc['currentDayDate']}');
    }
    debugPrint('');

    debugPrint('📋 TODAY\'S ACTIVITIES:');
    final activities = info['todayActivities'] as List;
    if (activities.isEmpty) {
      debugPrint('  ⚠️ NO ACTIVITIES FOUND!');
    } else {
      debugPrint('  Total activities: ${activities.length}');
      for (final activity in activities) {
        final icon = activity['shouldBeScheduled'] ? '✅' : '❌';
        debugPrint('  $icon ${activity['name']}');
        debugPrint('      - Time: ${activity['time']}');
        debugPrint('      - Enabled: ${activity['notificationEnabled']}');
        debugPrint('      - Status: ${activity['status']}');
        debugPrint('      - Should schedule: ${activity['shouldBeScheduled']}');
      }
    }
    debugPrint('');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('');
  }

  static Future<bool> verifyNotificationsScheduled() async {
    final info = await getDebugInfo();
    final activities = info['todayActivities'] as List;
    final pending = info['pendingNotifications'] as List;

    int shouldBeScheduled = 0;
    for (final activity in activities) {
      if (activity['shouldBeScheduled'] == true) {
        shouldBeScheduled++;
      }
    }

    debugPrint('');
    debugPrint('🔍 VERIFICATION:');
    debugPrint('  - Activities that should be scheduled: $shouldBeScheduled');
    debugPrint('  - Actually pending: ${pending.length}');
    debugPrint('  - Match: ${shouldBeScheduled == pending.length}');
    debugPrint('');

    return shouldBeScheduled == pending.length;
  }

  static Future<void> forceRescheduleAll() async {
    debugPrint('');
    debugPrint('🔄 FORCE RESCHEDULING ALL NOTIFICATIONS...');
    debugPrint('');

    try {
      await NotificationService.cancelAllNotifications();
      debugPrint('✅ Cancelled all existing notifications');

      await NotificationService.scheduleAllRemindersForToday();
      debugPrint('✅ Rescheduled today\'s reminders');

      await Future.delayed(const Duration(milliseconds: 500));

      await printDebugInfo();
      final verified = await verifyNotificationsScheduled();

      if (verified) {
        debugPrint('✅ VERIFICATION PASSED: Notifications properly scheduled');
      } else {
        debugPrint(
          '❌ VERIFICATION FAILED: Mismatch in scheduled notifications',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR DURING RESCHEDULE: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    debugPrint('');
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

  static bool _isTimePassed(String timeString) {
    try {
      final now = DateTime.now();
      final match = RegExp(
        r'(\d+):(\d+)\s*(am|pm)',
        caseSensitive: false,
      ).firstMatch(timeString);

      if (match == null) return false;

      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final isPM = match.group(3)!.toLowerCase() == 'pm';

      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }

      final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      return now.isAfter(scheduled);
    } catch (e) {
      return false;
    }
  }
}
