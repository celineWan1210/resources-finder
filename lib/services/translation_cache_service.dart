import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class TranslationCacheService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'translations';
  
  /// Generate unique hash for cache key
  String _getCacheKey(String text, String targetLang) {
    final content = '$text|$targetLang';
    return md5.convert(utf8.encode(content)).toString();
  }
  
  /// Get cached translation from Firestore
  Future<String?> getCachedTranslation(String text, String targetLang) async {
    if (text.isEmpty || targetLang == 'auto') return null;
    
    final cacheKey = _getCacheKey(text, targetLang);
    
    try {
      // Try local cache first
      final doc = await _firestore
          .collection(_collection)
          .doc(cacheKey)
          .get(const GetOptions(source: Source.cache)); 
      
      if (doc.exists && doc.data()?['translated'] != null) {
        return doc.data()?['translated'] as String;
      }
      
      // If not in cache, fetch from server
      final serverDoc = await _firestore
          .collection(_collection)
          .doc(cacheKey)
          .get(const GetOptions(source: Source.server));
      
      if (serverDoc.exists && serverDoc.data()?['translated'] != null) {
        return serverDoc.data()?['translated'] as String;  // ✅ FIXED: Use serverDoc, not doc
      }
    } catch (e) {
      // Firestore might be unavailable, that's OK - we'll use API instead
    }
    
    return null;
  }

    /// Delete all bad translations where original == translated (failed translations)
  Future<void> deleteBadTranslations(String targetLang) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('targetLang', isEqualTo: targetLang)
          .get();
      
      int deleted = 0;
      final batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['original'] == data['translated']) {
          print('🗑️ Deleting bad translation: ${data['original']}');
          batch.delete(doc.reference);
          deleted++;
        }
      }
      
      if (deleted > 0) {
        await batch.commit();
        print('✅ Deleted $deleted bad $targetLang translations');
      } else {
        print('✅ No bad $targetLang translations found');
      }
    } catch (e) {
      print('❌ Error deleting bad translations: $e');
    }
  }

  Future<void> saveTranslation(
    String originalText,
    String targetLang,
    String translatedText,
  ) async {
    if (originalText.isEmpty || translatedText.isEmpty) return;
    
    final cacheKey = _getCacheKey(originalText, targetLang);
    
    try {
      await _firestore.collection(_collection).doc(cacheKey).set({
        'original': originalText,
        'translated': translatedText,
        'targetLang': targetLang,
        'cachedAt': FieldValue.serverTimestamp(),
        'charCount': originalText.length,
      }, SetOptions(merge: true));
      
      // Don't log preview - causes RangeError
    } catch (e) {
      // App will still work using API
    }
  }
  /// Clear old cache (optional - run monthly to save storage)
  Future<void> clearOldCache({int daysOld = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final oldDocs = await _firestore
          .collection(_collection)
          .where('cachedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .limit(500) // Delete in batches
          .get();
      
      final batch = _firestore.batch();
      for (var doc in oldDocs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('🗑️ Deleted ${oldDocs.docs.length} old translations');
    } catch (e) {
      print('Cache cleanup error: $e');
    }
  }
}