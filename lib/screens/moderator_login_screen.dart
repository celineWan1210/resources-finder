import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Moderator Login Screen
/// Only requires email and verification code - no password needed
class ModeratorLoginScreen extends StatefulWidget {
  const ModeratorLoginScreen({super.key});

  @override
  State<ModeratorLoginScreen> createState() => _ModeratorLoginScreenState();
}

class _ModeratorLoginScreenState extends State<ModeratorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  final email = _emailController.text.trim().toLowerCase();
  final code = _verificationCodeController.text.trim().toUpperCase();

  try {
    // Step 1: Check if code exists
    final codeDoc = await FirebaseFirestore.instance
        .collection('moderatorCodes')
        .doc(code)
        .get();

    if (!codeDoc.exists) {
      _showError('Invalid verification code');
      return;
    }

    final codeData = codeDoc.data() as Map<String, dynamic>;
    final codeEmail = (codeData['email'] as String?)?.toLowerCase();

    // Step 2: Check email matches
    if (codeEmail != email) {
      _showError('Email does not match the verification code');
      return;
    }

    // Step 3: Check if code already used
    if (codeData['used'] == true) {
      _showError('This code has already been used');
      return;
    }

    // Step 4: Check if code expired
    if (codeData['expiresAt'] != null) {
      final expiresAt = (codeData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        _showError('This verification code has expired');
        return;
      }
    }

    // Step 5: Mark code as used
    await FirebaseFirestore.instance
        .collection('moderatorCodes')
        .doc(code)
        .update({
      'used': true,
      'usedBy': email,
      'usedAt': FieldValue.serverTimestamp(),
    });

    // Step 6: Navigate to moderator dashboard
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/moderator-dashboard');
    }

  } catch (e) {
    _showError('An error occurred: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade400,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo/Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.admin_panel_settings,
                            size: 64,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          'Moderator Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your email and verification code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Verification Code Field
                        TextFormField(
                          controller: _verificationCodeController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Verification Code',
                            prefixIcon: const Icon(Icons.verified_user),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.amber.shade50,
                            helperText: 'Enter the 8-character code from email',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter verification code';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        
                        // Login Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Access Dashboard',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Help Text
                        TextButton(
                          onPressed: () {
                            _showHelpDialog();
                          },
                          child: Text(
                            'Need help accessing the moderator panel?',
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Moderator Access'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To access the moderator dashboard, you need:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('1. Your registered email address'),
            SizedBox(height: 8),
            Text('2. A valid 8-character verification code'),
            SizedBox(height: 12),
            Text(
              'The code is sent to your email by the admin and must match your email address.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 8),
            Text(
              'If you need access, please contact the system administrator.',
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
}