import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';  
import 'services/location_service.dart';
import 'services/moderation_service_no_functions.dart';  
import 'map_screen.dart';
import 'widgets/translatable_text.dart';

class RequestHelpScreen extends StatefulWidget {
  const RequestHelpScreen({super.key});

  @override
  State<RequestHelpScreen> createState() => _RequestHelpScreenState();
}

class RequestCategory {
  final String id;
  final String label;
  final IconData icon;
  final String description;
  final Color color;

  RequestCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.color,
  });
}

class _RequestHelpScreenState extends State<RequestHelpScreen> {
  int _currentView = 0; // 0 = Request Help, 1 = My Requests

  // Simplified: Single-step form
  final Set<String> _selectedCategories = {};
  final List<RequestCategory> _categories = [
    RequestCategory(
      id: 'food',
      label: 'Food',
      icon: Icons.restaurant,
      description: 'Meals or groceries',
      color: Colors.orange,
    ),
    RequestCategory(
      id: 'shelter',
      label: 'Shelter',
      icon: Icons.home,
      description: 'Place to stay',
      color: Colors.blue,
    ),
    RequestCategory(
      id: 'clothes',
      label: 'Clothes',
      icon: Icons.shopping_bag,
      description: 'Clothing items',
      color: Colors.purple,
    ),
    RequestCategory(
      id: 'hygiene',
      label: 'Hygiene',
      icon: Icons.cleaning_services,
      description: 'Personal care',
      color: Colors.teal,
    ),
    RequestCategory(
      id: 'transport',
      label: 'Transport',
      icon: Icons.directions_car,
      description: 'Need a ride',
      color: Colors.green,
    ),
    RequestCategory(
      id: 'supplies',
      label: 'Supplies',
      icon: Icons.card_giftcard,
      description: 'Essential items',
      color: Colors.red,
    ),
  ];

  // Simplified fields
  bool _useCurrentLocation = true;
  final TextEditingController _manualLocationController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  
  LatLng _currentLocation = LocationService.defaultLocation;
  String _currentLocationName = LocationService.defaultLocationName;

  // Tags/Preferences (simplified)
  final Map<String, List<String>> _tagsByCategory = {
    'food': ['Halal', 'Vegetarian', 'Vegan', 'Any Food'],
    'shelter': ['Emergency', 'Family-friendly', 'Pet-friendly'],
    'clothes': ['Men', 'Women', 'Children'],
    'hygiene': ['Baby Care', 'Feminine Products', 'Any'],
    'transport': ['Medical', 'Emergency', 'Job Interview'],
    'supplies': ['Blankets', 'Baby Items', 'Kitchen Items'],
  };
  final Set<String> _selectedTags = {};

  // Store requests
  List<Map<String, dynamic>> _myRequests = [];
  String? _selectedRequestFilter;

  Future<void> _loadCurrentLocation() async {
    final result = await LocationService.getCurrentLocation();
    setState(() {
      _currentLocation = result.location;
      _currentLocationName = result.locationName ?? LocationService.defaultLocationName;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadRequests();
  }

  

  Future<void> _loadRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final String? requestsJson = prefs.getString('my_requests');
    
    if (requestsJson != null) {
      final List<dynamic> decoded = json.decode(requestsJson);
      setState(() {
        _myRequests = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _myRequests.sort((a, b) => 
          DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt']))
        );
      });
      
      // Find matches for each active request
      for (var request in _myRequests) {
        if (request['status'] == 'active') {
          await _findMatches(request);
        }
      }
    }
  }

  Future<void> _syncModerationStatus() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get all user's requests from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('help_requests')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      // Update local requests with Firestore data
      for (var doc in snapshot.docs) {
        final firestoreData = doc.data();
        final firestoreId = doc.id;
        
        // Find matching local request
        final localIndex = _myRequests.indexWhere(
          (r) => r['firestoreId'] == firestoreId || r['id'] == firestoreData['id']
        );
        
        if (localIndex != -1) {
          // Update moderation fields
          setState(() {
            _myRequests[localIndex]['moderationStatus'] = 
              firestoreData['moderationStatus'] ?? 'pending';
            _myRequests[localIndex]['riskScore'] = 
              firestoreData['riskScore'] ?? 'unknown';
            _myRequests[localIndex]['moderationReason'] = 
              firestoreData['moderationReason'];
            _myRequests[localIndex]['verified'] = 
              firestoreData['verified'] ?? false;
          });
        }
      }
      
      // Save updated data
      await _saveRequests();
      
      print('✅ Synced moderation status for ${snapshot.docs.length} requests');
    } catch (e) {
      print('Error syncing moderation status: $e');
    }
  }

  Future<void> _saveRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_myRequests);
    await prefs.setString('my_requests', encoded);
  }

  Future<void> _findMatches(Map<String, dynamic> request) async {
    try {
      // ADD THIS CHECK - Don't find matches for non-approved requests
      final moderationStatus = request['moderationStatus'] ?? 'pending';
      if (moderationStatus != 'approved') {
        print('⚠️ Skipping match finding - request not approved (status: $moderationStatus)');
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('contributions')
          .where('status', isEqualTo: 'active')
          // ADD THIS - Only match with approved contributions
          .where('moderationStatus', isEqualTo: 'approved')
          .get();

    List<Map<String, dynamic>> matches = [];

    for (var doc in snapshot.docs) {
      try {
        final contrib = doc.data();

        // SAFE: Check category match with null safety
        final contribCategories = List<String>.from(contrib['categories'] ?? []);
        final requestCategories = List<String>.from(request['categories'] ?? []);

        bool categoryMatch = contribCategories.any((c) => requestCategories.contains(c));
        if (!categoryMatch) continue;

        // SAFE: Check if coordinates exist
        if (contrib['lat'] == null || contrib['lng'] == null) {
          print('Contribution ${doc.id} missing coordinates, skipping');
          continue;
        }

        // SAFE: Check distance (within 15km for requests - more flexible)
        double distance = _calculateDistance(
          request['lat'] as double,
          request['lng'] as double,
          contrib['lat'] as double,
          contrib['lng'] as double,
        );
        if (distance > 15) continue;

        // SAFE: Check if contribution has end date
        if (contrib['endDate'] == null) {
          print('Contribution ${doc.id} missing endDate, skipping');
          continue;
        }

        // SAFE: Check if contribution is still active (end date hasn't passed)
        try {
          DateTime contribEnd = DateTime.parse(contrib['endDate'] as String);
          if (contribEnd.isBefore(DateTime.now())) continue;
        } catch (e) {
          print('Invalid date format for contribution ${doc.id}: $e');
          continue;
        }

        // Calculate match score
        double matchScore = _calculateMatchScore(request, contrib, distance);

        // SAFE: Add contribution with null-safe data
        matches.add({
          'contribution': {
            'id': doc.id,
            'categories': contribCategories,
            'description': contrib['description'] ?? 'No description provided',
            'quantity': contrib['quantity'] ?? 'Not specified',
            'location': contrib['location'] ?? 'Location not specified',
            'lat': contrib['lat'],
            'lng': contrib['lng'],
            'contact': contrib['contact'] ?? '', // Empty string if null
            'tags': contrib['tags'] ?? [],
            'startDate': contrib['startDate'] ?? '',
            'endDate': contrib['endDate'] ?? '',
            'verified': contrib['verified'] ?? false,
          },
          'matchScore': matchScore,
          'distance': distance,
        });
      } catch (e) {
        print('Error processing contribution ${doc.id}: $e');
        continue; // Skip this contribution and continue with others
      }
    }

    matches.sort((a, b) => b['matchScore'].compareTo(a['matchScore']));

    request['matches'] = matches;
    await _saveRequests();

    setState(() {});
  } catch (e) {
    print('Error finding matches: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatableText('Error finding matches: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  double _calculateMatchScore(Map<String, dynamic> request, Map<String, dynamic> contrib, double distance) {
    double score = 100.0;

    // Distance scoring (very important for requests)
    if (distance < 1) {
      score += 30; // Very close
    } else if (distance < 3) {
      score += 20;
    } else if (distance < 5) {
      score += 10;
    } else if (distance > 10) {
      score -= 20;
    }

    // Tag matching bonus
    final requestTags = Set<String>.from(request['tags'] ?? []);
    final contribTags = Set<String>.from(contrib['tags'] ?? []);
    int commonTags = requestTags.intersection(contribTags).length;
    score += commonTags * 8;

    // Verified contributor bonus
    if (contrib['verified'] == true) {
      score += 15;
    }

    return score.clamp(0, 100);
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  Future<void> _submitRequest() async {
    // Check if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatableText('Please log in to submit requests'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is blacklisted
    final isBlacklisted = await ModerationService.isUserBlacklisted(currentUser.uid);
    if (isBlacklisted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatableText('Your account has been restricted from posting due to policy violations.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Refresh location if using current location
    if (_useCurrentLocation) {
      await _loadCurrentLocation();
    }

    String location = _useCurrentLocation
        ? _currentLocationName
        : _manualLocationController.text;

    if (location.isEmpty || _selectedCategories.isEmpty || _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatableText('Please select category and fill in quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // FIXED: Properly trim and store contact information
    final contactInfo = _contactController.text.trim();

    final request = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'userId': currentUser.uid,
      'userEmail': currentUser.email ?? 'not_provided',
      'categories': _selectedCategories.toList(),
      'location': location,
      'lat': _currentLocation.latitude,
      'lng': _currentLocation.longitude,
      'quantity': _quantityController.text,
      'remarks': _remarksController.text,
      'contact': contactInfo, // FIXED: Now properly stored
      'tags': _selectedTags.toList(),
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'active',
      'matches': [],
      'verified': false,
      'moderationStatus': 'pending',
    };

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
           TranslatableText('Submitting and checking with AI...'),
          ],
        ),
        duration: Duration(seconds: 10),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      // Step 1: Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('help_requests')
          .add(request);
      
      final firestoreId = docRef.id;
      request['firestoreId'] = firestoreId;
      
      // Step 2: Run AI Moderation (background)
      ModerationService.moderateRequest(firestoreId, request).catchError((e) {
        print('Background moderation error: $e');
      });
      
      // Step 3: Save locally
      setState(() {
        _myRequests.insert(0, request);
      });
      await _saveRequests();

      // Step 4: Find matches
      await _findMatches(request);

      // Hide loading, show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      if (mounted) {
        final matchCount = (request['matches'] as List).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatableText(matchCount > 0
                ? '✓ Request submitted! Found $matchCount match${matchCount > 1 ? 'es' : ''}! AI is reviewing it now.'
                : '✓ Request submitted! AI is reviewing it now. We\'ll notify you when help is available.'),
            backgroundColor: matchCount > 0 ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        _resetForm();
        setState(() {
          _currentView = 1;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatableText('Error saving request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  void _resetForm() {
    _manualLocationController.clear();
    _quantityController.clear();
    _remarksController.clear();
    _contactController.clear();
    setState(() {
      _selectedCategories.clear();
      _useCurrentLocation = true;
      _selectedTags.clear();
    });
  }

Future<void> _deleteRequest(String id) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const TranslatableText('Delete Request'),
      content: const TranslatableText('Are you sure you want to delete this request?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const TranslatableText('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const TranslatableText('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    try {
      // Delete from Firestore
      final request = _myRequests.firstWhere((r) => r['id'] == id);
      if (request['firestoreId'] != null) {
        await FirebaseFirestore.instance
            .collection('help_requests')
            .doc(request['firestoreId'])
            .delete();
      }
      
      // Delete locally
      setState(() {
        _myRequests.removeWhere((r) => r['id'] == id);
      });
      await _saveRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TranslatableText('Request deleted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TranslatableText('Error deleting: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

  Future<void> _markAsFulfilled(String id) async {
    setState(() {
      final index = _myRequests.indexWhere((r) => r['id'] == id);
      if (index != -1) {
        _myRequests[index]['status'] = 'fulfilled';
      }
    });
    await _saveRequests();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatableText('✓ Marked as fulfilled. Thank you!')),
      );
    }
  }


  void _editRequest(Map<String, dynamic> request) async {
    // Create temporary controllers with current values
    final tempQuantityController = TextEditingController(text: request['quantity']?.toString() ?? '');
    final tempRemarksController = TextEditingController(text: request['remarks']?.toString() ?? '');
    final tempContactController = TextEditingController(text: request['contact']?.toString() ?? '');
    
    final tempSelectedCategories = Set<String>.from(request['categories'] ?? []);
    final tempSelectedTags = Set<String>.from(request['tags'] ?? []);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const TranslatableText('Edit Request'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TranslatableText(
                    'Categories',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final isSelected = tempSelectedCategories.contains(category.id);
                      return FilterChip(
                        selected: isSelected,
                        label: TranslatableText(category.label, style: const TextStyle(fontSize: 12)),
                        selectedColor: category.color,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              tempSelectedCategories.add(category.id);
                            } else {
                              tempSelectedCategories.remove(category.id);
                              tempSelectedTags.removeWhere((tag) => 
                                _tagsByCategory[category.id]?.contains(tag) ?? false
                              );
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (tempSelectedCategories.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const TranslatableText(
                      'Preferences',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tempSelectedCategories.expand((catId) {
                        final tags = _tagsByCategory[catId] ?? [];
                        return tags.map((tag) {
                          final isSelected = tempSelectedTags.contains(tag);
                          return FilterChip(
                            label: TranslatableText(tag, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            selectedColor: Colors.purple[200],
                            checkmarkColor: Colors.purple[700],
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  tempSelectedTags.add(tag);
                                } else {
                                  tempSelectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        });
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: tempQuantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tempRemarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tempContactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const TranslatableText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (tempSelectedCategories.isEmpty || tempQuantityController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: TranslatableText('Please select category and fill in quantity')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
              ),
              child: const TranslatableText('Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // Update the request with new values
      final index = _myRequests.indexWhere((r) => r['id'] == request['id']);
      if (index != -1) {
        setState(() {
          _myRequests[index]['categories'] = tempSelectedCategories.toList();
          _myRequests[index]['tags'] = tempSelectedTags.toList();
          _myRequests[index]['quantity'] = tempQuantityController.text.trim();
          _myRequests[index]['remarks'] = tempRemarksController.text.trim();
          _myRequests[index]['contact'] = tempContactController.text.trim();
        });
        
        await _saveRequests();
        
        // Re-find matches with updated criteria
        await _findMatches(_myRequests[index]);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatableText('✓ Request updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
    
    // Dispose temporary controllers
    tempQuantityController.dispose();
    tempRemarksController.dispose();
    tempContactController.dispose();
  }

  // Navigate to Map Screen and show helper location
  void _showHelperOnMap(Map<String, dynamic> contribution, double distance) {
    final lat = contribution['lat'] as double?;
    final lng = contribution['lng'] as double?;
    
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatableText('Location not available')),
      );
      return;
    }

    final categories = (contribution['categories'] as List?)
        ?.map((e) => e.toString())
        .toList() ?? ['Helper'];
    
    final helperLocation = LatLng(lat, lng);
    final title = categories.join(' • ');
    final description = contribution['description']?.toString() ?? 'Contribution location';

    // Clear any existing snackbars before navigating
    ScaffoldMessenger.of(context).clearSnackBars();

    // Navigate to MapScreen with target location
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          targetLocation: helperLocation,
          targetTitle: title,
          targetDescription: description,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatableText('Request Help'),
        elevation: 0,
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton('Request Help', 0, Icons.add_alert),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleButton('My Requests', 1, Icons.list_alt),
                ),
              ],
            ),
          ),

          Expanded(
            child: _currentView == 0
                ? _buildRequestForm()
                : _buildMyRequests(),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgent banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[400]!, Colors.orange[400]!],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                     TranslatableText(
                        'Need Help Urgently?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                     TranslatableText(
                        'We\'ll match you with nearby helpers immediately',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const TranslatableText(
            'What do you need? *',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Category chips (horizontal scroll)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategories.contains(category.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    selected: isSelected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(category.icon, size: 18, color: isSelected ? Colors.white : category.color),
                        const SizedBox(width: 8),
                       TranslatableText(category.label),
                      ],
                    ),
                    selectedColor: category.color,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category.id);
                        } else {
                          _selectedCategories.remove(category.id);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
          const TranslatableText(
            'How much/many? *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _quantityController,
            hint: 'e.g., "3 meals" or "1 bag of clothes"',
            icon: Icons.numbers,
          ),

          const SizedBox(height: 24),
          const TranslatableText(
            'Additional Details (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _remarksController,
            hint: 'Any specific needs or preferences...',
            maxLines: 3,
            icon: Icons.note,
          ),

          const SizedBox(height: 24),
          const TranslatableText(
            'Your Location',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildLocationSection(),

          if (_selectedCategories.isNotEmpty) ...[
            const SizedBox(height: 24),
            const TranslatableText(
              'Preferences (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTagsSection(),
          ],

          const SizedBox(height: 24),
          const TranslatableText(
            'Contact (Optional but Recommended)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _contactController,
            hint: 'Phone number or preferred contact',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitRequest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.send, size: 20),
                  SizedBox(width: 8),
                 TranslatableText(
                    'Submit Urgent Request',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Radio<bool>(
                value: true,
                groupValue: _useCurrentLocation,
                onChanged: (val) => setState(() => _useCurrentLocation = true),
                activeColor: Colors.purple[600],
              ),
              Icon(Icons.my_location, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: TranslatableText(
                  _currentLocationName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Radio<bool>(
                value: false,
                groupValue: _useCurrentLocation,
                onChanged: (val) => setState(() => _useCurrentLocation = false),
                activeColor: Colors.purple[600],
              ),
              const TranslatableText('Enter manually'),
            ],
          ),
        ),
        if (!_useCurrentLocation) ...[
          const SizedBox(height: 8),
          _buildTextField(
            controller: _manualLocationController,
            hint: 'Enter your location',
            icon: Icons.location_on,
          ),
        ],
      ],
    );
  }

  Widget _buildTagsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedCategories.expand((catId) {
        final tags = _tagsByCategory[catId] ?? [];
        return tags.map((tag) {
          final isSelected = _selectedTags.contains(tag);
          return FilterChip(
            label: TranslatableText(tag, style: const TextStyle(fontSize: 13)),
            selected: isSelected,
            selectedColor: Colors.purple[200],
            checkmarkColor: Colors.purple[700],
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedTags.add(tag);
                } else {
                  _selectedTags.remove(tag);
                }
              });
            },
          );
        });
      }).toList(),
    );
  }

  Widget _buildMyRequests() {
    if (_myRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
           TranslatableText(
              'No requests yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
           TranslatableText(
              'Submit a request to get matched with helpers',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildStatusFilterChip('All', null),
              const SizedBox(width: 8),
              _buildStatusFilterChip('Active', 'active'),
              const SizedBox(width: 8),
              _buildStatusFilterChip('Fulfilled', 'fulfilled'),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _getFilteredRequests().length,
            itemBuilder: (context, index) {
              final request = _getFilteredRequests()[index];
              return _buildRequestCard(request);
            },
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredRequests() {
    if (_selectedRequestFilter == null) {
      return _myRequests;
    }
    return _myRequests
        .where((r) => r['status'] == _selectedRequestFilter)
        .toList();
  }

  Widget _buildStatusFilterChip(String label, String? status) {
    final isSelected = _selectedRequestFilter == status;
    final filteredList = status == null
        ? _myRequests
        : _myRequests.where((r) => r['status'] == status).toList();

    return FilterChip(
      label: TranslatableText('$label (${filteredList.length})'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedRequestFilter = selected ? status : null;
        });
      },
      selectedColor: Colors.purple[200],
      checkmarkColor: Colors.purple[700],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
  final isActive = request['status'] == 'active';
  final createdAt = DateTime.parse(request['createdAt']);
  final categories = List<String>.from(request['categories'] ?? []);
  final matches = List<Map<String, dynamic>>.from(request['matches'] ?? []);
  
  final moderationStatus = request['moderationStatus'] ?? 'pending';
  final riskScore = request['riskScore'] ?? 'unknown';
  final moderationReason = request['moderationReason'];
  final isApprovedForMatching = moderationStatus == 'approved';
  
  // Determine status colors
  Color statusColor;
  String statusText;
  IconData statusIcon;
  
  switch (moderationStatus) {
    case 'approved':
      statusColor = Colors.green;
      statusText = 'APPROVED';
      statusIcon = Icons.check_circle;
      break;
    case 'flagged':
      statusColor = Colors.orange;
      statusText = 'UNDER REVIEW';
      statusIcon = Icons.flag;
      break;
    case 'rejected':
      statusColor = Colors.red;
      statusText = 'REJECTED';
      statusIcon = Icons.cancel;
      break;
    case 'error':
      statusColor = Colors.grey;
      statusText = 'ERROR';
      statusIcon = Icons.error;
      break;
    default:
      statusColor = Colors.blue;
      statusText = 'CHECKING...';
      statusIcon = Icons.hourglass_empty;
  }

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing header container...
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive 
                  ? [Colors.purple[400]!, Colors.purple[600]!]
                  : [Colors.grey[300]!, Colors.grey[400]!],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   TranslatableText(
                      categories.join(' • '),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                   TranslatableText(
                      DateFormat('MMM dd, yyyy - h:mm a').format(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (moderationStatus != 'approved')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: statusColor.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                     TranslatableText(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (moderationStatus == 'flagged' && moderationReason != null)
                       TranslatableText(
                          moderationReason,
                          style: TextStyle(
                            color: statusColor.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (moderationStatus == 'rejected' && moderationReason != null)
                       TranslatableText(
                          moderationReason,
                          style: TextStyle(
                            color: statusColor.withOpacity(0.8),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (moderationStatus == 'pending')
                       TranslatableText(
                          'AI is reviewing your request...',
                          style: TextStyle(
                            color: statusColor.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (riskScore != 'unknown' && riskScore != 'low')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskScore == 'high' ? Colors.red : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TranslatableText(
                      riskScore.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.numbers, '${request['quantity']}'),
                if (request['remarks'] != null && request['remarks'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.note, request['remarks']),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on, request['location']),

         if (isApprovedForMatching && matches.isNotEmpty) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _showMatchesDialog(request),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[400]!, Colors.green[600]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                             TranslatableText(
                                '${matches.length} Helper${matches.length > 1 ? 's' : ''} Found!',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const TranslatableText(
                                'Tap to view and contact',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ] else if (isActive && isApprovedForMatching) ...[
                // Only show "searching" if approved
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.orange[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TranslatableText(
                          'Searching for helpers nearby...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isActive && !isApprovedForMatching) ...[
                // ADD THIS - Show message when not approved
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_empty, color: Colors.grey[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TranslatableText(
                          moderationStatus == 'pending' 
                            ? 'Matching will begin after AI approval'
                            : 'This request cannot be matched at this time',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]else if (isActive) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.orange[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TranslatableText(
                            'Searching for helpers nearby...',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if ((request['tags'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (request['tags'] as List).map((tag) {
                      return Chip(
                        label: TranslatableText(tag, style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.purple[50],
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          if (isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editRequest(request),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const TranslatableText('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple[600],
                        side: BorderSide(color: Colors.purple[600]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (matches.isEmpty && isApprovedForMatching) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _findMatches(request);
                          setState(() {});
                          if (mounted) {
                            final newMatches = (request['matches'] as List).length;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: TranslatableText(newMatches > 0
                                    ? 'Found $newMatches match${newMatches > 1 ? 'es' : ''}!'
                                    : 'No matches yet. Will keep searching.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const TranslatableText('Refresh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsFulfilled(request['id']),
                      icon: const Icon(Icons.check, size: 18),
                      label: const TranslatableText('Got Help'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteRequest(request['id']),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showMatchesDialog(Map<String, dynamic> request) {
    final matches = List<Map<String, dynamic>>.from(request['matches'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                         TranslatableText(
                            '${matches.length} Helper${matches.length > 1 ? 's' : ''} Available',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const TranslatableText(
                            'Choose the best match for you',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    try {
                      final match = matches[index];
                      final contrib = match['contribution'] as Map<String, dynamic>;
                      final score = (match['matchScore'] as num?)?.toDouble() ?? 0.0;
                      final distance = (match['distance'] as num?)?.toDouble() ?? 0.0;

                      // SAFE: Get categories with fallback
                      final categories = (contrib['categories'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ?? ['Unknown'];

                      String matchQuality = score >= 90
                          ? '⭐⭐⭐ Perfect Match'
                          : score >= 70
                              ? '⭐⭐ Great Match'
                              : '⭐ Good Match';

                      Color qualityColor = score >= 90
                          ? Colors.green
                          : score >= 70
                              ? Colors.blue
                              : Colors.orange;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TranslatableText(
                                      categories.join(' • '),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: qualityColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: qualityColor, width: 1.5),
                                    ),
                                    child: TranslatableText(
                                      matchQuality,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: qualityColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                             TranslatableText(
                                contrib['description']?.toString() ?? 'No description',
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // MODIFIED: Make location tappable with visual indication
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(context); // Close matches dialog
                                      _showHelperOnMap(contrib, distance);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.blue[300]!),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                                          const SizedBox(width: 4),
                                         TranslatableText(
                                            '${distance.toStringAsFixed(1)} km away',
                                            style: TextStyle(
                                              fontSize: 13, 
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.map, size: 14, color: Colors.blue[700]),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.inventory_2, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                 TranslatableText(
                                    '${contrib['quantity']?.toString() ?? 'N/A'} available',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              // SAFE: Check if contact exists and is not empty
                              if (contrib['contact'] != null && 
                                  contrib['contact'].toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green[300]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.phone, size: 16, color: Colors.green[700]),
                                          const SizedBox(width: 8),
                                          const TranslatableText(
                                            'Contact Information',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TranslatableText(
                                              contrib['contact'].toString(),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[900],
                                              ),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(
                                                ClipboardData(text: contrib['contact'].toString()),
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: const TranslatableText('✓ Contact copied to clipboard'),
                                                  backgroundColor: Colors.green[700],
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.copy, size: 16),
                                            label: const TranslatableText('Copy'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.green[700],
                                              backgroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 18, color: Colors.orange[700]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TranslatableText(
                                          'No contact info provided. Check location on map.',
                                          style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    } catch (e) {
                      // If there's an error with this specific match, show an error card
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TranslatableText(
                            'Error loading match: ${e.toString()}',
                            style: TextStyle(color: Colors.red[900]),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: TranslatableText(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(String label, int index, IconData icon) {
    final isSelected = _currentView == index;
    return ElevatedButton.icon(
      onPressed: () {
        setState(() => _currentView = index);
        if (index == 1) {
          _syncModerationStatus(); // Sync when viewing requests
        }
      },
      icon: Icon(icon, size: 20),
      label: TranslatableText(label, style: const TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.purple[600] : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: isSelected ? 3 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}