import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save a contribution to Firestore
  Future<void> addContribution(Map<String, dynamic> contribution) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _db.collection('contributions').add({
      ...contribution,
      'userId': user.uid,
      'userEmail': user.email,
    });
  }

  /// Get contributions by current user
  Stream<QuerySnapshot> getUserContributions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('contributions')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get all active contributions (for map view)
  Stream<QuerySnapshot> getAllActiveContributions() {
    return _db
        .collection('contributions')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  /// Update contribution status
  Future<void> updateContributionStatus(String docId, String status) async {
    await _db.collection('contributions').doc(docId).update({
      'status': status,
    });
  }

  /// Delete a contribution
  Future<void> deleteContribution(String docId) async {
    await _db.collection('contributions').doc(docId).delete();
  }
}