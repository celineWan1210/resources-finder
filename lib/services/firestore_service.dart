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

  /// Delete a contribution and adjust user warnings
  Future<void> deleteContribution(String docId) async {
    try {
      // Get the contribution data before deleting
      final doc = await _db.collection('contributions').doc(docId).get();
      
      if (!doc.exists) return;
      
      final data = doc.data();
      final userId = data?['userId'];
      final moderationStatus = data?['moderationStatus'];
      final riskScore = data?['riskScore'];
      
      // Delete the contribution
      await _db.collection('contributions').doc(docId).delete();
      
      // If this was a violation (flagged/rejected/approved with risk), reduce warnings
      if (userId != null && 
          userId != 'anonymous' && 
          riskScore != null &&
          (moderationStatus == 'flagged' || moderationStatus == 'rejected' || moderationStatus == 'approved')) {
        
        await _decrementUserWarnings(userId, riskScore);
      }
    } catch (e) {
      print('Error deleting contribution: $e');
      rethrow;
    }
  }

  /// Delete a help request and adjust user warnings
  Future<void> deleteHelpRequest(String docId) async {
    try {
      // Get the help request data before deleting
      final doc = await _db.collection('help_requests').doc(docId).get();
      
      if (!doc.exists) return;
      
      final data = doc.data();
      final userId = data?['userId'];
      final moderationStatus = data?['moderationStatus'];
      final riskScore = data?['riskScore'];
      
      // Delete the help request
      await _db.collection('help_requests').doc(docId).delete();
      
      // If this was a violation, reduce warnings
      if (userId != null && 
          userId != 'anonymous' && 
          riskScore != null &&
          (moderationStatus == 'flagged' || moderationStatus == 'rejected' || moderationStatus == 'approved')) {
        
        await _decrementUserWarnings(userId, riskScore);
      }
    } catch (e) {
      print('Error deleting help request: $e');
      rethrow;
    }
  }

  /// Decrement user warning count when a violation is deleted
  Future<void> _decrementUserWarnings(String userId, String riskScore) async {
    try {
      final userRef = _db.collection('users').doc(userId);
      
      // HIGH risk gave 2 warnings, MEDIUM/LOW gave 1 warning
      final warningDecrement = riskScore == 'high' ? 2 : 1;
      
      await _db.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) return;
        
        final currentWarnings = userDoc.data()?['warningCount'] ?? 0;
        final isBlacklisted = userDoc.data()?['blacklisted'] == true;
        
        // Calculate new warning count (don't go below 0)
        final newWarningCount = (currentWarnings - warningDecrement).clamp(0, double.infinity).toInt();
        
        Map<String, dynamic> updateData = {
          'warningCount': newWarningCount,
        };
        
        // If they were blacklisted but now have less than 3 warnings, unblacklist them
        if (isBlacklisted && newWarningCount < 3) {
          updateData['blacklisted'] = false;
          updateData['autoUnblackedAt'] = FieldValue.serverTimestamp();
          updateData['autoUnblackedReason'] = 'Violation deleted - warnings reduced below threshold';
          print('✅ User $userId auto-unblacklisted (warnings reduced to $newWarningCount)');
        }
        
        transaction.update(userRef, updateData);
        
        print('📉 User $userId warnings reduced by $warningDecrement (${currentWarnings} → $newWarningCount)');
      });
    } catch (e) {
      print('⚠️ Failed to decrement user warnings: $e');
      // Don't throw - this shouldn't block the deletion
    }
  }
}