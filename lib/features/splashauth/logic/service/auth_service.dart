import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignInAccount? _googleUser;

  User? get currentUser => _auth.currentUser;
  GoogleSignInAccount? get googleUser => _googleUser;

  Future<void> initialize({String? clientId, String? serverClientId}) async {
    await GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );

    GoogleSignIn.instance.authenticationEvents.listen((event) {
      _googleUser = switch (event) {
        GoogleSignInAuthenticationEventSignIn() => event.user,
        GoogleSignInAuthenticationEventSignOut() => null,
      };
      notifyListeners();
    });
  }

  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        debugPrint('Platform requires platform-specific sign-in UI');
        return null;
      }

      await GoogleSignIn.instance.authenticate();

      await _waitForGoogleUser();
      if (_googleUser == null) {
        debugPrint('Sign-in was canceled');
        return null;
      }

      final googleAuth = _googleUser!.authentication;
      if (googleAuth.idToken == null) {
        debugPrint('Failed to get idToken');
        return null;
      }

      final authorization = await _googleUser!.authorizationClient
          .authorizationForScopes(['email']);

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: authorization?.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final success = await _createOrUpdateUserDocument(
        userCredential.user!,
        _googleUser!,
      );

      if (!success) {
        await _auth.currentUser?.delete();
        await signOut();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to connect to servers. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return null;
      }

      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> _waitForGoogleUser() async {
    int attempts = 0;
    while (_googleUser == null && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
  }

  Future<bool> _createOrUpdateUserDocument(
    User user,
    GoogleSignInAccount googleAccount,
  ) async {
    final userDoc = _firestore.collection('users').doc(user.uid);

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          await userDoc.set({
            'uid': user.uid,
            'email': user.email,
            'displayName': googleAccount.displayName ?? user.displayName,
            'photoURL': googleAccount.photoUrl ?? user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'assessment': 4,
          });
          debugPrint('Created new user document for ${user.uid}');
        } else {
          await userDoc.update({'lastLoginAt': FieldValue.serverTimestamp()});
          debugPrint('Updated last login for ${user.uid}');
        }

        return true;
      } on FirebaseException catch (e) {
        debugPrint('Firestore error (${e.code}), attempt ${attempt + 1}/3');
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('Unexpected error: $e');
        return false;
      }
    }

    debugPrint('Firestore failed after 3 attempts');
    return false;
  }
}
