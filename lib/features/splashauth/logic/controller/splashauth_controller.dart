import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../service/auth_service.dart';

class SplashController {
  final GoogleAuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SplashController(this._authService);

  Future<String> checkInitialRoute() async {
    await Future.delayed(const Duration(seconds: 2));
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return '/login';
    }
    final assessmentValue = await _getAssessmentValue(currentUser.uid);
    return _determineRoute(assessmentValue);
  }

  Future<String?> signInWithGoogle(BuildContext context) async {
    final userCredential = await _authService.signInWithGoogle(context);

    if (userCredential == null) {
      return null;
    }

    final assessmentValue = await _getAssessmentValue(userCredential.user!.uid);
    return _determineRoute(assessmentValue);
  }

  Future<String?> signInAsGuest() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      await _createGuestDocument(userCredential.user!.uid);
      return '/assessment';
    } catch (e) {
      debugPrint('Error signing in as guest: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<int?> _getAssessmentValue(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        debugPrint('User document not found for $uid');
        return null;
      }

      final data = doc.data();
      final assessment = data?['assessment'];

      if (assessment is int) {
        return assessment;
      } else if (assessment is bool) {
        return assessment ? 0 : 4;
      }

      return 4;
    } catch (e) {
      debugPrint('Error getting assessment value: $e');
      return null;
    }
  }

  String _determineRoute(int? assessmentValue) {
    if (assessmentValue == null) {
      return '/login';
    }

    return assessmentValue <= 3 ? '/main' : '/assessment';
  }

  Future<void> _createGuestDocument(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'isGuest': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'assessment': 4,
      });
      debugPrint('Created guest document for $uid');
    } catch (e) {
      debugPrint('Error creating guest document: $e');
      rethrow;
    }
  }
}
