import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> completeOnboarding({
    required String displayName,
    required String avatar,
    required int? categoryScore,
    required int? totalScore,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final userRef = _firestore.collection('users').doc(user.uid);

    await userRef.update({
      'displayName': displayName.trim(),
      'avatar': avatar,
      'assessment': categoryScore,
      'assessmentScore': totalScore,
      'currentDay': 0,
      'programStartDate': null,
      'programEndDate': null,
      'currentDayDate': null,
      'lastDayUpdate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await user.updateDisplayName(displayName.trim());
  }
}
