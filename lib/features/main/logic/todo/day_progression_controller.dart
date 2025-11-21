import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:restart_app/restart_app.dart';
import 'package:snoozio/core/helper/activity_reminder_helper.dart';
import 'package:snoozio/features/main/logic/todo/todo_controller.dart';

class DayProgressionController {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> initializeDayZero() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'currentDay': 0,
      'programStartDate': null,
      'currentDayDate': null,
      'lastDayUpdate': FieldValue.serverTimestamp(),
    });

    debugPrint('âœ… User initialized to Day 0 (Orientation)');
  }

  static Future<void> checkAndAutoAdvanceAtMidnight() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;

    final data = userDoc.data() ?? {};
    final currentDay = data['currentDay'] ?? 0;
    final assessment = data['assessment'] ?? 4;

    if (currentDay == 0 || currentDay >= 30) return;

    String carePlan = _getCarePlan(assessment);

    final canProgress = await _canProgressAtMidnight(carePlan, currentDay);

    if (canProgress) {
      await advanceToNextDay();
      debugPrint('✅ Auto-advanced to Day ${currentDay + 1} at midnight');
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await _firestore.collection('users').doc(user.uid).update({
        'currentDayDate': Timestamp.fromDate(today),
        'lastDayUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint('⏰ Day $currentDay activities re-scheduled for today');
    }
  }

  static Future<bool> _canProgressAtMidnight(
    String carePlan,
    int currentDay,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      return await ToDoLogic.canProgressToNextDay(carePlan, currentDay);
    } catch (e) {
      debugPrint('❌ Error checking midnight progression: $e');
      return false;
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

  static Future<void> startProgram() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final startDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final endDate = startDate.add(const Duration(days: 29));

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};
    final assessment = data['assessment'] ?? 4;

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

    await _firestore.collection('users').doc(user.uid).update({
      'currentDay': 1,
      'programStartDate': Timestamp.fromDate(startDate),
      'programEndDate': Timestamp.fromDate(endDate),
      'currentDayDate': Timestamp.fromDate(startDate),
      'lastDayUpdate': FieldValue.serverTimestamp(),
    });

    await ActivityReminderHelper.scheduleAllRemindersForDay(
      carePlan: carePlan,
      currentDay: 1,
    );

    debugPrint('ðŸ“… Program started! Day 1 begins: ${startDate.toString()}');
    debugPrint('â° Scheduled reminders for Day 1');
  }

  static Future<void> advanceToNextDay() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};

    final currentDay = data['currentDay'] ?? 1;
    final programStartDate = (data['programStartDate'] as Timestamp?)?.toDate();
    final assessment = data['assessment'] ?? 4;

    if (programStartDate == null) {
      throw Exception('Program not started yet');
    }

    if (currentDay >= 30) {
      Restart.restartApp();
    }

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

    final newDay = currentDay + 1;
    final newDayDate = programStartDate.add(Duration(days: newDay - 1));

    await _firestore.collection('users').doc(user.uid).update({
      'currentDay': newDay,
      'currentDayDate': Timestamp.fromDate(newDayDate),
      'lastDayUpdate': FieldValue.serverTimestamp(),
    });

    await ActivityReminderHelper.cancelAllReminders(currentDay);
    await ActivityReminderHelper.scheduleAllRemindersForDay(
      carePlan: carePlan,
      currentDay: newDay,
    );

    debugPrint('âœ… Advanced to Day $newDay (${newDayDate.toString()})');
    debugPrint('â° Scheduled reminders for Day $newDay');
  }

  static Future<void> restartCurrentDay() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};

    final currentDay = data['currentDay'] ?? 1;
    final programStartDate = (data['programStartDate'] as Timestamp?)?.toDate();

    if (programStartDate == null) {
      throw Exception('Program not started yet');
    }

    final today = DateTime.now();
    final newStartDate = today.subtract(Duration(days: currentDay - 1));
    final newEndDate = newStartDate.add(const Duration(days: 29));
    final newCurrentDayDate = today.add(const Duration(days: 1));

    await _firestore.collection('users').doc(user.uid).update({
      'programStartDate': Timestamp.fromDate(newStartDate),
      'programEndDate': Timestamp.fromDate(newEndDate),
      'currentDayDate': Timestamp.fromDate(newCurrentDayDate),
      'lastDayUpdate': FieldValue.serverTimestamp(),
    });

    await _resetDayActivities(user.uid, currentDay);
    await ActivityReminderHelper.cancelAllReminders(currentDay);

    debugPrint('ðŸ”„ Restarted Day $currentDay - now scheduled for tomorrow');
    debugPrint('ðŸš« Cancelled all reminders for Day $currentDay');
  }

  static Future<void> _resetDayActivities(String userId, int dayNumber) async {
    final activityStatusRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('activity_status');

    final snapshot = await activityStatusRef
        .where(
          FieldPath.documentId,
          isGreaterThanOrEqualTo: 'day_${dayNumber}_',
        )
        .where(FieldPath.documentId, isLessThan: 'day_${dayNumber + 1}_')
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': 'pending',
        'completedAt': FieldValue.delete(),
        'missedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint(
      'âœ… Reset ${snapshot.docs.length} activities for Day $dayNumber',
    );
  }

  static Future<bool> isDayReady() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};

    final currentDay = data['currentDay'] ?? 0;

    if (currentDay == 0) return true;

    final currentDayDate = (data['currentDayDate'] as Timestamp?)?.toDate();
    if (currentDayDate == null) return false;

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dayDateMidnight = DateTime(
      currentDayDate.year,
      currentDayDate.month,
      currentDayDate.day,
    );

    return !todayMidnight.isBefore(dayDateMidnight);
  }

  static Future<int> getDaysUntilDayStarts() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};

    final currentDayDate = (data['currentDayDate'] as Timestamp?)?.toDate();
    if (currentDayDate == null) return 0;

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dayDateMidnight = DateTime(
      currentDayDate.year,
      currentDayDate.month,
      currentDayDate.day,
    );

    final difference = dayDateMidnight.difference(todayMidnight).inDays;
    return difference > 0 ? difference : 0;
  }

  static Future<Map<String, dynamic>> getProgramDatesInfo() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data() ?? {};

    return {
      'currentDay': data['currentDay'] ?? 0,
      'programStartDate': (data['programStartDate'] as Timestamp?)?.toDate(),
      'programEndDate': (data['programEndDate'] as Timestamp?)?.toDate(),
      'currentDayDate': (data['currentDayDate'] as Timestamp?)?.toDate(),
    };
  }

  static Future<void> autoCheckDayProgression() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;

    final data = userDoc.data() ?? {};
    final currentDay = data['currentDay'] ?? 0;
    final assessment = data['assessment'] ?? 4;
    final currentDayDate = (data['currentDayDate'] as Timestamp?)?.toDate();

    if (currentDay == 0 || currentDay >= 30 || currentDayDate == null) return;

    String carePlan = _getCarePlan(assessment);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayMidnight = DateTime(
      currentDayDate.year,
      currentDayDate.month,
      currentDayDate.day,
    );

    if (today.isAfter(dayMidnight)) {
      final canProgress = await ToDoLogic.canProgressToNextDay(
        carePlan,
        currentDay,
      );

      if (canProgress) {
        await advanceToNextDay();
        debugPrint('✅ Auto-advanced at app init');
      }
    }
  }
}
