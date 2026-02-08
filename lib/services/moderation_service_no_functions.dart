import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AI Moderation Service - Optimized with retry logic
class ModerationService {
  static final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static final String geminiApiUrl = dotenv.env['GEMINI_API_URL'] ?? '';
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Call this AFTER creating a contribution in Firestore
  static Future<void> moderateContribution(String contributionId, Map<String, dynamic> contributionData) async {
    try {
      print('🔍 Starting moderation for contribution: $contributionId');
      
      // Step 1: Call Gemini API with retry logic
      final moderationResult = await _analyzeWithGemini(contributionData);
      
      // Step 2: Determine status
      final isSafe = moderationResult['safe'] == true;
      final riskScore = moderationResult['riskScore'] ?? 'medium';
      
      // Step 3: Update contribution and create log in a batch
      final batch = _firestore.batch();
      
      // Update contribution
      batch.update(
        _firestore.collection('contributions').doc(contributionId),
        {
          'verified': isSafe,
          'moderationStatus': isSafe ? 'approved' : 'flagged',
          'moderationReason': moderationResult['reason'],
          'riskScore': riskScore,
          if (isSafe) 'approvedAt': FieldValue.serverTimestamp()
          else 'flaggedAt': FieldValue.serverTimestamp(),
        },
      );
      
      // Add moderation log
      batch.set(
        _firestore.collection('moderationLogs').doc(),
        {
          'contributionId': contributionId,
          'userId': contributionData['userId'] ?? 'anonymous',
          'userEmail': contributionData['userEmail'] ?? 'not_provided',
          'description': contributionData['description'],
          'categories': contributionData['categories'] ?? [],
          'location': contributionData['location'] ?? 'not_provided',
          'contact': contributionData['contact'] ?? 'not_provided',
          'moderationResult': moderationResult,
          'timestamp': FieldValue.serverTimestamp(),
          'reviewedByHuman': false,
        },
      );
      
      // Commit batch
      await batch.commit();
      
      print(isSafe ? '✅ APPROVED automatically' : '⚠️ FLAGGED: ${moderationResult['reason']}');
      
      // Step 4: Handle user warnings (separate transaction)
      if (!isSafe) {
        await _incrementUserWarning(
          contributionData['userId'],
          riskScore,
        );
      }

    } catch (e) {
      print('❌ Moderation error: $e');
      
      // Mark as error - moderator will need to review manually
      try {
        await _firestore.collection('contributions').doc(contributionId).update({
          'moderationStatus': 'error',
          'moderationError': e.toString(),
        });
      } catch (updateError) {
        print('Failed to update error status: $updateError');
      }
    }
  }

  /// Call Gemini API to analyze content with retry logic
  static Future<Map<String, dynamic>> _analyzeWithGemini(Map<String, dynamic> contribution) async {
    // FIXED: Now includes contact information in the analysis
    final contact = contribution['contact'] ?? '';
    final hasContact = contact.isNotEmpty;
    
    final prompt = '''Analyze this community aid post for safety. Return ONLY valid JSON.

Post Details:
Description: "${contribution['description'] ?? 'N/A'}"
Categories: ${json.encode(contribution['categories'] ?? [])}
Location: "${contribution['location'] ?? 'N/A'}"
${hasContact ? 'Contact Information: "$contact"' : 'Contact: Not provided'}

Check for:
- Scams or fake offers
- Inappropriate or offensive content
- Suspicious contact information (fake numbers, scam patterns)
- Requests for money or personal information
- Spam or commercial advertising
- Contact info that seems suspicious or incomplete

${hasContact ? 'Pay special attention to the contact information - check if it looks legitimate.' : ''}

IMPORTANT: Keep "reason" field to 2 sentences maximum or less.

Response format (valid JSON only, no extra text):
{
  "safe": true or false,
  "reason": "Brief reason in 1-2 sentences max",
  "riskScore": "low" or "medium" or "high",
  "concerns": ["concern1", "concern2"]
}''';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 1000,
      }
    };

    // Retry logic for API overload
    int maxRetries = 3;
    Duration delay = Duration(seconds: 2);
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$geminiApiUrl?key=$geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(Duration(seconds: 30));

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          
          // Check if response was truncated
          final finishReason = responseData['candidates']?[0]?['finishReason'];
          if (finishReason == 'MAX_TOKENS' || finishReason == 'STOP') {
            print('⚠️ Response finish reason: $finishReason');
          }
          
          final text = responseData['candidates'][0]['content']['parts'][0]['text'];
          
          print('📝 Raw Gemini response: $text');
          
          // Try to extract JSON from response (handle markdown, backticks, etc)
          String jsonText = text.trim();
          
          // Remove markdown code blocks if present
          jsonText = jsonText.replaceAll(RegExp(r'```json\s*'), '');
          jsonText = jsonText.replaceAll(RegExp(r'```\s*'), '');
          
          // Try to find JSON object
          final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonText);
          if (jsonMatch != null) {
            jsonText = jsonMatch.group(0)!;
          }
          
          // Try to fix incomplete JSON by adding missing closing braces
          if (!jsonText.trim().endsWith('}')) {
            int openBraces = '{'.allMatches(jsonText).length;
            int closeBraces = '}'.allMatches(jsonText).length;
            
            if (openBraces > closeBraces) {
              // Add missing fields and close the JSON
              if (!jsonText.contains('"riskScore"')) {
                jsonText += ',\n  "riskScore": "low"';
              }
              if (!jsonText.contains('"concerns"')) {
                jsonText += ',\n  "concerns": []';
              }
              jsonText += '\n}';
              print('🔧 Fixed incomplete JSON');
            }
          }
          
          try {
            final parsed = json.decode(jsonText);
            
            return {
              'safe': parsed['safe'] == true,
              'reason': parsed['reason'] ?? 'No reason provided',
              'riskScore': parsed['riskScore']?.toString().toLowerCase() ?? 'low',
              'concerns': List<String>.from(parsed['concerns'] ?? []),
              'rawResponse': text,
            };
          } catch (parseError) {
            print('❌ JSON parse error: $parseError');
            print('📝 Attempted to parse: $jsonText');
            
            // Try to extract just the "safe" field
            final safeMatch = RegExp(r'"safe":\s*(true|false)').firstMatch(text);
            if (safeMatch != null) {
              final isSafe = safeMatch.group(1) == 'true';
              print('✅ Extracted safe status: $isSafe');
              return {
                'safe': isSafe,
                'reason': 'Parsed from incomplete response',
                'riskScore': 'low',
                'concerns': [],
                'rawResponse': text,
              };
            }
            
            // Ultimate fallback: approve as safe if we can't parse
            print('⚠️ Using fallback: marking as safe');
            return {
              'safe': true,
              'reason': 'Unable to parse AI response - defaulting to safe',
              'riskScore': 'low',
              'concerns': [],
              'rawResponse': text,
            };
          }
        }
        
        // Handle 503 (overloaded) - retry
        if (response.statusCode == 503 && attempt < maxRetries - 1) {
          print('⏳ Gemini overloaded, retrying in ${delay.inSeconds}s... (${attempt + 1}/$maxRetries)');
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
          continue;
        }
        
        throw Exception('Gemini API error (${response.statusCode}): ${response.body}');
        
      } catch (e) {
        if (attempt == maxRetries - 1) {
          rethrow;
        }
        print('⏳ Error on attempt ${attempt + 1}, retrying: $e');
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    
    throw Exception('Max retries reached');
  }

static Future<void> moderateRequest(String requestId, Map<String, dynamic> requestData) async {
  try {
    print('🔍 Starting moderation for request: $requestId');
    
    // Step 1: Call Gemini API with retry logic
    final moderationResult = await _analyzeRequestWithGemini(requestData);
    
    // Step 2: Determine status
    final isSafe = moderationResult['safe'] == true;
    final riskScore = moderationResult['riskScore'] ?? 'medium';
    
    // Step 3: Update request and create log in a batch
    final batch = _firestore.batch();
    
    // Update request
    batch.update(
      _firestore.collection('help_requests').doc(requestId),
      {
        'verified': isSafe,
        'moderationStatus': isSafe ? 'approved' : 'flagged',
        'moderationReason': moderationResult['reason'],
        'riskScore': riskScore,
        if (isSafe) 'approvedAt': FieldValue.serverTimestamp()
        else 'flaggedAt': FieldValue.serverTimestamp(),
      },
    );
    
    // Add moderation log
    batch.set(
      _firestore.collection('moderationLogs').doc(),
      {
        'requestId': requestId,
        'userId': requestData['userId'] ?? 'anonymous',
        'userEmail': requestData['userEmail'] ?? 'not_provided',
        'type': 'help_request',
        'categories': requestData['categories'] ?? [],
        'remarks': requestData['remarks'] ?? '',
        'location': requestData['location'] ?? 'not_provided',
        'contact': requestData['contact'] ?? 'not_provided',
        'moderationResult': moderationResult,
        'timestamp': FieldValue.serverTimestamp(),
        'reviewedByHuman': false,
      },
    );
    
    // Commit batch
    await batch.commit();
    
    print(isSafe ? '✅ REQUEST APPROVED automatically' : '⚠️ REQUEST FLAGGED: ${moderationResult['reason']}');
    
    // Step 4: Handle user warnings (separate transaction)
    if (!isSafe) {
      await _incrementUserWarning(
        requestData['userId'],
        riskScore,
      );
    }

  } catch (e) {
    print('❌ Request moderation error: $e');
    
    // Mark as error
    try {
      await _firestore.collection('help_requests').doc(requestId).update({
        'moderationStatus': 'error',
        'moderationError': e.toString(),
      });
    } catch (updateError) {
      print('Failed to update error status: $updateError');
    }
  }
}


  /// Analyze help request with Gemini
static Future<Map<String, dynamic>> _analyzeRequestWithGemini(Map<String, dynamic> request) async {
  final contact = request['contact'] ?? '';
  final hasContact = contact.isNotEmpty;
  final remarks = request['remarks'] ?? '';
  
  final prompt = '''Analyze this HELP REQUEST from someone asking for assistance. Return ONLY valid JSON.

Request Details:
What they need: ${json.encode(request['categories'] ?? [])}
Quantity Needed: "${request['quantity'] ?? 'N/A'}"
Additional Details: "${remarks.isNotEmpty ? remarks : 'None'}"
Location: "${request['location'] ?? 'N/A'}"
${hasContact ? 'Contact Information: "$contact"' : 'Contact: Not provided'}

Check for RED FLAGS in help requests:
- Suspicious or unrealistic quantities (e.g., "need 1000 meals")
- Offensive, abusive, or inappropriate language
- Signs of scamming (asking for money, gift cards, personal info)
- Repeated spam requests
- Fake emergencies to exploit helpers
- Vague or suspicious locations
- Inappropriate use of the help request system
- Signs the person may be trying to abuse helpers' generosity

${hasContact ? 'Check if contact information looks legitimate or suspicious.' : ''}

REMEMBER: Most genuine help requests should be APPROVED. Only flag if there are clear red flags.

IMPORTANT: Keep "reason" field to 2 sentences maximum or less.

Response format (valid JSON only, no extra text):
{
  "safe": true or false,
  "reason": "Brief reason in 1-2 sentences max",
  "riskScore": "low" or "medium" or "high",
  "concerns": ["concern1", "concern2"]
}''';

  final requestBody = {
    'contents': [
      {
        'parts': [
          {'text': prompt}
        ]
      }
    ],
    'generationConfig': {
      'temperature': 0.2,
      'maxOutputTokens': 1000,
    }
  };

  // [Rest of the method stays the same - the retry logic and JSON parsing]
  int maxRetries = 3;
  Duration delay = Duration(seconds: 2);
  
  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      final response = await http.post(
        Uri.parse('$geminiApiUrl?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final text = responseData['candidates'][0]['content']['parts'][0]['text'];
        
        print('📝 Raw Gemini response (help request): $text');
        
        // Same JSON parsing logic as contributions
        String jsonText = text.trim();
        jsonText = jsonText.replaceAll(RegExp(r'```json\s*'), '');
        jsonText = jsonText.replaceAll(RegExp(r'```\s*'), '');
        
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonText);
        if (jsonMatch != null) {
          jsonText = jsonMatch.group(0)!;
        }
        
        if (!jsonText.trim().endsWith('}')) {
          int openBraces = '{'.allMatches(jsonText).length;
          int closeBraces = '}'.allMatches(jsonText).length;
          
          if (openBraces > closeBraces) {
            if (!jsonText.contains('"riskScore"')) {
              jsonText += ',\n  "riskScore": "low"';
            }
            if (!jsonText.contains('"concerns"')) {
              jsonText += ',\n  "concerns": []';
            }
            jsonText += '\n}';
          }
        }
        
        try {
          final parsed = json.decode(jsonText);
          
          return {
            'safe': parsed['safe'] == true,
            'reason': parsed['reason'] ?? 'No reason provided',
            'riskScore': parsed['riskScore']?.toString().toLowerCase() ?? 'low',
            'concerns': List<String>.from(parsed['concerns'] ?? []),
            'rawResponse': text,
          };
        } catch (parseError) {
          final safeMatch = RegExp(r'"safe":\s*(true|false)').firstMatch(text);
          if (safeMatch != null) {
            final isSafe = safeMatch.group(1) == 'true';
            return {
              'safe': isSafe,
              'reason': 'Parsed from incomplete response',
              'riskScore': 'low',
              'concerns': [],
              'rawResponse': text,
            };
          }
          
          return {
            'safe': true,
            'reason': 'Unable to parse AI response - defaulting to safe',
            'riskScore': 'low',
            'concerns': [],
            'rawResponse': text,
          };
        }
      }
      
      if (response.statusCode == 503 && attempt < maxRetries - 1) {
        await Future.delayed(delay);
        delay *= 2;
        continue;
      }
      
      throw Exception('Gemini API error (${response.statusCode}): ${response.body}');
      
    } catch (e) {
      if (attempt == maxRetries - 1) rethrow;
      await Future.delayed(delay);
      delay *= 2;
    }
  }
  
  throw Exception('Max retries reached');
}

  /// Increment user warning count
  static Future<void> _incrementUserWarning(String? userId, String riskScore) async {
    if (userId == null || userId.isEmpty || userId == 'anonymous') {
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // High risk = 2 warnings, Medium/Low = 1 warning
      final warningIncrement = riskScore == 'high' ? 2 : 1;
      
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          // Create new user record
          transaction.set(userRef, {
            'warningCount': warningIncrement,
            'blacklisted': false,
            'lastWarningAt': FieldValue.serverTimestamp(),
          });
        } else {
          final currentWarnings = userDoc.data()?['warningCount'] ?? 0;
          final newWarningCount = currentWarnings + warningIncrement;
          final shouldBlacklist = newWarningCount >= 3;
          
          transaction.update(userRef, {
            'warningCount': newWarningCount,
            'blacklisted': shouldBlacklist,
            'lastWarningAt': FieldValue.serverTimestamp(),
          });

          if (shouldBlacklist) {
            print('🚫 User $userId BLACKLISTED ($newWarningCount warnings)');
          }
        }
      });
    } catch (e) {
      print('⚠️ Warning: Failed to update user warnings: $e');
      // Don't throw - this shouldn't block the moderation process
    }
  }

  /// Check if user is blacklisted (call before allowing contribution)
  static Future<bool> isUserBlacklisted(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists && (doc.data()?['blacklisted'] == true);
    } catch (e) {
      print('Error checking blacklist: $e');
      return false;
    }
  }

  /// Get user warning count
  static Future<int> getUserWarningCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['warningCount'] ?? 0;
    } catch (e) {
      print('Error getting warning count: $e');
      return 0;
    }
  }
}