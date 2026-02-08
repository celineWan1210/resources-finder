import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'voice_navigation_service.dart';

/// Background wake word detection service
/// Continuously listens for "Hey ResourceAI" to trigger voice commands
class WakeWordService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isListening = false;
  static bool _isInitialized = false;
  static BuildContext? _context;
  
  // Wake words that trigger the assistant
  static const List<String> _wakeWords = [
    'hey resource ai',
    'hey resourceai', 
    'resource ai',
    'resourceai',
    'hey resource',
  ];
  
  /// Initialize wake word detection
  static Future<bool> initialize(BuildContext context) async {
    _context = context;
    
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('🎤 Wake word: Microphone permission denied');
        return false;
      }
      
      // Initialize speech recognition
      bool available = await _speech.initialize(
        onError: (error) {
          debugPrint('🎤 Wake word error: $error');
          // Auto-restart on error
          if (_isListening) {
            Future.delayed(const Duration(seconds: 2), () {
              if (_isListening) startListening();
            });
          }
        },
        onStatus: (status) {
          debugPrint('🎤 Wake word status: $status');
          if (status == 'done' && _isListening) {
            // Restart listening when done
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isListening) startListening();
            });
          }
        },
      );
      
      if (!available) {
        debugPrint('🎤 Wake word: Speech not available');
        return false;
      }
      
      _isInitialized = true;
      debugPrint('🎤 Wake word service initialized');
      return true;
      
    } catch (e) {
      debugPrint('🎤 Wake word init error: $e');
      return false;
    }
  }
  
  /// Start continuous listening for wake word
  static Future<void> startListening() async {
    if (!_isInitialized) {
      debugPrint('🎤 Wake word: Not initialized');
      return;
    }
    
    if (_isListening) {
      debugPrint('🎤 Wake word: Already listening');
      return;
    }
    
    _isListening = true;
    debugPrint('🎤 👂 Wake word: Started continuous listening...');
    
    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase().trim();
          debugPrint('🎤 Heard: "$text"');
          
          // Check if wake word detected
          if (_containsWakeWord(text)) {
            debugPrint('🎤 ✅ WAKE WORD DETECTED!');
            _onWakeWordDetected(text);
          }
        },
        listenFor: const Duration(minutes: 10), // Listen for long periods
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation, // Continuous mode
      );
    } catch (e) {
      debugPrint('🎤 Wake word listen error: $e');
      _isListening = false;
    }
  }
  
  /// Stop continuous listening
  static Future<void> stopListening() async {
    if (!_isListening) return;
    
    _isListening = false;
    await _speech.stop();
    debugPrint('🎤 Wake word: Stopped listening');
  }
  
  /// Check if text contains wake word
  static bool _containsWakeWord(String text) {
    final cleaned = text.toLowerCase().replaceAll(',', '').replaceAll('.', '');
    
    for (final wakeWord in _wakeWords) {
      if (cleaned.contains(wakeWord)) {
        return true;
      }
    }
    return false;
  }
  
  /// Extract command after wake word
  static String _extractCommand(String text) {
    final cleaned = text.toLowerCase().trim();
    
    // Remove wake word and get remaining command
    for (final wakeWord in _wakeWords) {
      if (cleaned.contains(wakeWord)) {
        final command = cleaned
            .replaceFirst(wakeWord, '')
            .trim()
            .replaceAll(RegExp(r'^[,.]'), '')
            .trim();
        
        if (command.isNotEmpty) {
          return command;
        }
      }
    }
    
    return '';
  }
  
  /// Handle wake word detection
  static Future<void> _onWakeWordDetected(String fullText) async {
    if (_context == null) return;
    
    // Stop continuous listening temporarily
    await stopListening();
    
    // Play confirmation sound/haptic
    debugPrint('🎤 Processing wake word command...');
    
    // Extract the actual command
    String command = _extractCommand(fullText);
    
    // If no command after wake word, wait for user to speak
    if (command.isEmpty) {
      debugPrint('🎤 Waiting for command after wake word...');
      await VoiceNavigationService.speak("Yes, how can I help?");
      
      // Listen for the actual command
      await _listenForCommand();
    } else {
      // Command was in same sentence as wake word
      debugPrint('🎤 Command detected: "$command"');
      await _executeCommand(command);
    }
    
    // Resume continuous listening after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isListening) startListening();
    });
  }
  
  /// Listen for command after wake word
  static Future<void> _listenForCommand() async {
    try {
      await _speech.listen(
        onResult: (result) async {
          if (result.finalResult) {
            final command = result.recognizedWords;
            debugPrint('🎤 Command received: "$command"');
            await _executeCommand(command);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('🎤 Command listen error: $e');
    }
  }
  
  /// Execute the voice command
  static Future<void> _executeCommand(String command) async {
    if (_context == null) return;
    
    try {
      final result = await VoiceNavigationService.executeCommand(
        context: _context!,
        userText: command,
      );
      
      debugPrint('🎤 Command result: ${result.message}');
    } catch (e) {
      debugPrint('🎤 Command execution error: $e');
    }
  }
  
  /// Check if currently listening
  static bool get isListening => _isListening;
}