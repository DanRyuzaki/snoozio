import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:snoozio/core/background/background_service_manager.dart' as bg;

class ActivityReminderHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<String> toggleNotification({
    required String activityId,
    required bool enabled,
    required String activityName,
    required String time,
    required int dayNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activity_status')
          .doc(activityId)
          .set({
            'notificationEnabled': enabled,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (enabled) {
        final scheduled =
            await bg.BackgroundServiceManager.scheduleActivityReminder(
              activityId: activityId,
              activityName: activityName,
              time: time,
              dayNumber: dayNumber,
            );

        if (!scheduled) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('activity_status')
              .doc(activityId)
              .set({
                'notificationEnabled': false,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          return 'time_passed';
        }

        return 'success';
      } else {
        await bg.BackgroundServiceManager.cancelActivityReminder(activityId);
        return 'success';
      }
    } catch (e) {
      return 'error';
    }
  }

  static Future<void> scheduleAllRemindersForDay({
    required String carePlan,
    required int currentDay,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    final currentDayDate = (data['currentDayDate'] as Timestamp?)?.toDate();

    if (currentDayDate != null) {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final dayDateMidnight = DateTime(
        currentDayDate.year,
        currentDayDate.month,
        currentDayDate.day,
      );

      if (todayMidnight.isBefore(dayDateMidnight)) {
        debugPrint('⏳ Day $currentDay not ready - NOT scheduling reminders');
        return;
      }
    }

    await bg.BackgroundServiceManager.scheduleAllRemindersForToday('auto', 0);
  }

  static Future<void> cancelAllReminders(int currentDay) async {
    await bg.BackgroundServiceManager.cancelAllReminders();
  }
}
