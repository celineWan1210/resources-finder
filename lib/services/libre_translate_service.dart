// lib/services/libre_translate_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class LibreTranslateService {
  
  Future<String> translate(String text, String targetLang) async {
    if (text.isEmpty) return text;
    
    try {
      // 🔥 For Chinese: ALWAYS use Google Free API (most reliable)
      if (targetLang == 'zh') {
        final result = await _translateWithGoogleFree(text, targetLang);
        if (result != text) {
          print('✅ Google (Chinese): "$text" → "$result"');
          return result;
        }
      }
      
      // For other languages: Try LibreTranslate first
      final libreResult = await _translateWithLibre(text, targetLang);
      if (libreResult != text) {
        print('✅ LibreTranslate: "$text" → "$libreResult"');
        return libreResult;
      }
      
      // Fallback: MyMemory
      final memoryResult = await _translateWithMyMemory(text, targetLang);
      if (memoryResult != text && !memoryResult.contains('MYMEMORY WARNING')) {
        print('✅ MyMemory: "$text" → "$memoryResult"');
        return memoryResult;
      }
      
      // Last resort: Google Free for all languages
      final googleResult = await _translateWithGoogleFree(text, targetLang);
      if (googleResult != text) {
        print('✅ Google (fallback): "$text" → "$googleResult"');
        return googleResult;
      }
      
    } catch (e) {
      print('❌ Translation failed: $e');
    }
    
    return text;
  }
  
  /// Method 1: Google Free API (MOST RELIABLE for Chinese)
  Future<String> _translateWithGoogleFree(String text, String targetLang) async {
    try {
      final target = _mapLanguageCodeGoogle(targetLang);
      
      print('🔄 Google Free: Translating "$text" to $target');
      
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$target&dt=t&q=${Uri.encodeComponent(text)}'
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      print('📡 Google response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded != null && decoded[0] != null && decoded[0][0] != null) {
          final translated = decoded[0][0][0] as String;
          if (translated != text) {
            print('✅ Google translated: "$text" → "$translated"');
            return translated;
          }
        }
      }
    } catch (e) {
      print('⚠️ Google Free failed: $e');
    }
    return text;
  }
  
  /// Method 2: LibreTranslate (good for Malay)
  Future<String> _translateWithLibre(String text, String targetLang) async {
    try {
      final target = _mapLanguageCodeLibre(targetLang);
      
      print('🔄 LibreTranslate: Translating "$text" to $target');
      
      final response = await http.post(
        Uri.parse('https://libretranslate.com/translate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'q': text,
          'source': 'en',
          'target': target,
          'format': 'text',
        }),
      ).timeout(const Duration(seconds: 12));
      
      print('📡 LibreTranslate response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translated = data['translatedText'] ?? text;
        
        if (translated != text) {
          print('✅ LibreTranslate: "$text" → "$translated"');
          return translated;
        }
      } else {
        print('❌ LibreTranslate error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('⚠️ LibreTranslate failed: $e');
    }
    return text;
  }
  
  /// Method 3: MyMemory
  Future<String> _translateWithMyMemory(String text, String targetLang) async {
    try {
      final target = _mapLanguageCodeMyMemory(targetLang);
      
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|$target'
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translated = data['responseData']['translatedText'] ?? text;
        
        if (!translated.contains('MYMEMORY WARNING') && 
            !translated.contains('LIMIT') && 
            translated != text) {
          return translated;
        }
      }
    } catch (e) {
      print('⚠️ MyMemory failed: $e');
    }
    return text;
  }
  
  /// LibreTranslate codes
  String _mapLanguageCodeLibre(String code) {
    switch (code) {
      case 'ms': return 'ms';
      case 'zh': return 'zh-CN'; 
      case 'en': return 'en';
      default: return 'en';
    }
  }
  
  /// MyMemory codes
  String _mapLanguageCodeMyMemory(String code) {
    switch (code) {
      case 'ms': return 'ms-MY';
      case 'zh': return 'zh-CN';
      case 'en': return 'en-US';
      default: return 'en-US';
    }
  }
  
  /// Google codes (BEST for Chinese)
  String _mapLanguageCodeGoogle(String code) {
    switch (code) {
      case 'ms': return 'ms';
      case 'zh': return 'zh-CN'; // Simplified Chinese
      case 'en': return 'en';
      default: return 'en';
    }
  }
  
  /// Batch translate
  Future<List<String>> translateBatch(
    List<String> texts,
    String targetLang,
  ) async {
    final results = <String>[];
    for (final text in texts) {
      final translated = await translate(text, targetLang);
      results.add(translated);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return results;
  }
}