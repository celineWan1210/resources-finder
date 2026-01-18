import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  int _currentView = 0; // 0 = Contribute, 1 = My Contributions
  
  String _contributionType = 'Food';
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
  final List<String> _foodTags = ['Halal', 'Vegetarian', 'Vegan', 'Non-Halal', 'Dry Food', 'Perishable'];
  final List<String> _shelterTags = ['Emergency', 'Short-term', 'Long-term', 'Family-friendly', 'Pet-friendly'];
  Set<String> _selectedTags = {};

  // Store contributions
  List<Map<String, dynamic>> _myContributions = [];

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
        // Sort by date, newest first
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
    
    // Also save to global contributions for MapScreen
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
    
    // Add all my active contributions to global
    for (var contribution in _myContributions) {
      if (contribution['status'] == 'active') {
        bool exists = globalContributions.any((c) => c['id'] == contribution['id']);
        if (!exists) {
          globalContributions.add(contribution);
        } else {
          // Update existing
          int index = globalContributions.indexWhere((c) => c['id'] == contribution['id']);
          globalContributions[index] = contribution;
        }
      }
    }
    
    await prefs.setString('global_contributions', json.encode(globalContributions));
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

  void _submitContribution() {
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

    final contribution = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': _contributionType,
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

    setState(() {
      _myContributions.insert(0, contribution);
    });

    _saveContributions();

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
      _currentView = 1; // Switch to My Contributions view
    });
  }

  void _resetForm() {
    _manualLocationController.clear();
    _descriptionController.clear();
    _quantityController.clear();
    _contactController.clear();
    setState(() {
      _selectedImage = null;
      _contributionType = 'Food';
      _useCurrentLocation = true;
      _selectedTags.clear();
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 7));
      _startTime = TimeOfDay.now();
      _endTime = const TimeOfDay(hour: 18, minute: 0);
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
      setState(() {
        _myContributions.removeWhere((c) => c['id'] == id);
      });
      await _saveContributions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contribution deleted')),
        );
      }
    }
  }

  Future<void> _markAsCompleted(String id) async {
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
          // Toggle Buttons
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
          
          // Content
          Expanded(
            child: _currentView == 0 
                ? _buildContributeForm() 
                : _buildMyContributions(),
          ),
        ],
      ),
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

  Widget _buildContributeForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('What are you offering?'),
          const SizedBox(height: 12),
          _buildContributionTypeSelector(),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Location'),
          const SizedBox(height: 12),
          _buildLocationSection(),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Details', required: true),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _descriptionController,
            hint: 'Describe what you can provide (e.g., "50 packed meals", "2 rooms available")',
            maxLines: 3,
            icon: Icons.description,
          ),
          
          const SizedBox(height: 16),
          _buildTextField(
            controller: _quantityController,
            hint: _contributionType == 'Food' 
                ? 'Number of meals/packages' 
                : 'Number of people you can host',
            icon: Icons.numbers,
            keyboardType: TextInputType.number,
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Availability'),
          const SizedBox(height: 12),
          _buildAvailabilitySection(),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Categories (Optional)'),
          const SizedBox(height: 12),
          _buildTagsSection(),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Contact Information (Optional)'),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _contactController,
            hint: 'Phone number or email',
            icon: Icons.contact_phone,
            keyboardType: TextInputType.phone,
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('Photo (Optional)'),
          const SizedBox(height: 12),
          _buildImageUpload(),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitContribution,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Submit Contribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
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
            const SizedBox(height: 8),
            Text(
              'Start helping your community!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myContributions.length,
      itemBuilder: (context, index) {
        final contribution = _myContributions[index];
        return _buildContributionCard(contribution);
      },
    );
  }

  Widget _buildContributionCard(Map<String, dynamic> contribution) {
    final isActive = contribution['status'] == 'active';
    final startDate = DateTime.parse(contribution['startDate']);
    final endDate = DateTime.parse(contribution['endDate']);
    final createdAt = DateTime.parse(contribution['createdAt']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                  contribution['type'] == 'Food' ? Icons.restaurant : 
                  contribution['type'] == 'Shelter' ? Icons.home : Icons.favorite,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contribution['type'],
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
          
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.description, contribution['description']),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.numbers,
                  '${contribution['quantity']} ${contribution['type'] == 'Food' ? 'meals/packages' : 'people'}',
                ),
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
          
          // Actions
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

  Widget _buildSectionTitle(String title, {bool required = false}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildContributionTypeSelector() {
    return Row(
      children: [
        Expanded(child: _buildTypeCard('Food', Icons.restaurant)),
        const SizedBox(width: 12),
        Expanded(child: _buildTypeCard('Shelter', Icons.home)),
        const SizedBox(width: 12),
        Expanded(child: _buildTypeCard('Both', Icons.favorite)),
      ],
    );
  }

  Widget _buildTypeCard(String type, IconData icon) {
    final isSelected = _contributionType == type;
    return InkWell(
      onTap: () => setState(() => _contributionType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[700], size: 32),
            const SizedBox(height: 8),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      children: [
        SwitchListTile(
          title: Text('Use current location ($_currentLocationName)'),
          subtitle: const Text('Kuala Lumpur area'),
          value: _useCurrentLocation,
          onChanged: (value) => setState(() => _useCurrentLocation = value),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          tileColor: Colors.grey[100],
        ),
        if (!_useCurrentLocation) ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _manualLocationController,
            hint: 'Enter specific address or area',
            icon: Icons.edit_location,
          ),
        ],
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateButton('Start', _startDate, true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateButton('End', _endDate, false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeButton('From', _startTime, true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeButton('To', _endTime, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime date, bool isStart) {
    return InkWell(
      onTap: () => _selectDate(context, isStart),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(DateFormat('MMM dd, yyyy').format(date)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, TimeOfDay time, bool isStart) {
    return InkWell(
      onTap: () => _selectTime(context, isStart),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Text(time.format(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    final availableTags = _contributionType == 'Food' ? _foodTags : _shelterTags;
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableTags.map((tag) {
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
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
          checkmarkColor: Theme.of(context).primaryColor,
        );
      }).toList(),
    );
  }

  Widget _buildImageUpload() {
    return InkWell(
      onTap: _pickImage,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(
              _selectedImage != null ? Icons.check_circle : Icons.add_photo_alternate,
              size: 48,
              color: _selectedImage != null ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedImage != null 
                  ? 'Photo selected: ${_selectedImage!.name}' 
                  : 'Tap to upload photo',
              style: TextStyle(
                color: _selectedImage != null ? Colors.green : Colors.grey[700],
                fontWeight: _selectedImage != null ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manualLocationController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _contactController.dispose();
    super.dispose();
  }
}