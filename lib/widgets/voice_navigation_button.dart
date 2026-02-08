import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../services/voice_navigation_service.dart';

/// Floating voice button widget with speech-to-text
class VoiceNavigationButton extends StatefulWidget {
  const VoiceNavigationButton({super.key});

  @override
  State<VoiceNavigationButton> createState() => _VoiceNavigationButtonState();
}

class _VoiceNavigationButtonState extends State<VoiceNavigationButton>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _speechAvailable = false;
  bool _hasCheckedAvailability = false;
  String _currentText = '';
  String? _availabilityError;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    print('🎤 VoiceNavigationButton initialized');
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    
    // Check availability on init
    _checkSpeechAvailability();
  }

  @override
  void dispose() {
    print('🎤 VoiceNavigationButton disposed');
    _animationController.dispose();
    _speech.cancel(); // Cancel any ongoing speech recognition
    super.dispose();
  }

  /// Check if speech recognition is available on this device
  Future<void> _checkSpeechAvailability() async {
    if (_hasCheckedAvailability) return;
    
    print('🎤 Checking speech recognition availability...');
    
    try {
      bool available = await _speech.initialize(
        onError: (error) {
          print('🎤 ❌ Availability check error: $error');
        },
        onStatus: (status) {
          print('🎤 Availability check status: $status');
        },
      );

      setState(() {
        _speechAvailable = available;
        _hasCheckedAvailability = true;
        _availabilityError = available ? null : 'Speech recognition not available on this device';
      });

      print('🎤 Speech available: $available');

      if (!available) {
        print('🎤 ❌ Speech recognition is NOT available');
      }
    } catch (e) {
      print('🎤 ❌ Exception checking availability: $e');
      setState(() {
        _speechAvailable = false;
        _hasCheckedAvailability = true;
        _availabilityError = 'Speech recognition error: $e';
      });
    }
  }

  Future<void> _requestMicrophonePermission() async {
    print('🎤 Requesting microphone permission...');
    final status = await Permission.microphone.request();
    print('🎤 Permission status after request: $status');
    
    if (!status.isGranted) {
      print('🎤 ❌ Permission DENIED!');
      if (mounted) {
        _showPermissionDeniedDialog();
      }
    } else {
      print('🎤 ✅ Permission GRANTED!');
    }
  }

  void _showPermissionDeniedDialog() {
    print('🎤 Showing permission denied dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'Please enable microphone access in your device settings to use voice commands.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('🎤 User canceled permission dialog');
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              print('🎤 Opening app settings');
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Feature Unavailable'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_availabilityError ?? 'Speech recognition is not available on this device.'),
            const SizedBox(height: 16),
            const Text(
              'Possible reasons:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Device doesn\'t support speech recognition'),
            const Text('• Google app needs to be updated'),
            const Text('• Speech services are disabled in settings'),
            const SizedBox(height: 16),
            const Text(
              'You can still use text-based navigation.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListening() async {
    print('🎤 ========================================');
    print('🎤 Toggle button pressed!');
    print('🎤 Current listening state: $_isListening');
    print('🎤 Current processing state: $_isProcessing');
    print('🎤 Speech available: $_speechAvailable');
    print('🎤 ========================================');
    
    // Check if speech is available
    if (!_hasCheckedAvailability) {
      await _checkSpeechAvailability();
    }
    
    if (!_speechAvailable) {
      print('🎤 ⚠️ Speech not available, showing dialog');
      _showUnavailableDialog();
      return;
    }
    
    if (_isListening) {
      print('🎤 Stopping listening...');
      await _stopListening();
    } else {
      print('🎤 Starting listening...');
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    print('🎤 --- START LISTENING FUNCTION CALLED ---');
    
    // Check permission first
    print('🎤 Checking microphone permission...');
    final permissionStatus = await Permission.microphone.status;
    print('🎤 Current permission status: $permissionStatus');
    
    if (!permissionStatus.isGranted) {
      print('🎤 ⚠️ Permission not granted, requesting...');
      await _requestMicrophonePermission();
      
      // Check again after request
      final newStatus = await Permission.microphone.status;
      print('🎤 Permission status after request: $newStatus');
      
      if (!newStatus.isGranted) {
        print('🎤 ❌ Still not granted, aborting');
        return;
      }
    }

    print('🎤 ✅ Permission granted, starting speech recognition...');

    try {
      // Re-initialize if needed
      if (!_speech.isAvailable) {
        print('🎤 Re-initializing speech...');
        bool available = await _speech.initialize(
          onError: (error) {
            print('🎤 ❌ Speech recognition ERROR: $error');
            debugPrint('Speech recognition error: $error');
            if (mounted) {
              setState(() {
                _isListening = false;
                _isProcessing = false;
              });
              _showErrorSnackbar('Voice recognition error: ${error.errorMsg}');
            }
          },
          onStatus: (status) {
            print('🎤 Speech STATUS changed: $status');
            debugPrint('Speech status: $status');
            if (status == 'done' || status == 'notListening') {
              print('🎤 Speech finished, current text: "$_currentText"');
              if (_isListening && _currentText.isNotEmpty) {
                print('🎤 Processing voice command...');
                _processVoiceCommand();
              } else if (_isListening) {
                // No text captured but listening stopped
                setState(() {
                  _isListening = false;
                });
              }
            }
          },
        );

        print('🎤 Re-initialize result: $available');

        if (!available) {
          print('🎤 ❌ Speech recognition NOT available!');
          setState(() {
            _speechAvailable = false;
            _availabilityError = 'Speech recognition initialization failed';
          });
          _showUnavailableDialog();
          return;
        }
      }

      print('🎤 ✅ Speech recognition ready!');
      
      setState(() {
        _isListening = true;
        _currentText = '';
      });

      print('🎤 State updated: isListening=$_isListening');

      // Start listening
      print('🎤 Starting to listen for speech...');
      await _speech.listen(
        onResult: (result) {
          print('🎤 Speech result: "${result.recognizedWords}"');
          print('🎤 Is final: ${result.finalResult}');
          if (mounted) {
            setState(() {
              _currentText = result.recognizedWords;
            });
          }
        },
        listenFor: const Duration(seconds: 30),  // INCREASED from 10 to 30
        pauseFor: const Duration(seconds: 5),    // INCREASED from 3 to 5
        partialResults: true,
        cancelOnError: false,  // CHANGED from true to false
        listenMode: stt.ListenMode.confirmation,
      );
      
      print('🎤 ✅ Listening started successfully!');
      
    } catch (e) {
      print('🎤 ❌ EXCEPTION during speech initialization: $e');
      setState(() {
        _speechAvailable = false;
        _availabilityError = e.toString();
      });
      _showUnavailableDialog();
    }
  }

  Future<void> _stopListening() async {
    print('🎤 Stopping speech recognition...');
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
    print('🎤 Stopped. Current text: "$_currentText"');

    if (_currentText.isNotEmpty) {
      print('🎤 Processing command from stop...');
      await _processVoiceCommand();
    } else {
      print('🎤 No text captured, nothing to process');
    }
  }

  Future<void> _processVoiceCommand() async {
    print('🎤 --- PROCESSING VOICE COMMAND ---');
    print('🎤 Text to process: "$_currentText"');
    
    if (_currentText.trim().isEmpty) {
      print('🎤 ❌ Empty text, showing error');
      _showErrorSnackbar('No voice input detected.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _isListening = false;
    });

    print('🎤 State: isProcessing=$_isProcessing, isListening=$_isListening');

    try {
      print('🎤 Calling VoiceNavigationService.executeCommand...');
      final result = await VoiceNavigationService.executeCommand(
        context: context,
        userText: _currentText,
      );

      print('🎤 Command result: $result');

      if (!mounted) {
        print('🎤 Widget not mounted, aborting');
        return;
      }

      if (result.success) {
        print('🎤 ✅ Command successful: ${result.message}');
        _showSuccessSnackbar(result.message);
      } else if (result.requiresAuth) {
        print('🎤 ⚠️ Auth required: ${result.message}');
        _showAuthRequiredDialog(result.message);
      } else {
        print('🎤 ❌ Command failed: ${result.message}');
        _showErrorSnackbar(result.message);
      }
    } catch (e) {
      print('🎤 ❌ EXCEPTION during command processing: $e');
      debugPrint('Voice command processing error: $e');
      _showErrorSnackbar('Failed to process voice command.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _currentText = '';
        });
        print('🎤 Processing complete, state reset');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    print('🎤 Showing success snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    print('🎤 Showing error snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAuthRequiredDialog(String message) {
    print('🎤 Showing auth required dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 12),
            Text('Sign In Required'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              print('🎤 User canceled auth dialog');
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              print('🎤 User navigating to login');
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🎤 Building VoiceNavigationButton - isListening: $_isListening, isProcessing: $_isProcessing, available: $_speechAvailable');
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing animation when listening
        if (_isListening)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                width: 80 + (20 * _animationController.value),
                height: 80 + (20 * _animationController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.3 * (1 - _animationController.value)),
                ),
              );
            },
          ),

        // Main button
        FloatingActionButton.large(
          onPressed: () {
            print('🎤 🔘 BUTTON TAPPED!');
            if (_isProcessing) {
              print('🎤 Button press ignored - currently processing');
            } else {
              _toggleListening();
            }
          },
          backgroundColor: _isListening
              ? Colors.red[600]
              : _isProcessing
                  ? Colors.grey[400]
                  : _hasCheckedAvailability && !_speechAvailable
                      ? Colors.grey[500]
                      : Colors.blue[600],
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : Icon(
                  _isListening 
                      ? Icons.stop 
                      : _hasCheckedAvailability && !_speechAvailable
                          ? Icons.mic_off
                          : Icons.mic,
                  size: 32,
                  color: Colors.white,
                ),
        ),

        // Listening text indicator
        if (_isListening || _currentText.isNotEmpty)
          Positioned(
            top: -50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                _currentText.isEmpty ? 'Listening...' : _currentText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple tap-to-speak button for use in app bar or other locations
class CompactVoiceButton extends StatelessWidget {
  const CompactVoiceButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.mic),
      tooltip: 'Voice Command',
      onPressed: () {
        print('🎤 Compact voice button pressed');
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VoiceNavigationButton(),
                SizedBox(height: 16),
                Text(
                  'Tap to speak',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try: "Find food banks near me"',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}