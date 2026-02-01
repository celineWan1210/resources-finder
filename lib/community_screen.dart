import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class CommunityResource {
  final String id;
  final String type;
  final List<String> categories;
  final String description;
  final String location;
  final double lat;
  final double lng;
  final String quantity;
  final String? contact;
  final List<String> tags;
  final DateTime startDate;
  final DateTime endDate;
  final String startTime;
  final String endTime;
  final String status;
  final DateTime createdAt;
  final double distance;
  final String moderationStatus;
  final String riskScore;
  final bool verified;

  CommunityResource({
    required this.id,
    required this.type,
    required this.categories,
    required this.description,
    required this.location,
    required this.lat,
    required this.lng,
    required this.quantity,
    this.contact,
    required this.tags,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    required this.distance,
    required this.moderationStatus,
    required this.riskScore,
    required this.verified,
  });

  factory CommunityResource.fromFirestore(DocumentSnapshot doc, LatLng userLocation) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Calculate distance
    double distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      data['lat'] as double,
      data['lng'] as double,
    ) / 1000; // Convert to km

    return CommunityResource(
      id: doc.id,
      type: data['type'] ?? 'community',
      categories: List<String>.from(data['categories'] ?? []),
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      lat: data['lat'] ?? 0.0,
      lng: data['lng'] ?? 0.0,
      quantity: data['quantity'] ?? '',
      contact: data['contact'],
      tags: List<String>.from(data['tags'] ?? []),
      startDate: DateTime.parse(data['startDate']),
      endDate: DateTime.parse(data['endDate']),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: DateTime.parse(data['createdAt']),
      distance: distance,
      moderationStatus: data['moderationStatus'] ?? 'pending',
      riskScore: data['riskScore'] ?? 'unknown',
      verified: data['verified'] ?? false,
    );
  }
}

class _CommunityScreenState extends State<CommunityScreen> {
  LatLng _currentLocation = LocationService.defaultLocation;
  String? _selectedFilter; // null = all, 'food', 'shelter', 'community'
  String _sortBy = 'distance'; // 'distance', 'date', 'type'
  bool _isLoading = true;
  bool _showOnlyVerified = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    final result = await LocationService.getCurrentLocation();
    setState(() {
      _currentLocation = result.location;
      _isLoading = false;
    });
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m away';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km away';
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'food':
        return Icons.restaurant;
      case 'shelter':
        return Icons.home;
      default:
        return Icons.volunteer_activism;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'food':
        return Colors.orange;
      case 'shelter':
        return const Color.fromARGB(175, 233, 30, 98);
      default:
        return Colors.purple;
    }
  }

  List<CommunityResource> _sortResources(List<CommunityResource> resources) {
    switch (_sortBy) {
      case 'distance':
        resources.sort((a, b) => a.distance.compareTo(b.distance));
        break;
      case 'date':
        resources.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'type':
        resources.sort((a, b) => a.type.compareTo(b.type));
        break;
    }
    return resources;
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _openDirections(double lat, double lng) async {
    final Uri googleMapsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    }
  }

  void _showResourceDetails(CommunityResource resource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getColorForType(resource.type).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIconForType(resource.type),
                          color: _getColorForType(resource.type),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Community Contribution',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              resource.categories.join(' • '),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (resource.verified) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'AI Verified',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // AI Verification Banner
                  if (resource.verified)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This contribution has been verified by AI moderation',
                              style: TextStyle(
                                color: Colors.green[900],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (resource.verified)
                    const SizedBox(height: 20),

                  // Description
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getColorForType(resource.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      resource.description,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Details
                  _buildInfoRow(
                    Icons.numbers,
                    'Quantity',
                    resource.quantity,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_on,
                    'Location',
                    resource.location,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.directions_walk,
                    'Distance',
                    _formatDistance(resource.distance),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Available',
                    '${DateFormat('MMM dd').format(resource.startDate)} - ${DateFormat('MMM dd, yyyy').format(resource.endDate)}',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.access_time,
                    'Hours',
                    '${resource.startTime} - ${resource.endTime}',
                  ),

                  if (resource.contact != null && resource.contact!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.phone,
                      'Contact',
                      resource.contact!,
                      onTap: () => _launchPhone(resource.contact!),
                    ),
                  ],

                  if (resource.tags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: resource.tags.map((tag) {
                        return Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          backgroundColor: _getColorForType(resource.type).withOpacity(0.2),
                          padding: const EdgeInsets.all(4),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  
                  // Action buttons
                  ElevatedButton.icon(
                    onPressed: () => _openDirections(resource.lat, resource.lng),
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(15),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: onTap != null ? Colors.blue : Colors.black,
                    decoration: onTap != null ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Resources'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple[700]!, Colors.purple[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'distance',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'distance' ? Icons.check : Icons.directions_walk,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Distance'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'date' ? Icons.check : Icons.calendar_today,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Most Recent'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'type',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'type' ? Icons.check : Icons.category,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Type'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.purple[50],
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', null, Icons.apps),
                      const SizedBox(width: 8),
                      _buildFilterChip('Food', 'food', Icons.restaurant),
                      const SizedBox(width: 8),
                      _buildFilterChip('Shelter', 'shelter', Icons.home),
                      const SizedBox(width: 8),
                      _buildFilterChip('Community', 'community', Icons.volunteer_activism),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Verification filter
                CheckboxListTile(
                  title: const Text(
                    'Show only AI-verified contributions',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: _showOnlyVerified,
                  onChanged: (value) {
                    setState(() {
                      _showOnlyVerified = value ?? false;
                    });
                  },
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Resources list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('contributions')
                        .where('status', isEqualTo: 'active')
                        .where('moderationStatus', isEqualTo: 'approved') // Only show approved
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${snapshot.error}'),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No community resources available',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check back later for new contributions',
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }

                      // Convert to CommunityResource objects
                      List<CommunityResource> resources = snapshot.data!.docs
                          .map((doc) => CommunityResource.fromFirestore(doc, _currentLocation))
                          .toList();

                      // Apply type filter
                      if (_selectedFilter != null) {
                        resources = resources.where((r) => r.type == _selectedFilter).toList();
                      }

                      // Apply verification filter
                      if (_showOnlyVerified) {
                        resources = resources.where((r) => r.verified).toList();
                      }

                      // Apply sorting
                      resources = _sortResources(resources);

                      // Filter out expired contributions
                      resources = resources.where((r) => r.endDate.isAfter(DateTime.now())).toList();

                      if (resources.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == null
                                    ? 'No active resources found'
                                    : 'No ${_selectedFilter} resources found',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _showOnlyVerified 
                                    ? 'Try removing the verification filter'
                                    : 'Check back later for new contributions',
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: resources.length,
                        itemBuilder: (context, index) {
                          return _buildResourceCard(resources[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? type, IconData icon) {
    final isSelected = _selectedFilter == type;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? type : null;
        });
      },
      selectedColor: type != null 
          ? _getColorForType(type).withOpacity(0.3) 
          : Colors.purple.withOpacity(0.3),
      checkmarkColor: type != null ? _getColorForType(type) : Colors.purple,
    );
  }

  Widget _buildResourceCard(CommunityResource resource) {
    final color = _getColorForType(resource.type);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showResourceDetails(resource),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: color,
                        child: Icon(
                          _getIconForType(resource.type),
                          color: Colors.white,
                        ),
                      ),
                      if (resource.verified)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.categories.join(' • '),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Posted ${DateFormat('MMM dd, yyyy').format(resource.createdAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (resource.verified) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.verified, size: 14, color: Colors.blue),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      resource.type.toUpperCase(),
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
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.description,
                    style: const TextStyle(fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          resource.location,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.directions_walk, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        _formatDistance(resource.distance),
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Until ${DateFormat('MMM dd').format(resource.endDate)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  
                  if (resource.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: resource.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}