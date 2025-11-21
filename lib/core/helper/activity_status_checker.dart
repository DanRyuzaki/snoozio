import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityStatusChecker {
  static const int _statusCheckAlarmId = 9999;
  static const Duration _checkInterval = Duration(minutes: 30);

  static Future<void> initialize() async {
    try {
      await _schedulePeriodicCheck();
      debugPrint('✅ 30-minute status checker initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize status checker: $e');
    }
  }

  static Future<void> _schedulePeriodicCheck() async {
    await AndroidAlarmManager.periodic(
      _checkInterval,
      _statusCheckAlarmId,
      _statusCheckCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    debugPrint('⏰ Status checker scheduled (every 30 minutes)');
  }

  @pragma('vm:entry-point')
  static Future<void> _statusCheckCallback() async {
    debugPrint('🔍 Running 30-minute activity status check...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        debugPrint('⚠️ No user ID found in SharedPreferences');
        return;
      }

      final firestore = FirebaseFirestore.instance;

      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found');
        return;
      }

      final userData = userDoc.data()!;
      final currentDay = userData['currentDay'] ?? 0;

      if (currentDay == 0) {
        debugPrint('ℹ️ User on Day 0, skipping check');
        return;
      }

      final assessment = userData['assessment'] ?? 4;
      String carePlan;
      switch (assessment) {
        case 1:
          carePlan = 'mild';
          break;
        case 2:
          carePlan = 'moderate';
          break;
        case 3:
          carePlan = 'severe';
          break;
        case 0:
          carePlan = 'normal';
          break;
        default:
          carePlan = 'unassigned';
      }

      final currentDayDate = (userData['currentDayDate'] as Timestamp?)
          ?.toDate();
      if (currentDayDate == null) {
        debugPrint('⚠️ No current day date found');
        return;
      }

      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final dayDateMidnight = DateTime(
        currentDayDate.year,
        currentDayDate.month,
        currentDayDate.day,
      );

      if (todayMidnight.isBefore(dayDateMidnight)) {
        debugPrint('ℹ️ Day $currentDay not ready yet');
        return;
      }

      final dayDoc = await firestore
          .collection('care_plans')
          .doc(carePlan)
          .collection('v1')
          .doc('day_$currentDay')
          .get();

      if (!dayDoc.exists) {
        debugPrint('⚠️ Day $currentDay not found in $carePlan');
        return;
      }

      final activities = dayDoc.data()!['activities'] as List;
      int missedCount = 0;

      for (int i = 0; i < activities.length; i++) {
        final activity = activities[i];
        final activityId = 'day_${currentDay}_$i';
        final timeString = activity['time'] as String;

        final statusDoc = await firestore
            .collection('users')
            .doc(userId)
            .collection('activity_status')
            .doc(activityId)
            .get();

        final currentStatus = statusDoc.exists
            ? (statusDoc.data()?['status'] ?? 'pending')
            : 'pending';

        if (currentStatus != 'pending') continue;

        if (_isActivityMissed(timeString, now)) {
          await firestore
              .collection('users')
              .doc(userId)
              .collection('activity_status')
              .doc(activityId)
              .set({
                'status': 'missed',
                'missedAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'autoMarkedByChecker': true,
              }, SetOptions(merge: true));

          missedCount++;
          debugPrint('🔴 Auto-marked as missed: ${activity['activity']}');
        }
      }

      if (missedCount > 0) {
        debugPrint(
          '✅ Status check complete: $missedCount activities marked as missed',
        );
      } else {
        debugPrint('✅ Status check complete: All activities up to date');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in status check: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static bool _isActivityMissed(String timeString, DateTime now) {
    try {
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
      final difference = now.difference(scheduled);
      return difference.inMinutes > 60;
    } catch (e) {
      debugPrint('❌ Error parsing time "$timeString": $e');
      return false;
    }
  }

  static Future<void> runManualCheck() async {
    debugPrint('🔍 Manual status check triggered');
    await _statusCheckCallback();
  }

  static Future<void> cancel() async {
    try {
      await AndroidAlarmManager.cancel(_statusCheckAlarmId);
      debugPrint('🚫 Status checker cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling status checker: $e');
    }
  }

  static Future<void> reschedule() async {
    await cancel();
    await initialize();
    debugPrint('🔄 Status checker rescheduled');
  }
}
