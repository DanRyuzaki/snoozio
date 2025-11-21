import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot> getUserDataStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }
    return _firestore.collection('users').doc(userId).snapshots();
  }

  int getCurrentDay(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return 1;
    try {
      return snapshot.get('currentDay') ?? 1;
    } catch (e) {
      return 1;
    }
  }

  DateTime? getCreatedAt(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return null;
    try {
      Timestamp timestamp = snapshot.get('createdAt');
      return timestamp.toDate();
    } catch (e) {
      return null;
    }
  }

  DateTime? getPredictedEndDate(DateTime? createdAt, int currentDay) {
    if (createdAt == null) return null;

    final today = DateTime.now();
    final remainingDays = 30 - currentDay;

    return today.add(Duration(days: remainingDays));
  }

  DateTime? getActualEndDate(DateTime? startDate) {
    if (startDate == null) return null;
    return startDate.add(const Duration(days: 29));
  }

  DateTime? getProgramEndDate(DocumentSnapshot snapshot) {
    final programStartDate = (snapshot.get('programStartDate') as Timestamp?)
        ?.toDate();
    if (programStartDate != null) {
      return programStartDate.add(const Duration(days: 29));
    }

    final startDate = getCreatedAt(snapshot);
    return getActualEndDate(startDate);
  }

  List<DateTime> getWeekDates(DateTime currentDate) {
    final startOfWeek = currentDate.subtract(
      Duration(days: currentDate.weekday - 1),
    );
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  bool isToday(DateTime date) {
    final today = DateTime.now();
    return _isSameDay(date, today);
  }

  bool isCompleted(DateTime date, DateTime? createdAt) {
    if (createdAt == null) return false;

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    return !date.isBefore(_startOfDay(createdAt)) &&
        !date.isAfter(_startOfDay(yesterday));
  }

  bool isUpcoming(DateTime date, DateTime? createdAt, int currentDay) {
    if (createdAt == null) return false;

    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final predictedEnd = getPredictedEndDate(createdAt, currentDay);

    if (predictedEnd == null) return false;

    return !date.isBefore(_startOfDay(tomorrow)) &&
        !date.isAfter(_startOfDay(predictedEnd));
  }

  bool isInCarePlanRange(DateTime date, DateTime? createdAt) {
    if (createdAt == null) return false;

    final endDate = getActualEndDate(createdAt);
    if (endDate == null) return false;

    return !date.isBefore(_startOfDay(createdAt)) &&
        !date.isAfter(_startOfDay(endDate));
  }

  int? getDayNumber(DateTime date, DateTime? createdAt) {
    if (createdAt == null) return null;

    final difference = date.difference(_startOfDay(createdAt)).inDays;
    final dayNumber = difference + 1;

    if (dayNumber >= 1 && dayNumber <= 30) {
      return dayNumber;
    }

    return null;
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<String> getDailyQuote(int currentDay) async {
    try {
      final querySnapshot = await _firestore
          .collection('quotes')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return "Stay committed to your sleep journey!";
      }

      final latestDoc = querySnapshot.docs.first;
      final quotesArray = latestDoc.get('quotes') as List<dynamic>;

      final quoteIndex = currentDay - 1;

      if (quoteIndex >= 0 && quoteIndex < quotesArray.length) {
        return quotesArray[quoteIndex].toString();
      }

      return "Keep going! You're doing great!";
    } catch (e) {
      return "Stay committed to your sleep journey!";
    }
  }

  int getIncompleteTasksCount(QuerySnapshot snapshot) {
    return snapshot.docs.where((doc) {
      try {
        return doc.get('isCompleted') == false;
      } catch (e) {
        return true;
      }
    }).length;
  }

  Future<void> updateAssessmentToNormal() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }
    await _firestore.collection('users').doc(userId).update({'assessment': 4});
  }
}
