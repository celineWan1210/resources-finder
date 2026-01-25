import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save a contribution to Firestore
  Future<String> addContribution(Map<String, dynamic> contribution) async {
      try {
        // Add user info to the contribution
        final user = _auth.currentUser;
        if (user != null) {
          contribution['userId'] = user.uid;
          contribution['userEmail'] = user.email;
        }

        // Add to Firestore
        DocumentReference docRef = await _db
            .collection('contributions')
            .add(contribution);
        
        return docRef.id; // Return the Firestore document ID
      } catch (e) {
        print('Error adding contribution: $e');
        rethrow;
      }
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