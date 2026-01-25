import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'services/firestore_service.dart';


class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class ContributionCategory {
  final String id;
  final String label;
  final IconData icon;
  final String description;
  final Color color;

  ContributionCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.color,
  });
}

class _ContributionScreenState extends State<ContributionScreen> {
  int _currentView = 0; // 0 = Contribute, 1 = My Contributions
  int _contributionStep = 1; // 1 = Select Category, 2 = Fill Details
  final FirestoreService _firestoreService = FirestoreService();
  
  // Step 1: Category selection
  Set<String> _selectedCategories = {};
  final List<ContributionCategory> _categories = [
    ContributionCategory(
      id: 'food',
      label: 'Food',
      icon: Icons.restaurant,
      description: 'Meals, groceries, or food packages',
      color: Colors.orange,
    ),
    ContributionCategory(
      id: 'shelter',
      label: 'Temporary Shelter',
      icon: Icons.home,
      description: 'Safe place to stay for nights',
      color: Colors.blue,
    ),
    ContributionCategory(
      id: 'clothes',
      label: 'Clothes',
      icon: Icons.shopping_bag,
      description: 'Clothing items for any season',
      color: Colors.purple,
    ),
    ContributionCategory(
      id: 'hygiene',
      label: 'Hygiene Kits',
      icon: Icons.cleaning_services,
      description: 'Soap, pads, diapers, toothpaste',
      color: Colors.teal,
    ),
    ContributionCategory(
      id: 'transport',
      label: 'Transportation',
      icon: Icons.directions_car,
      description: 'Ride to clinic, shelter, or appointment',
      color: Colors.green,
    ),
    ContributionCategory(
      id: 'supplies',
      label: 'Supplies',
      icon: Icons.card_giftcard,
      description: 'Blankets, school supplies, essentials',
      color: Colors.red,
    ),
    ContributionCategory(
      id: 'volunteer',
      label: 'Volunteering',
      icon: Icons.volunteer_activism,
      description: 'Help cook, pack, clean, or mentor',
      color: Colors.indigo,
    ),
  ];

  // Step 2: Detail fields
  bool _useCurrentLocation = true;
  final TextEditingController _manualLocationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Hardcoded KL location
  final LatLng _currentLocation = const LatLng(3.1390, 101.6869);
  final String _currentLocationName = 'Kuala Lumpur, Malaysia';

  // Time availability
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);

  // Tags/Categories
  final Map<String, List<String>> _tagsByCategory = {
    'food': ['Halal', 'Vegetarian', 'Vegan', 'Non-Halal', 'Dry Food', 'Perishable'],
    'shelter': ['Emergency', 'Short-term', 'Long-term', 'Family-friendly', 'Pet-friendly'],
    'clothes': ['Men', 'Women', 'Children', 'Winter', 'Summer'],
    'hygiene': ['Soap', 'Feminine Products', 'Diapers', 'Toothpaste', 'Deodorant'],
    'transport': ['Medical', 'Emergency', 'Daily', 'Long-distance'],
    'supplies': ['Blankets', 'School Supplies', 'Bedding', 'Kitchen Items'],
    'volunteer': ['Cooking', 'Packing', 'Cleaning', 'Mentoring', 'Teaching'],
  };
  Set<String> _selectedTags = {};

  // Store contributions
  List<Map<String, dynamic>> _myContributions = [];
  String? _selectedContributionFilter = null;

  @override
  void initState() {
    super.initState();
    _loadContributions();
  }

  Future<void> _loadContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? contributionsJson = prefs.getString('my_contributions');
    
    if (contributionsJson != null) {
      final List<dynamic> decoded = json.decode(contributionsJson);
      setState(() {
        _myContributions = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _myContributions.sort((a, b) => 
          DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt']))
        );
      });
    }
  }

  Future<void> _saveContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_myContributions);
    await prefs.setString('my_contributions', encoded);
    await _saveToGlobalContributions();
  }

  Future<void> _saveToGlobalContributions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? globalJson = prefs.getString('global_contributions');
    
    List<Map<String, dynamic>> globalContributions = [];
    if (globalJson != null) {
      final List<dynamic> decoded = json.decode(globalJson);
      globalContributions = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    
    for (var contribution in _myContributions) {
      if (contribution['status'] == 'active') {
        bool exists = globalContributions.any((c) => c['id'] == contribution['id']);
        if (!exists) {
          globalContributions.add(contribution);
        } else {
          int index = globalContributions.indexWhere((c) => c['id'] == contribution['id']);
          globalContributions[index] = contribution;
        }
      }
    }
    
    await prefs.setString('global_contributions', json.encode(globalContributions));
  }

  void _proceedToDetails() {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one contribution type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _contributionStep = 2;
    });
  }

  void _goBackToSelection() {
    setState(() {
      _contributionStep = 1;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submitContribution() async {  // Add async here
    String location = _useCurrentLocation
        ? _currentLocationName
        : _manualLocationController.text;

    if (location.isEmpty || _descriptionController.text.isEmpty || 
        _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Combine selected categories into a single type for map filtering
    // Combine selected categories into a single type for filtering (Food / Shelter / Community)
    String contributionType;

    if (_selectedCategories.length == 1) {
      if (_selectedCategories.contains('food')) {
        contributionType = 'food';        // Food only
      } else if (_selectedCategories.contains('shelter')) {
        contributionType = 'shelter';     // Shelter only
      } else {
        contributionType = 'community';  // Any other single category
      }
    } else {
      // Multiple categories selected
      if (_selectedCategories.contains('food') &&
          _selectedCategories.contains('shelter') &&
          _selectedCategories.length == 2) {
        contributionType = 'community';  // Food + Shelter
      } else {
        contributionType = 'community';  // Any other mix
      }
    }

    final contribution = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': contributionType,
      'categories': _selectedCategories.toList(),
      'location': location,
      'lat': _currentLocation.latitude,
      'lng': _currentLocation.longitude,
      'description': _descriptionController.text,
      'quantity': _quantityController.text,
      'contact': _contactController.text,
      'tags': _selectedTags.toList(),
      'startDate': _startDate.toIso8601String(),
      'endDate': _endDate.toIso8601String(),
      'startTime': '${_startTime.hour}:${_startTime.minute}',
      'endTime': '${_endTime.hour}:${_endTime.minute}',
      'image': _selectedImage?.name ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'active',
      'verified': false,
    };

    try {
      // Save to Firestore FIRST
      await _firestoreService.addContribution(contribution);
      
      // Then save locally (this maintains your existing local storage logic)
      setState(() {
        _myContributions.insert(0, contribution);
      });

      _saveContributions();  // Your existing method to save to SharedPreferences

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Contribution submitted successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      _resetForm();
      setState(() {
        _currentView = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving contribution: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetForm() {
    _manualLocationController.clear();
    _descriptionController.clear();
    _quantityController.clear();
    _contactController.clear();
    setState(() {
      _selectedImage = null;
      _selectedCategories.clear();
      _useCurrentLocation = true;
      _selectedTags.clear();
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 7));
      _startTime = TimeOfDay.now();
      _endTime = const TimeOfDay(hour: 18, minute: 0);
      _contributionStep = 1;
    });
  }

  Future<void> _deleteContribution(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contribution'),
        content: const Text('Are you sure you want to delete this contribution?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Delete from Firestore
        final contribution = _myContributions.firstWhere((c) => c['id'] == id);
        if (contribution['firestoreId'] != null) {
          await _firestoreService.deleteContribution(contribution['firestoreId']);
        }
        
        // Delete locally
        setState(() {
          _myContributions.removeWhere((c) => c['id'] == id);
        });
        await _saveContributions();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contribution deleted')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markAsCompleted(String id) async {
    try {
      final contribution = _myContributions.firstWhere((c) => c['id'] == id);
      
      // Update in Firestore
      if (contribution['firestoreId'] != null) {
        await _firestoreService.updateContributionStatus(
          contribution['firestoreId'], 
          'completed'
        );
      }
      
      // Update locally
      setState(() {
        final index = _myContributions.indexWhere((c) => c['id'] == id);
        if (index != -1) {
          _myContributions[index]['status'] = 'completed';
        }
      });
      await _saveContributions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as completed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Contribution'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton('Contribute', 0, Icons.add_circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleButton('My Contributions', 1, Icons.list_alt),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _currentView == 0 
                ? _buildContributeFlow()
                : _buildMyContributions(),
          ),
        ],
      ),
    );
  }

  Widget _buildContributeFlow() {
    if (_contributionStep == 1) {
      return _buildCategorySelection();
    } else {
      return _buildContributionDetails();
    }
  }

  Widget _buildCategorySelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 1 of 2: What can you contribute?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select one or more categories',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              return _buildCategoryCard(_categories[index]);
            },
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceedToDetails,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue to Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
Widget _buildCategoryCard(ContributionCategory category) {
  final isSelected = _selectedCategories.contains(category.id);

  return GestureDetector(
    onTap: () {
      setState(() {
        if (isSelected) {
          _selectedCategories.remove(category.id);
        } else {
          _selectedCategories.add(category.id);
        }
      });
    },
    child: Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(
        minHeight: 160, // make the card taller
      ),
      decoration: BoxDecoration(
        color: isSelected ? category.color.withOpacity(0.2) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? category.color : Colors.grey[300]!,
          width: isSelected ? 3 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            category.icon,
            size: 40,
            color: category.color,
          ),
          const SizedBox(height: 12),
          Text(
            category.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            maxLines: 3, // allow more lines
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          if (isSelected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
        ],
      ),
    ),
  );
}



  // Generic TextField builder
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
      fillColor: Colors.grey[100],
    ),
  );
}

// Location section with toggle between current & manual location
Widget _buildLocationSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Radio<bool>(
            value: true,
            groupValue: _useCurrentLocation,
            onChanged: (val) => setState(() => _useCurrentLocation = true),
          ),
          const Text('Use Current Location'),
          const SizedBox(width: 16),
          Radio<bool>(
            value: false,
            groupValue: _useCurrentLocation,
            onChanged: (val) => setState(() => _useCurrentLocation = false),
          ),
          const Text('Enter Manually'),
        ],
      ),
      if (!_useCurrentLocation)
        _buildTextField(
          controller: _manualLocationController,
          hint: 'Enter location',
          icon: Icons.location_on,
        ),
    ],
  );
}

// Availability section with date and time pickers
Widget _buildAvailabilitySection() {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _selectDate(context, true),
              child: Text('Start Date: ${DateFormat('MMM dd, yyyy').format(_startDate)}'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _selectDate(context, false),
              child: Text('End Date: ${DateFormat('MMM dd, yyyy').format(_endDate)}'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _selectTime(context, true),
              child: Text('Start Time: ${_startTime.format(context)}'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _selectTime(context, false),
              child: Text('End Time: ${_endTime.format(context)}'),
            ),
          ),
        ],
      ),
    ],
  );
}

// Tags / category selection
Widget _buildTagsSection() {
  List<String> allTags = [];
  for (var catId in _selectedCategories) {
    allTags.addAll(_tagsByCategory[catId] ?? []);
  }
  allTags = allTags.toSet().toList(); // remove duplicates

  return Wrap(
    spacing: 8,
    children: allTags.map((tag) {
      final isSelected = _selectedTags.contains(tag);
      return FilterChip(
        label: Text(tag),
        selected: isSelected,
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
    }).toList(),
  );
}

// Image picker / upload
Widget _buildImageUpload() {
  return GestureDetector(
    onTap: _pickImage,
    child: Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[100],
      ),
      child: _selectedImage == null
          ? const Icon(Icons.camera_alt, size: 50, color: Colors.grey)
          : Image.file(
              File(_selectedImage!.path),
              fit: BoxFit.cover,
            ),
    ),
  );
}


  Widget _buildContributionDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step 2 of 2: Fill in the details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            children: _selectedCategories.map((catId) {
              final category = _categories.firstWhere((c) => c.id == catId);
              return Chip(
                label: Text(category.label),
                backgroundColor: category.color.withOpacity(0.3),
                deleteIcon: const Icon(Icons.edit),
                onDeleted: _goBackToSelection,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Details *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _descriptionController,
            hint: 'Describe what you can provide',
            maxLines: 3,
            icon: Icons.description,
          ),
          
          const SizedBox(height: 16),
          _buildTextField(
            controller: _quantityController,
            hint: 'Quantity or number of items/people',
            icon: Icons.numbers,
            keyboardType: TextInputType.number,
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Location',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildLocationSection(),
          
          const SizedBox(height: 24),
          const Text(
            'Availability',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAvailabilitySection(),
          
          const SizedBox(height: 24),
          const Text(
            'Categories (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTagsSection(),
          
          const SizedBox(height: 24),
          const Text(
            'Contact Information (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _contactController,
            hint: 'Phone number or email',
            icon: Icons.contact_phone,
            keyboardType: TextInputType.phone,
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Photo (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildImageUpload(),
          
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _goBackToSelection,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitContribution,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMyContributions() {
    if (_myContributions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No contributions yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeFilterChip('All', null),
                const SizedBox(width: 8),
                _buildTypeFilterChip('Food', 'food'),
                const SizedBox(width: 8),
                _buildTypeFilterChip('Shelter', 'shelter'),
                const SizedBox(width: 8),
                _buildTypeFilterChip('Community', 'community'),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _getFilteredContributions().length,
            itemBuilder: (context, index) {
              final contribution = _getFilteredContributions()[index];
              return _buildContributionCard(contribution);
            },
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredContributions() {
    if (_selectedContributionFilter == null) {
      return _myContributions;
    }
    return _myContributions
        .where((c) => c['type'] == _selectedContributionFilter)
        .toList();
  }

  Widget _buildTypeFilterChip(String label, String? type) {
    final isSelected = _selectedContributionFilter == type;
    final filteredList = type == null
        ? _myContributions
        : _myContributions.where((c) => c['type'] == type).toList();
    
    return FilterChip(
      label: Text('$label (${filteredList.length})'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedContributionFilter = selected ? type : null;
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildContributionCard(Map<String, dynamic> contribution) {
    final isActive = contribution['status'] == 'active';
    final startDate = DateTime.parse(contribution['startDate']);
    final endDate = DateTime.parse(contribution['endDate']);
    final createdAt = DateTime.parse(contribution['createdAt']);
    final categories = List<String>.from(contribution['categories'] ?? []);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.green[50] : Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categories.join(', '),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.green[900] : Colors.grey[700],
                        ),
                      ),
                      Text(
                        'Posted ${DateFormat('MMM dd, yyyy').format(createdAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'COMPLETED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
                _buildInfoRow(Icons.description, contribution['description']),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.numbers, '${contribution['quantity']} items'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on, contribution['location']),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.calendar_today,
                  '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.access_time,
                  '${contribution['startTime']} - ${contribution['endTime']}',
                ),
                
                if (contribution['contact'] != null && contribution['contact'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.phone, contribution['contact']),
                ],
                
                if ((contribution['tags'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (contribution['tags'] as List).map((tag) {
                      return Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue[50],
                        padding: const EdgeInsets.all(4),
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
                      onPressed: () => _markAsCompleted(contribution['id']),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Mark Complete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteContribution(contribution['id']),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
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
      onPressed: () => setState(() => _currentView = index),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}