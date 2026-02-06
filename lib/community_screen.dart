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
    );
  }
}

class _CommunityScreenState extends State<CommunityScreen> {
  GoogleMapController? mapController;
  LatLng _currentLocation = LocationService.defaultLocation;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  
  // All categories checked by default
  final Map<String, bool> _categoryFilters = {
    'food': true,
    'shelter': true,
    'clothes': true,
    'hygiene': true,
    'transport': true,
    'supplies': true,
    'volunteer': true,
  };

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
      case 'clothes':
        return Icons.shopping_bag;
      case 'hygiene':
        return Icons.cleaning_services;
      case 'transport':
        return Icons.directions_car;
      case 'supplies':
        return Icons.card_giftcard;
      case 'volunteer':
        return Icons.volunteer_activism;
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
      case 'clothes':
        return Colors.purple;
      case 'hygiene':
        return Colors.teal;
      case 'transport':
        return Colors.green;
      case 'supplies':
        return Colors.red;
      case 'volunteer':
        return Colors.indigo;
      default:
        return Colors.purple;
    }
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

  void _updateMarkers(List<CommunityResource> resources) {
    _markers.clear();
    
    for (var resource in resources) {
      final marker = Marker(
        markerId: MarkerId(resource.id),
        position: LatLng(resource.lat, resource.lng),
        infoWindow: InfoWindow(
          title: resource.categories.join(' • '),
          snippet: _formatDistance(resource.distance),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _getMarkerHue(resource.type),
        ),
        onTap: () => _showResourceDetails(resource),
      );
      
      _markers.add(marker);
    }

    if (_markers.isNotEmpty && mapController != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _fitMarkersInView();
      });
    }
  }

  double _getMarkerHue(String type) {
    switch (type) {
      case 'food':
        return BitmapDescriptor.hueOrange;
      case 'shelter':
        return BitmapDescriptor.hueRose;
      case 'clothes':
        return BitmapDescriptor.hueViolet;
      case 'hygiene':
        return BitmapDescriptor.hueCyan;
      case 'transport':
        return BitmapDescriptor.hueGreen;
      case 'supplies':
        return BitmapDescriptor.hueRed;
      case 'volunteer':
        return BitmapDescriptor.hueBlue;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }

  void _fitMarkersInView() {
    if (_markers.isEmpty || mapController == null) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (var marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    // Add padding
    final latDiff = (maxLat - minLat) * 0.1;
    final lngDiff = (maxLng - minLng) * 0.1;

    mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - latDiff, minLng - lngDiff),
          northeast: LatLng(maxLat + latDiff, maxLng + lngDiff),
        ),
        100,
      ),
    );
  }

  void _showResourceDetails(CommunityResource resource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
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
                                  Text(
                                    resource.type.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getColorForType(resource.type),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    resource.categories.join(' • '),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                            'Tags',
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
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getColorForType(resource.type).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 20),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(resource.lat, resource.lng),
                                      16,
                                    ),
                                  );
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.my_location),
                                label: const Text('Show on Map'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  backgroundColor: _getColorForType(resource.type),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openDirections(resource.lat, resource.lng),
                                icon: const Icon(Icons.directions),
                                label: const Text('Directions'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  backgroundColor: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: onTap != null ? Colors.blue : Colors.black87,
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Show on Map',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            final allChecked = _categoryFilters.values.every((v) => v);
                            _categoryFilters.updateAll((key, value) => !allChecked);
                          });
                          setState(() {});
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          _categoryFilters.values.every((v) => v) ? 'Uncheck All' : 'Check All',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ..._categoryFilters.keys.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setModalState(() {
                              _categoryFilters[category] = !(_categoryFilters[category] ?? false);
                            });
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: (_categoryFilters[category] ?? false)
                                  ? _getColorForType(category).withOpacity(0.1)
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (_categoryFilters[category] ?? false)
                                    ? _getColorForType(category).withOpacity(0.3)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getColorForType(category).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getIconForType(category),
                                    color: _getColorForType(category),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    category[0].toUpperCase() + category.substring(1),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Checkbox(
                                  value: _categoryFilters[category],
                                  activeColor: _getColorForType(category),
                                  onChanged: (value) {
                                    setModalState(() {
                                      _categoryFilters[category] = value ?? false;
                                    });
                                    setState(() {});
                                  },
                                  materialTapTargetSize: MaterialTapTargetSize.padded,
                                  visualDensity: VisualDensity.comfortable,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
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
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Categories',
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('contributions')
                  .where('status', isEqualTo: 'active')
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
                List<CommunityResource> allResources = snapshot.data!.docs
                    .map((doc) => CommunityResource.fromFirestore(doc, _currentLocation))
                    .toList();

                // Filter out expired contributions
                allResources = allResources.where((r) => r.endDate.isAfter(DateTime.now())).toList();

                // Apply category filters - check if resource type or any of its tags match
                List<CommunityResource> filteredResources = allResources
                    .where((r) {
                      // Check if the resource type matches any enabled filter
                      if (_categoryFilters[r.type] == true) return true;
                      
                      // Check if any of the resource's tags match enabled filters
                      for (var tag in r.tags) {
                        if (_categoryFilters[tag.toLowerCase()] == true) return true;
                      }
                      
                      // Check if any of the resource's categories match enabled filters
                      for (var category in r.categories) {
                        if (_categoryFilters[category.toLowerCase()] == true) return true;
                      }
                      
                      return false;
                    })
                    .toList();

                // Update markers
                _updateMarkers(filteredResources);

                if (filteredResources.isEmpty) {
                  return Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation,
                          zoom: 12,
                        ),
                        markers: _markers,
                        onMapCreated: (controller) {
                          mapController = controller;
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                      Center(
                        child: Card(
                          margin: const EdgeInsets.all(20),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                const Text(
                                  'No resources to display',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Try adjusting your filters',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _showFilterSheet,
                                  icon: const Icon(Icons.filter_list),
                                  label: const Text('Adjust Filters'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentLocation,
                        zoom: 12,
                      ),
                      markers: _markers,
                      onMapCreated: (controller) {
                        mapController = controller;
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                    // Legend
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Legend',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ..._categoryFilters.entries
                                  .where((entry) => entry.value)
                                  .map((entry) => _buildLegendItem(
                                        entry.key[0].toUpperCase() + entry.key.substring(1),
                                        _getColorForType(entry.key),
                                      ))
                                  .toList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Resource count
                  // Resource count - clickable to show list
                  Positioned(
                    bottom: 20,
                    left: 10,
                    child: GestureDetector(
                      onTap: () => _showResourcesList(filteredResources),
                      child: Card(
                        color: Colors.purple,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${filteredResources.length} resource${filteredResources.length != 1 ? 's' : ''} found',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.list,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ],
                );
              },
            ),
    );
  }
  void _showResourcesList(List<CommunityResource> resources) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.volunteer_activism, color: Colors.purple, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Community Resources',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${resources.length} available',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                // List of resources
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: resources.length,
                    itemBuilder: (context, index) {
                      final resource = resources[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _getColorForType(resource.type).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context); // Close the list
                            _showResourceDetails(resource); // Show details
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _getColorForType(resource.type).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getIconForType(resource.type),
                                        color: _getColorForType(resource.type),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            resource.type.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _getColorForType(resource.type),
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            resource.categories.join(' • '),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  resource.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
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
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.directions_walk, size: 16, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDistance(resource.distance),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${resource.startTime} - ${resource.endTime}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getColorForType(resource.type).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _getColorForType(resource.type),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}