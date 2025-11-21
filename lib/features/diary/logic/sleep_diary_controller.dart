import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum SleepQuality { poor, moderate, good }

class SleepDiaryEntry {
  final String id;
  final DateTime date;
  final DateTime bedtime;
  final DateTime wakeTime;
  final SleepQuality quality;
  final List<String> disturbances;
  final String? notes;
  final double sleepEfficiency;

  SleepDiaryEntry({
    required this.id,
    required this.date,
    required this.bedtime,
    required this.wakeTime,
    required this.quality,
    required this.disturbances,
    this.notes,
    required this.sleepEfficiency,
  });

  factory SleepDiaryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SleepDiaryEntry(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      bedtime: (data['bedtime'] as Timestamp).toDate(),
      wakeTime: (data['wakeTime'] as Timestamp).toDate(),
      quality: SleepQuality.values[data['quality'] ?? 1],
      disturbances: List<String>.from(data['disturbances'] ?? []),
      notes: data['notes'],
      sleepEfficiency: (data['sleepEfficiency'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'bedtime': Timestamp.fromDate(bedtime),
      'wakeTime': Timestamp.fromDate(wakeTime),
      'quality': quality.index,
      'disturbances': disturbances,
      'notes': notes,
      'sleepEfficiency': sleepEfficiency,
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class SleepDiaryController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> getSleepDiaryEntries({int limit = 7}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }

    return _firestore
        .collection('sleepDiary')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<DocumentSnapshot?> getTodayEntry() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final querySnapshot = await _firestore
        .collection('sleepDiary')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
  }

  Future<void> saveSleepDiaryEntry(SleepDiaryEntry entry) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('No user logged in');

    if (entry.id.isEmpty) {
      await _firestore.collection('sleepDiary').add(entry.toFirestore());
    } else {
      await _firestore
          .collection('sleepDiary')
          .doc(entry.id)
          .update(entry.toFirestore());
    }
  }

  double calculateSleepEfficiency(DateTime bedtime, DateTime wakeTime) {
    final duration = wakeTime.difference(bedtime);
    final hoursSlept = duration.inMinutes / 60;

    if (hoursSlept <= 0 || hoursSlept > 24) {
      return 0.0;
    }

    const optimalMin = 7.0;
    const optimalMax = 9.0;

    double efficiency;

    if (hoursSlept >= optimalMin && hoursSlept <= optimalMax) {
      efficiency = 100.0;
    } else if (hoursSlept < optimalMin) {
      efficiency = (hoursSlept / optimalMin) * 100;
    } else {
      final excessHours = hoursSlept - optimalMax;
      efficiency = 100.0 - (excessHours * 10);
    }

    return efficiency.clamp(0.0, 100.0);
  }

  SleepQuality getSleepQualityFromEfficiency(double efficiency) {
    if (efficiency >= 85) return SleepQuality.good;
    if (efficiency >= 60) return SleepQuality.moderate;
    return SleepQuality.poor;
  }

  int getColorForQuality(SleepQuality quality) {
    switch (quality) {
      case SleepQuality.good:
        return 0xFF4CAF50;
      case SleepQuality.moderate:
        return 0xFFFF9800;
      case SleepQuality.poor:
        return 0xFFF44336;
    }
  }

  String getEmojiForQuality(SleepQuality quality) {
    switch (quality) {
      case SleepQuality.good:
        return '😴';
      case SleepQuality.moderate:
        return '😐';
      case SleepQuality.poor:
        return '😫';
    }
  }

  List<String> getCommonDisturbances() {
    return [
      'Worries/Stress',
      'Napping during day',
      'Phone usage before bed',
      'Noise',
      'Temperature',
      'Pain/Discomfort',
      'Nightmares',
      'Bathroom trips',
      'Other(s)',
    ];
  }
}
