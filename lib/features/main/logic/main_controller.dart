import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot> getUserDataStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('No user logged in');
    }

    return _firestore.collection('users').doc(userId).snapshots();
  }

  String getDisplayName(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return 'User';

    try {
      return snapshot.get('displayName') ?? 'User';
    } catch (e) {
      return 'User';
    }
  }

  String getAvatar(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return 'ðŸ˜Š';

    try {
      return snapshot.get('avatar') ?? 'ðŸ˜Š';
    } catch (e) {
      return 'ðŸ˜Š';
    }
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}
