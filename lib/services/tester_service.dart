// lib/services/tester_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages tester opt-in consent and feedback storage.
///
/// Feedback is written to Firestore anonymously.
/// Each (user, feature) pair can only submit feedback once — enforced
/// via document ID  `{uid}_{featureKey}` so subsequent attempts are no-ops.
///
/// No PII is stored: the UID is only used as a key for deduplication and is
/// never written into the document body.
///
/// After the user has answered all feature prompts, [checkAndMarkCompletion]
/// returns `true` exactly once so the UI knows to show a final "All done!
/// Any future improvements?" dialog. The suggestion is saved via
/// [saveCompletionFeedback].
class TesterService {
  // ── SharedPreferences keys ──────────────────────────────────────────────────
  static const String _keyIsTester = 'tester_is_tester';
  static const String _keyHasSeenConsent = 'tester_has_seen_consent';
  static const String _keyAnsweredFeatures = 'tester_answered_features';
  static const String _keyHasSeenCompletion = 'tester_has_seen_completion';

  // ── Firestore ───────────────────────────────────────────────────────────────
  static const String _collection = 'tester_feedback';

  /// The feature key used for the wrap-up / completion document in Firestore.
  static const String _completionFeatureKey = 'all_done';

  /// All feature keys that count toward "completed all sections".
  /// Must match the featureKey() output of the feature names used in triggers.
  static const List<String> allFeatureKeys = [
    'food_bank_map',
    'shelter_map',
    'resource_map',
    'community_contribution',
    'help_request',
    'language_change',
  ];

  // Singleton
  static final TesterService _instance = TesterService._internal();
  factory TesterService() => _instance;
  TesterService._internal();

  // ── Consent ──────────────────────────────────────────────────────────────────

  Future<bool> hasSeenConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenConsent) ?? false;
  }

  Future<bool> isTester() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsTester) ?? false;
  }

  Future<void> setConsentResponse({required bool agreed}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenConsent, true);
    await prefs.setBool(_keyIsTester, agreed);
  }

  /// Resets everything — for testing purposes.
  Future<void> resetTesterStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsTester);
    await prefs.remove(_keyHasSeenConsent);
    await prefs.remove(_keyAnsweredFeatures);
    await prefs.remove(_keyHasSeenCompletion);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  /// Converts a feature name to a safe Firestore key segment.
  /// e.g. "Food Bank Map" → "food_bank_map"
  String featureKey(String feature) =>
      feature.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  // ── Feedback ─────────────────────────────────────────────────────────────────

  /// Returns true if this user has already submitted feedback for [feature].
  Future<bool> hasAlreadyAnswered(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> answered =
        prefs.getStringList(_keyAnsweredFeatures) ?? [];
    return answered.contains(featureKey(feature));
  }

  /// Returns the list of feature keys the user has already answered.
  Future<List<String>> answeredFeatureKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyAnsweredFeatures) ?? [];
  }

  /// Returns true if the user has answered feedback for every feature in
  /// [allFeatureKeys]. Note: a user who opened only food banks and shelters
  /// (but not the generic map) will see "resource_map" as unanswered, which
  /// is fine — completion requires all paths.
  ///
  /// Map group: done if ANY of the three map variants is answered.
  /// All other features must each be individually answered.
  Future<bool> hasCompletedAllFeatures() async {
    final answered = await answeredFeatureKeys();
    final mapDone = answered.contains('food_bank_map') ||
        answered.contains('shelter_map') ||
        answered.contains('resource_map');
    final othersDone = answered.contains('community_contribution') &&
        answered.contains('help_request') &&
        answered.contains('language_change');
    return mapDone && othersDone;
  }

  /// Marks a feature as answered in local cache.
  Future<void> _markAnswered(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> answered =
        prefs.getStringList(_keyAnsweredFeatures) ?? [];
    final key = featureKey(feature);
    if (!answered.contains(key)) {
      answered.add(key);
      await prefs.setStringList(_keyAnsweredFeatures, answered);
    }
  }

  /// Saves feedback anonymously to Firestore.
  ///
  /// Returns `false` if the user has already submitted feedback for this
  /// feature, or if no authenticated user is present.
  Future<bool> saveFeedback({
    required String feature,
    required bool helpful,
    String? comment,
  }) async {
    // Fast local check first
    if (await hasAlreadyAnswered(feature)) {
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return false;
    }

    final docId = '${uid}_${featureKey(feature)}';

    try {
      final docRef =
          FirebaseFirestore.instance.collection(_collection).doc(docId);

      // Check Firestore in case device was cleared
      final existing = await docRef.get();
      if (existing.exists) {
        await _markAnswered(feature);
        return false;
      }

      // Write anonymously — UID is in the doc ID only, not the body
      await docRef.set({
        'feature': feature,
        'helpful': helpful,
        'comment': (comment?.trim().isEmpty ?? true) ? null : comment?.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _markAnswered(feature);
      return true;
    } catch (e) {
      print('❌ [TesterService] Failed to save feedback: $e');
      return false;
    }
  }

  // ── Completion / Wrap-up ──────────────────────────────────────────────────────

  /// Returns true if the completion survey has already been triggered.
  Future<bool> hasSeenCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenCompletion) ?? false;
  }

  /// Call this immediately after every successful [saveFeedback].
  ///
  /// Returns `true` exactly once — the first time the user has completed all
  /// required feature sections — so the calling UI knows to display the
  /// "All done! Any future improvements?" dialog.
  ///
  /// Subsequent calls always return `false` (latch behaviour).
  Future<bool> checkAndMarkCompletion() async {
    if (await hasSeenCompletion()) return false;
    if (!await hasCompletedAllFeatures()) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenCompletion, true);
    return true;
  }

  /// Saves the optional wrap-up suggestion to Firestore.
  ///
  /// [suggestion] is the user's answer to "Any future improvements?".
  /// Passing `null` or an empty string is fine — it records completion without
  /// a suggestion.
  ///
  /// Returns `false` if the document already exists or no authenticated user
  /// is present.
  Future<bool> saveCompletionFeedback({String? suggestion}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final docId = '${uid}_$_completionFeatureKey';

    try {
      final docRef =
          FirebaseFirestore.instance.collection(_collection).doc(docId);

      final existing = await docRef.get();
      if (existing.exists) return false;

      await docRef.set({
        'feature': _completionFeatureKey,
        'suggestion':
            (suggestion?.trim().isEmpty ?? true) ? null : suggestion?.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('❌ [TesterService] Failed to save completion feedback: $e');
      return false;
    }
  }
}