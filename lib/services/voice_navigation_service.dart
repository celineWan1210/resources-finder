import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';
import 'location_cache_service.dart';

class VoiceNavigationService {
  // TTS instance
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsInitialized = false;
  
  // Get API credentials from .env file
  static final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final String _geminiApiUrl = dotenv.env['GEMINI_API_URL'] ?? '';
  
  // System prompt for AI to understand commands
  static const String _systemPrompt = '''You are a voice command parser. 
Analyze this voice input and return ONLY ONE of these commands:

- food_bank_nearby (user wants food banks near them)
- food_bank (user wants food banks, no location emphasis)
- shelter_nearby (user wants shelters near them)
- shelter (user wants shelters)
- community_resources_nearby (user wants all resources near them)
- community_resources (user wants all resources)
- share_resources (user wants to donate/contribute)
- request_help (user needs help, is hungry, homeless, etc.)
- home (user wants to go home)
- profile (user wants their profile)
- none (unrelated to the app)

RULES:
- If user mentions "near", "nearby", "close", "around me" → use "_nearby" version
- If user says "I need", "I'm hungry", "I'm homeless" → return "request_help"
- If user says "donate", "give", "contribute", "share" → return "share_resources"
- Return ONLY the command, nothing else, no quotes, no explanation.

User said: ''';

  /// Initialize TTS with settings
  static Future<void> _initializeTts() async {
    if (_ttsInitialized) return;
    
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5); // Normal speed
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      _ttsInitialized = true;
      debugPrint('🔊 TTS initialized successfully');
    } catch (e) {
      debugPrint('❌ TTS initialization error: $e');
    }
  }

  /// Speak a message using TTS
  static Future<void> speak(String message) async {
    try {
      await _initializeTts();
      debugPrint('🔊 Speaking: "$message"');
      await _tts.speak(message);
    } catch (e) {
      debugPrint('❌ TTS speak error: $e');
    }
  }

  /// Stop speaking
  static Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('❌ TTS stop error: $e');
    }
  }

  /// Get counts of food banks/shelters in the area
  static Future<Map<String, int>> _getLocationCounts({
    required String locationType,
    required double lat,
    required double lng,
  }) async {
    int officialCount = 0;
    int contributionCount = 0;

    try {
      // ✅ Count OFFICIAL locations from LocationCacheService
      final cachedLocations = await LocationCacheService.getCachedLocations(
        type: locationType,
        userLat: lat,
        userLng: lng,
        radiusKm: 10.0,
      );
      officialCount = cachedLocations.length;
      
      // ✅ Count CONTRIBUTIONS from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('contributions')
          .where('status', isEqualTo: 'active')
          .where('moderationStatus', isEqualTo: 'approved')
          .get();
      
      for (var doc in snapshot.docs) {
        final contribution = doc.data();
        final endDate = DateTime.parse(contribution['endDate'] as String);
        final type = (contribution['type'] ?? '').toString().toLowerCase();
        
        // Check if matches type and is within 10km
        bool matches = false;
        if (locationType == 'foodbank' && type == 'food') {
          matches = true;
        } else if (locationType == 'shelter' && type == 'shelter') {
          matches = true;
        }
        
        if (matches && endDate.isAfter(DateTime.now())) {
          final distance = Geolocator.distanceBetween(
            lat,
            lng,
            contribution['lat'] as double,
            contribution['lng'] as double,
          ) / 1000;
          
          if (distance <= 10.0) {
            contributionCount++;
          }
        }
      }
      
      debugPrint('📊 Counts for $locationType: $officialCount official, $contributionCount contributions');
      
    } catch (e) {
      debugPrint('❌ Error counting locations: $e');
    }

    return {
      'official': officialCount,
      'contribution': contributionCount,
    };
  }

  /// Parse voice command using Gemini API
  static Future<String?> parseVoiceCommand(String userText) async {
    try {
      debugPrint('🎤 Parsing voice command: "$userText"');
      
      // Check if API credentials are configured
      if (_geminiApiKey.isEmpty || _geminiApiUrl.isEmpty) {
        debugPrint('❌ Gemini API not configured in .env file');
        return _fallbackParser(userText);
      }

      final url = '$_geminiApiUrl?key=$_geminiApiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': '$_systemPrompt"$userText"'}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 50, // ✨ INCREASED from 20 to 50
          }
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('🎤 Gemini API status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('🎤 Gemini response: $data');
        
        String? command;
        
        try {
          final candidates = data['candidates'];
          if (candidates != null && candidates is List && candidates.isNotEmpty) {
            final firstCandidate = candidates[0];
            if (firstCandidate != null && firstCandidate is Map) {
              final content = firstCandidate['content'];
              if (content != null && content is Map) {
                final parts = content['parts'];
                if (parts != null && parts is List && parts.isNotEmpty) {
                  final firstPart = parts[0];
                  if (firstPart != null && firstPart is Map) {
                    final text = firstPart['text'];
                    if (text != null) {
                      command = text.toString()
                          .trim()
                          .replaceAll('"', '')
                          .replaceAll("'", '')
                          .replaceAll('\n', '')
                          .toLowerCase();
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Error parsing Gemini response structure: $e');
        }
        
        if (command != null && command.isNotEmpty) {
          debugPrint('🎤 Voice: "$userText" → Command: $command');
          return command;
        } else {
          debugPrint('⚠️ Could not extract command from response, using fallback');
          return _fallbackParser(userText);
        }
      } else {
        debugPrint('❌ Gemini API error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return _fallbackParser(userText);
      }
    } catch (e) {
      debugPrint('❌ Voice parser exception: $e');
      return _fallbackParser(userText);
    }
  }

  /// Fallback parser using simple keyword matching when API fails
  static String? _fallbackParser(String userText) {
    debugPrint('🎤 Using fallback parser for: "$userText"');
    
    final text = userText.toLowerCase().trim();
    
    // Check for exact/priority keywords first to avoid false matches
    
    // Shelters - CHECK FIRST (before food, since "shelter" is more specific)
    if (text.contains('shelter') || text.contains('housing') || text.contains('sleep')) {
      if (text.contains('near') || text.contains('nearby') || text.contains('close') || text.contains('around')) {
        return 'shelter_nearby';
      }
      return 'shelter';
    }
    
    // Food banks - more specific matches first
    if (text.contains('food bank') || text.contains('foodbank')) {
      if (text.contains('near') || text.contains('nearby') || text.contains('close') || text.contains('around')) {
        return 'food_bank_nearby';
      }
      return 'food_bank';
    }
    
    // Food (only if no shelter match) - more general
    if (text.contains('food')) {
      if (text.contains('near') || text.contains('nearby') || text.contains('close') || text.contains('around')) {
        return 'food_bank_nearby';
      }
      return 'food_bank';
    }
    
    // Community resources
    if (text.contains('community') || text.contains('resource') || text.contains('all')) {
      if (text.contains('near') || text.contains('nearby') || text.contains('close') || text.contains('around')) {
        return 'community_resources_nearby';
      }
      return 'community_resources';
    }
    
    // Request help
    if (text.contains('need help') || text.contains('hungry') || text.contains('homeless') || 
        text.contains('i need') || text.contains('help me')) {
      return 'request_help';
    }
    
    // Share resources
    if (text.contains('donate') || text.contains('give') || text.contains('contribute') || 
        text.contains('share') || text.contains('offer')) {
      return 'share_resources';
    }
    
    // Navigation
    if (text.contains('home') || text.contains('main')) {
      return 'home';
    }
    
    if (text.contains('profile') || text.contains('account')) {
      return 'profile';
    }
    
    debugPrint('🎤 No matching command found');
    return null;
  }

  /// Execute a voice command and navigate accordingly
  static Future<VoiceCommandResult> executeCommand({
    required BuildContext context,
    required String userText,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final bool isGuest = user == null;

    // Parse the command using Gemini (with fallback)
    final command = await parseVoiceCommand(userText);

    if (command == null || command == 'none') {
      final errorMessage = "I didn't understand that. Try saying 'find food banks' or 'show shelters nearby'.";
      await speak(errorMessage);
      return VoiceCommandResult(
        success: false,
        message: errorMessage,
      );
    }

    // Normalize shorthand commands
    String normalizedCommand = command.toLowerCase().trim();
    
    if (normalizedCommand == 'food' || normalizedCommand == 'foodbank') {
      normalizedCommand = 'food_bank';
    } else if (normalizedCommand == 'shelters' || normalizedCommand == 'shel') { // ✨ Added 'shel'
      normalizedCommand = 'shelter';
    } else if (normalizedCommand == 'community') {
      normalizedCommand = 'community_resources';
    } else if (normalizedCommand == 'help' || normalizedCommand == 'assistance') {
      normalizedCommand = 'request_help';
    } else if (normalizedCommand == 'contribute' || normalizedCommand == 'donate') {
      normalizedCommand = 'share_resources';
    }

    // Check if command is valid
    const validCommands = [
      'food_bank_nearby', 'food_bank',
      'shelter_nearby', 'shelter',
      'community_resources_nearby', 'community_resources',
      'share_resources', 'contribute',
      'request_help', 'need_assistance',
      'home', 'profile',
    ];

    if (!validCommands.contains(normalizedCommand)) {
      final errorMessage = "I didn't understand that. Try saying 'find food banks' or 'show shelters'.";
      await speak(errorMessage);
      return VoiceCommandResult(
        success: false,
        message: errorMessage,
      );
    }

    // Handle guest restrictions
    if ((normalizedCommand == 'share_resources' || 
         normalizedCommand == 'contribute' || 
         normalizedCommand == 'request_help' || 
         normalizedCommand == 'need_assistance') && isGuest) {
      final authMessage = "You need to sign in to ${normalizedCommand.replaceAll('_', ' ')}. Would you like to sign in now?";
      await speak(authMessage);
      return VoiceCommandResult(
        success: false,
        message: authMessage,
        requiresAuth: true,
      );
    }

    // Execute the command
    return _navigateBasedOnCommand(context, normalizedCommand);
  }

  /// Navigate to the appropriate screen based on command
  static Future<VoiceCommandResult> _navigateBasedOnCommand(
    BuildContext context,
    String command,
  ) async {
    // Get current location for counting
    final locationResult = await LocationService.getCurrentLocation();
    final lat = locationResult.location.latitude;
    final lng = locationResult.location.longitude;

    switch (command) {
      // Food banks
      case 'food_bank_nearby':
      case 'food_bank':
        final counts = await _getLocationCounts(
          locationType: 'foodbank',
          lat: lat,
          lng: lng,
        );
        
        // Get the actual locations to read the first one
        final locations = await LocationCacheService.getCachedLocations(
          type: 'foodbank',
          userLat: lat,
          userLng: lng,
          radiusKm: 10.0,
        );
        
        String responseMessage;
        if (counts['official']! + counts['contribution']! > 0) {
          responseMessage = "Found ${counts['official']} official food banks and ${counts['contribution']} community contributions nearby.";
          
          // Add info about the nearest location
          if (locations.isNotEmpty) {
            final nearest = locations[0];
            final distanceKm = nearest['distance'] as double;
            final distanceText = distanceKm < 1 
                ? "${(distanceKm * 1000).round()} meters" 
                : "${distanceKm.toStringAsFixed(1)} kilometers";
            
            responseMessage += " The nearest is ${nearest['name']}, $distanceText away.";
          }
        } else {
          responseMessage = "No food banks found nearby.";
        }
        
        await speak(responseMessage);
        
        Navigator.pushNamed(
          context,
          '/map',
          arguments: {'locationType': 'foodbank', 'nearby': command.contains('nearby')},
        );
        
        return VoiceCommandResult(
          success: true,
          message: responseMessage,
          command: command,
        );

      // Shelters
      case 'shelter_nearby':
      case 'shelter':
        final counts = await _getLocationCounts(
          locationType: 'shelter',
          lat: lat,
          lng: lng,
        );
        
        // Get the actual locations to read the first one
        final locations = await LocationCacheService.getCachedLocations(
          type: 'shelter',
          userLat: lat,
          userLng: lng,
          radiusKm: 10.0,
        );
        
        String responseMessage;
        if (counts['official']! + counts['contribution']! > 0) {
          responseMessage = "Found ${counts['official']} official shelters and ${counts['contribution']} community contributions nearby.";
          
          // Add info about the nearest location
          if (locations.isNotEmpty) {
            final nearest = locations[0];
            final distanceKm = nearest['distance'] as double;
            final distanceText = distanceKm < 1 
                ? "${(distanceKm * 1000).round()} meters" 
                : "${distanceKm.toStringAsFixed(1)} kilometers";
            
            responseMessage += " The nearest is ${nearest['name']}, $distanceText away.";
          }
        } else {
          responseMessage = "No shelters found nearby.";
        }
        
        await speak(responseMessage);
        
        Navigator.pushNamed(
          context,
          '/map',
          arguments: {'locationType': 'shelter', 'nearby': command.contains('nearby')},
        );
        
        return VoiceCommandResult(
          success: true,
          message: responseMessage,
          command: command,
        );

      // Community resources
      case 'community_resources_nearby':
      case 'community_resources':
        final message = "Opening community resources.";
        await speak(message);
        Navigator.pushNamed(context, '/community');
        return VoiceCommandResult(
          success: true,
          message: message,
          command: command,
        );

      // Contribute
      case 'share_resources':
      case 'contribute':
        final message = "Opening contribution form.";
        await speak(message);
        Navigator.pushNamed(context, '/contribute');
        return VoiceCommandResult(
          success: true,
          message: message,
          command: command,
        );

      // Request help
      case 'request_help':
      case 'need_assistance':
        final message = "Opening help request form.";
        await speak(message);
        Navigator.pushNamed(context, '/request-help');
        return VoiceCommandResult(
          success: true,
          message: message,
          command: command,
        );

      // Navigation
      case 'home':
        final message = "Going home.";
        await speak(message);
        Navigator.popUntil(context, (route) => route.isFirst);
        return VoiceCommandResult(
          success: true,
          message: message,
          command: command,
        );

      case 'profile':
        final message = "Opening your profile.";
        await speak(message);
        Navigator.pushNamed(context, '/profile');
        return VoiceCommandResult(
          success: true,
          message: message,
          command: command,
        );

      default:
        final errorMessage = "Command recognized but not implemented yet: $command";
        await speak(errorMessage);
        return VoiceCommandResult(
          success: false,
          message: errorMessage,
        );
    }
  }
}

/// Result of a voice command execution
class VoiceCommandResult {
  final bool success;
  final String message;
  final String? command;
  final bool requiresAuth;

  VoiceCommandResult({
    required this.success,
    required this.message,
    this.command,
    this.requiresAuth = false,
  });

  @override
  String toString() => 'VoiceCommandResult(success: $success, message: $message, command: $command)';
}