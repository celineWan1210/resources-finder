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
          contributionData['userEmail'], // Pass email to store in users collection
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
        
        // Handle 503 Service Unavailable (rate limits, overload)
        if (response.statusCode == 503 && attempt < maxRetries - 1) {
          print('⏳ API overloaded (503), retrying in ${delay.inSeconds}s... (attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(delay);
          delay *= 2; // Exponential backoff
          continue;
        }
        
        throw Exception('Gemini API error (${response.statusCode}): ${response.body}');
        
      } catch (e) {
        if (attempt == maxRetries - 1) {
          rethrow; // Last attempt failed
        }
        print('⏳ Request failed, retrying in ${delay.inSeconds}s... (attempt ${attempt + 1}/$maxRetries)');
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    
    throw Exception('Max retries reached');
  }

  /// Moderate help request (similar to contribution)
  static Future<void> moderateHelpRequest(String requestId, Map<String, dynamic> requestData) async {
  try {
    print('🔍 Starting moderation for help request: $requestId');
    
    final moderationResult = await _analyzeHelpRequestWithGemini(requestData);
    
    final isSafe = moderationResult['safe'] == true;
    final riskScore = moderationResult['riskScore'] ?? 'medium';
    
    final batch = _firestore.batch();
    
    // Update help request
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
        'helpRequestId': requestId,
        'userId': requestData['userId'] ?? 'anonymous',
        'userEmail': requestData['userEmail'] ?? 'not_provided',
        'categories': requestData['categories'] ?? [],
        'quantity': requestData['quantity'] ?? 'N/A',
        'location': requestData['location'] ?? 'not_provided',
        'contact': requestData['contact'] ?? 'not_provided',
        'remarks': requestData['remarks'] ?? '',
        'moderationResult': moderationResult,
        'timestamp': FieldValue.serverTimestamp(),
        'reviewedByHuman': false,
      },
    );
    
    await batch.commit();
    
    print(isSafe ? '✅ APPROVED automatically' : '⚠️ FLAGGED: ${moderationResult['reason']}');
    
    if (!isSafe) {
      await _incrementUserWarning(
        requestData['userId'],
        riskScore,
        requestData['userEmail'],
      );
    }

  } catch (e) {
    print('❌ Moderation error: $e');
    
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

static Future<Map<String, dynamic>> _analyzeHelpRequestWithGemini(Map<String, dynamic> request) async {
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

  /// Increment user warning count with violation period tracking
  static Future<void> _incrementUserWarning(String? userId, String riskScore, String? userEmail) async {
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
          // Create new user record with first violation period
          transaction.set(userRef, {
            'warningCount': warningIncrement,
            'blacklisted': false,
            'lastWarningAt': FieldValue.serverTimestamp(),
            'email': userEmail ?? 'No email',
            'currentViolationPeriod': 1, // Track which violation period
            'totalBlacklistCount': 0, // How many times blacklisted in total
          });
        } else {
          final currentWarnings = userDoc.data()?['warningCount'] ?? 0;
          final wasUnblocked = userDoc.data()?['unblocked'] == true;
          final currentPeriod = userDoc.data()?['currentViolationPeriod'] ?? 1;
          final totalBlacklists = userDoc.data()?['totalBlacklistCount'] ?? 0;
          final newWarningCount = currentWarnings + warningIncrement;
          
          // FIXED: Stricter threshold for previously unblocked users
          // Normal users: blacklist at 3 warnings
          // Previously unblocked users: blacklist at 2 warnings (one strike policy)
          final blacklistThreshold = wasUnblocked ? 2 : 3;
          final shouldBlacklist = newWarningCount >= blacklistThreshold;
          
          Map<String, dynamic> updateData = {
            'warningCount': newWarningCount,
            'blacklisted': shouldBlacklist,
            'lastWarningAt': FieldValue.serverTimestamp(),
            'email': userEmail ?? userDoc.data()?['email'] ?? 'No email',
          };
          
          if (shouldBlacklist) {
            // When blacklisting, increment total blacklist count
            updateData['blacklistedAt'] = FieldValue.serverTimestamp();
            updateData['totalBlacklistCount'] = totalBlacklists + 1;
            updateData['currentViolationPeriod'] = currentPeriod;
            
            final reason = wasUnblocked 
                ? '🚫 User $userId RE-BLACKLISTED ($newWarningCount warnings - period $currentPeriod - total blacklists: ${totalBlacklists + 1})'
                : '🚫 User $userId BLACKLISTED ($newWarningCount warnings - period $currentPeriod)';
            print(reason);
          }
          
          transaction.update(userRef, updateData);
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

  /// Alias for moderateHelpRequest - for backward compatibility
  static Future<void> moderateRequest(String requestId, Map<String, dynamic> requestData) async {
    return moderateHelpRequest(requestId, requestData);
  }
}