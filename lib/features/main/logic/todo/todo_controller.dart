import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ToDoLogic {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String formatDayString(String rawDay) {
    if (!rawDay.toLowerCase().startsWith('day_')) {
      throw FormatException('Invalid care plan format');
    }
    String formatted = rawDay.replaceAll('_', ' ');
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  static Future<String> getUserCarePlan() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) throw Exception('User document not found.');

    final data = userDoc.data() ?? {};
    final assessment = data['assessment'] ?? 4;

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

  static Future<bool> canProgressToNextDay(
    String carePlan,
    int currentDay,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');

    final dayDoc = await _firestore
        .collection('care_plans')
        .doc(carePlan)
        .collection('v1')
        .doc('day_$currentDay')
        .get();

    if (!dayDoc.exists) return false;

    final dayData = dayDoc.data()!;
    final activities = (dayData['activities'] as List)
        .cast<Map<String, dynamic>>();
    final totalActivities = activities.length;

    if (totalActivities == 0) return true;

    int validActivities = 0;

    for (int i = 0; i < totalActivities; i++) {
      final activityId = getActivityId('day_$currentDay', i);
      final statusDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activity_status')
          .doc(activityId)
          .get();

      if (statusDoc.exists) {
        final status = statusDoc['status'] as String;

        if (status == 'done' || status == 'skipped') {
          validActivities++;
        }
      }
    }

    final completionRate = validActivities / totalActivities;
    return completionRate >= 0.8;
  }

  static Future<int> getCurrentDay() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) throw Exception('User document not found.');

    final data = userDoc.data() ?? {};
    return data['currentDay'] ?? 1;
  }

  static Stream<QuerySnapshot> getCarePlanDaysStream(String carePlan) {
    return _firestore
        .collection('care_plans')
        .doc(carePlan)
        .collection('v1')
        .orderBy(FieldPath.documentId)
        .snapshots();
  }

  static String getActivityId(String dayId, int activityIndex) {
    return '${dayId}_$activityIndex';
  }

  static Stream<DocumentSnapshot> getActivityStatusStream(String activityId) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activity_status')
        .doc(activityId)
        .snapshots();
  }

  static Future<void> updateActivityStatus({
    required String activityId,
    required String status,
    Timestamp? completedAt,
    Timestamp? missedAt,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');

    final data = {'status': status, 'updatedAt': FieldValue.serverTimestamp()};

    if (completedAt != null) data['completedAt'] = completedAt;
    if (missedAt != null) data['missedAt'] = missedAt;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activity_status')
        .doc(activityId)
        .set(data, SetOptions(merge: true));
  }

  static Future<void> toggleNotification({
    required String activityId,
    required bool enabled,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activity_status')
        .doc(activityId)
        .set({
          'notificationEnabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  static bool isActivityMissed(String timeString) {
    try {
      final now = DateTime.now();
      final parts = timeString.split(':');

      if (parts.length != 2) return false;

      final hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].split(' ')[0].trim());
      final isPm = timeString.toLowerCase().contains('pm');

      var scheduledHour = hour;
      if (isPm && hour != 12) {
        scheduledHour += 12;
      } else if (!isPm && hour == 12) {
        scheduledHour = 0;
      }

      final scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        scheduledHour,
        minute,
      );

      final difference = now.difference(scheduled);
      return difference.inMinutes > 60;
    } catch (e) {
      return false;
    }
  }

  static ActivitySection getActivitySection({
    required String status,
    required String timeString,
    required bool isCurrentActivity,
    bool notificationEnabled = true,
  }) {
    if (!notificationEnabled && status == 'pending') {
      return ActivitySection.disabled;
    }

    if (status == 'done' || status == 'skipped') {
      return ActivitySection.completed;
    }

    if (status == 'missed' ||
        (status == 'pending' && isActivityMissed(timeString))) {
      return ActivitySection.missed;
    }

    if (isCurrentActivity) {
      return ActivitySection.current;
    }

    return ActivitySection.upcoming;
  }

  static Future<void> evaluateAndAdvanceDay(
    String carePlan,
    int currentDay,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');
    final userDocRef = _firestore.collection('users').doc(user.uid);

    final dayDoc = await _firestore
        .collection('care_plans')
        .doc(carePlan)
        .collection('v1')
        .doc('day_$currentDay')
        .get();

    if (!dayDoc.exists) return;

    final dayData = dayDoc.data()!;
    final activities = (dayData['activities'] as List)
        .cast<Map<String, dynamic>>();
    final totalActivities = activities.length;

    int completedCount = 0;
    for (int i = 0; i < totalActivities; i++) {
      final activityId = getActivityId('day_$currentDay', i);
      final statusDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activity_status')
          .doc(activityId)
          .get();

      if (statusDoc.exists && statusDoc['status'] == 'done') {
        completedCount++;
      }
    }

    final completionRate = completedCount / totalActivities;

    if (completionRate >= 0.8) {
      await userDocRef.update({
        'currentDay': currentDay + 1,
        'lastProgressUpdate': FieldValue.serverTimestamp(),
      });
    } else {
      await userDocRef.update({
        'lastProgressUpdate': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<DayCompletionStats> getDayCompletionStats(
    String carePlan,
    int currentDay,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user.');

    final dayDoc = await _firestore
        .collection('care_plans')
        .doc(carePlan)
        .collection('v1')
        .doc('day_$currentDay')
        .get();

    if (!dayDoc.exists) {
      return DayCompletionStats(
        total: 0,
        completed: 0,
        skipped: 0,
        missed: 0,
        pending: 0,
      );
    }

    final dayData = dayDoc.data()!;
    final activities = (dayData['activities'] as List)
        .cast<Map<String, dynamic>>();
    final totalActivities = activities.length;

    int completedCount = 0;
    int skippedCount = 0;
    int missedCount = 0;
    int pendingCount = 0;

    for (int i = 0; i < totalActivities; i++) {
      final activityId = getActivityId('day_$currentDay', i);
      final statusDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activity_status')
          .doc(activityId)
          .get();

      if (statusDoc.exists) {
        final status = statusDoc['status'] as String;
        switch (status) {
          case 'done':
            completedCount++;
            break;
          case 'skipped':
            skippedCount++;
            break;
          case 'missed':
            missedCount++;
            break;
          default:
            pendingCount++;
        }
      } else {
        pendingCount++;
      }
    }

    return DayCompletionStats(
      total: totalActivities,
      completed: completedCount,
      skipped: skippedCount,
      missed: missedCount,
      pending: pendingCount,
    );
  }

  static List<Map<String, dynamic>> parseActivities(
    Map<String, dynamic> dayData,
  ) {
    final activitiesList = dayData['activities'] as List<dynamic>? ?? [];
    return activitiesList
        .map((activity) => activity as Map<String, dynamic>)
        .toList();
  }
}

class DayCompletionStats {
  final int total;
  final int completed;
  final int skipped;
  final int missed;
  final int pending;

  DayCompletionStats({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.pending,
  });

  double get completionRate => total > 0 ? completed / total : 0.0;
  double get totalRate => total > 0 ? (completed + skipped) / total : 0.0;
  bool get canAdvance => completionRate >= 0.8;
  int get remaining => total - (completed + skipped + missed);
}

enum ActivitySection { current, upcoming, completed, missed, disabled }

class ActivityModel {
  final String activity;
  final String time;

  ActivityModel({required this.activity, required this.time});

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    return ActivityModel(
      activity: map['activity'] ?? 'No activity',
      time: map['time'] ?? 'No time',
    );
  }

  Map<String, dynamic> toMap() {
    return {'activity': activity, 'time': time};
  }
}

class ActivityStatus {
  final String status;
  final bool notificationEnabled;
  final Timestamp? completedAt;
  final Timestamp? missedAt;

  ActivityStatus({
    required this.status,
    required this.notificationEnabled,
    this.completedAt,
    this.missedAt,
  });

  factory ActivityStatus.fromFirestore(DocumentSnapshot? doc) {
    if (doc == null || !doc.exists) {
      return ActivityStatus(status: 'pending', notificationEnabled: true);
    }

    final data = doc.data() as Map<String, dynamic>;
    return ActivityStatus(
      status: data['status'] ?? 'pending',
      notificationEnabled: data['notificationEnabled'] ?? true,
      completedAt: data['completedAt'],
      missedAt: data['missedAt'],
    );
  }
}

class DayModel {
  final String dayId;
  final String formattedDay;
  final List<ActivityModel> activities;

  DayModel({
    required this.dayId,
    required this.formattedDay,
    required this.activities,
  });

  factory DayModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dayId = doc.id;
    final formattedDay = ToDoLogic.formatDayString(dayId);
    final activitiesData = data['activities'] as List<dynamic>? ?? [];
    final activities = activitiesData
        .map(
          (activity) => ActivityModel.fromMap(activity as Map<String, dynamic>),
        )
        .toList();

    return DayModel(
      dayId: dayId,
      formattedDay: formattedDay,
      activities: activities,
    );
  }
}
