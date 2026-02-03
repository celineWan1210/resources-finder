import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

/// Centralized Translation Service for Kita Hack
/// Supports Malay, English, and Chinese translations using Gemini API
class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // Translation cache to avoid redundant API calls
  final Map<String, Map<String, String>> _cache = {};
  
  // Current user's preferred language
  String _preferredLanguage = 'auto'; // 'auto', 'ms', 'en', 'zh'
  String get preferredLanguage => _preferredLanguage;
  
  // Whether to show translated or original text
  bool _showTranslated = false;
  bool get showTranslated => _showTranslated;
  
  // 🔑 Gemini API key loaded from .env (GEMINI_API_KEY)
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  
  // ✅ Gemini API endpoint (model: gemini-2.5-flash)
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  
  /// Toggle between original and translated text
  void toggleTranslation() {
    _showTranslated = !_showTranslated;
    notifyListeners();
  }
  
  /// Set preferred language for translation
  void setPreferredLanguage(String languageCode) {
    _preferredLanguage = languageCode;
    notifyListeners();
  }
  
  /// Detect language of the text
  Future<String> detectLanguage(String text) async {
    if (text.isEmpty) return 'unknown';
    
    // Check for Chinese characters
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(text)) {
      return 'zh';
    }
    
    // Check for Malay-specific words
    final malayWords = ['untuk', 'dengan', 'adalah', 'di', 'yang', 'ini', 'itu', 
                        'saya', 'kami', 'bantuan', 'makanan', 'rumah', 'tempat'];
    final lowerText = text.toLowerCase();
    int malayMatches = malayWords.where((word) => lowerText.contains(word)).length;
    
    if (malayMatches >= 2) {
      return 'ms';
    }
    
    // Default to English
    return 'en';
  }
  
  /// Translate text using Gemini API
  Future<String> translate(String text, {String? targetLanguage}) async {
    if (text.isEmpty) return text;
    
    // Check if API key is set
    if (_geminiApiKey.isEmpty) {
      debugPrint('⚠️ WARNING: GEMINI_API_KEY not set. Add it to .env.');
      return text; // Return original text
    }
    
    // Use preferred language if not specified
    final target = targetLanguage ?? _preferredLanguage;
    if (target == 'auto') return text;
    
    // Check cache first
    final cacheKey = '$text|$target';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!['translation'] ?? text;
    }
    
    try {
      // Detect source language
      final sourceLang = await detectLanguage(text);
      
      // Don't translate if already in target language
      if (sourceLang == target) return text;
      
      // Get language names
      final targetLangName = _getLanguageName(target);
      
      // Prepare Gemini API request
      final prompt = '''
Translate the following text to $targetLangName.
Keep the translation natural and culturally appropriate for Malaysia.
Only return the translated text, nothing else.

Text: $text
''';
      
      // ✅ FIXED: Correct URL format with API key as query parameter
      final url = Uri.parse('$_geminiEndpoint?key=$_geminiApiKey');
      
      debugPrint('🌐 Calling Gemini API for translation...');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': prompt}]
          }],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 1024,
          }
        }),
      );
      
      debugPrint('📡 API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translation = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.trim() ?? text;
        
        // Cache the result
        _cache[cacheKey] = {
          'original': text,
          'translation': translation,
          'sourceLang': sourceLang,
          'targetLang': target,
        };
        
        debugPrint('✅ Translation successful: $text → $translation');
        return translation;
        
      } else if (response.statusCode == 400) {
        debugPrint('❌ API Error 400: Bad Request. Check your API key format.');
        debugPrint('Response: ${response.body}');
        return text;
        
      } else if (response.statusCode == 403) {
        debugPrint('❌ API Error 403: API key invalid or doesn\'t have permission.');
        debugPrint('Make sure you created the key at: https://aistudio.google.com/app/apikey');
        return text;
        
      } else if (response.statusCode == 404) {
        debugPrint('❌ API Error 404: Endpoint not found. API URL might be incorrect.');
        debugPrint('URL used: $url');
        return text;
        
      } else {
        debugPrint('❌ Translation API error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return text;
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Translation error: $e');
      debugPrint('Stack trace: $stackTrace');
      return text;
    }
  }
  
  /// Batch translate multiple texts (more efficient)
  Future<List<String>> translateBatch(List<String> texts, {String? targetLanguage}) async {
    if (texts.isEmpty) return texts;
    
    final target = targetLanguage ?? _preferredLanguage;
    if (target == 'auto') return texts;
    
    final results = <String>[];
    
    // Translate in batches of 5 to avoid rate limits
    const batchSize = 5;
    for (var i = 0; i < texts.length; i += batchSize) {
      final batch = texts.skip(i).take(batchSize).toList();
      final translated = await Future.wait(
        batch.map((text) => translate(text, targetLanguage: target))
      );
      results.addAll(translated);
      
      // Small delay between batches to avoid rate limiting
      if (i + batchSize < texts.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    
    return results;
  }
  
  /// Clear translation cache
  void clearCache() {
    _cache.clear();
    notifyListeners();
    debugPrint('🗑️ Translation cache cleared');
  }
  
  /// Get language display name
  String _getLanguageName(String code) {
    switch (code) {
      case 'ms':
        return 'Malay (Bahasa Malaysia)';
      case 'en':
        return 'English';
      case 'zh':
        return 'Chinese (简体中文)';
      default:
        return 'English';
    }
  }
  
  /// Get language emoji flag
  String getLanguageFlag(String code) {
    switch (code) {
      case 'ms':
        return '🇲🇾';
      case 'en':
        return '🇬🇧';
      case 'zh':
        return '🇨🇳';
      default:
        return '🌐';
    }
  }
}
