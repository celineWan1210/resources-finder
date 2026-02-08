// lib/services/translation_service.dart
import 'package:flutter/foundation.dart';
import 'translation_cache_service.dart';
import 'libre_translate_service.dart';

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final TranslationCacheService _cacheService = TranslationCacheService();
  final LibreTranslateService _translateApi = LibreTranslateService();
  
  // In-memory cache for super-fast repeated access
  final Map<String, String> _memoryCache = {};
  
  String _preferredLanguage = 'auto';
  bool _showTranslated = false;

  String get preferredLanguage => _preferredLanguage;
  bool get showTranslated => _showTranslated;

  void setPreferredLanguage(String lang) {
    _preferredLanguage = lang;
    notifyListeners();
  }

  void toggleTranslation() {
    _showTranslated = !_showTranslated;
    notifyListeners();
  }

  void clearCache() {
    _memoryCache.clear();
    notifyListeners();
  }

  /// Main translation method with 3-tier caching
/// Main translation method with 3-tier caching
    Future<String> translate(String text, String targetLang) async {
      print('🔧 TranslationService.translate called - text: "$text", targetLang: "$targetLang"');
      
      if (text.isEmpty || targetLang == 'auto') return text;
      
      final cacheKey = '$text|$targetLang';
        
      // ⚡ TIER 1: Memory cache (instant)
      if (_memoryCache.containsKey(cacheKey)) {
        print('🔧 Found in MEMORY cache: "$text"');  // ← ADD THIS
        return _memoryCache[cacheKey]!;
      }
      
      // 🔥 TIER 2: Firestore cache (fast, shared across users)
      final cached = await _cacheService.getCachedTranslation(text, targetLang);
      if (cached != null) {
        print('🔧 Found in FIRESTORE cache: "$text" → "$cached"');  // ← ADD THIS
        _memoryCache[cacheKey] = cached;
        return cached;
      }
      
      print('🔧 NOT in cache, calling API for: "$text"');  // ← ADD THIS
      
      // 🌐 TIER 3: API call (slow, only for new content)
      final previewLength = text.length < 50 ? text.length : 50;
      print('🔄 Translating new text: ${text.substring(0, previewLength)}...');
      final translated = await _translateApi.translate(text, targetLang);
      
      // Save to all caches
      _memoryCache[cacheKey] = translated;
      _cacheService.saveTranslation(text, targetLang, translated);
      
      return translated;
    }

  String getLanguageFlag(String code) {
    switch (code) {
      case 'ms': return '🇲🇾';
      case 'en': return '🇬🇧';
      case 'zh': return '🇨🇳';
      default: return '🌐';
    }
  }
}