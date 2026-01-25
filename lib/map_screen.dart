import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class FoodBankPlace {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double distance;
  String? phoneNumber;
  String? openingHours;
  double? rating;
  int? userRatingsTotal;
  List<String>? photos;
  bool isOpen;
  bool isContribution;
  Map<String, dynamic>? contributionData;

  FoodBankPlace({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distance,
    this.phoneNumber,
    this.openingHours,
    this.rating,
    this.userRatingsTotal,
    this.photos,
    this.isOpen = true,
    this.isContribution = false,
    this.contributionData,
  });
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng _currentLocation = const LatLng(3.1390, 101.6869);
  final Set<Marker> _markers = {};
  final String googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  bool _isLoading = true;
  String _statusMessage = 'Loading...';
  bool _isMapView = true;
  List<FoodBankPlace> _foodBanks = [];
  Set<String> _favoriteIds = {};
  bool _showContributionsOnly = false;
  final FirestoreService _firestoreService = FirestoreService();

  final List<String> keywords = [
    'food bank',
    'food charity',
    'lost food project',
    'food aid',
    'charity food'
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _initializeMap();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteIds = (prefs.getStringList('favorites') ?? []).toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favoriteIds.toList());
  }

  Future<void> _toggleFavorite(String placeId) async {
    setState(() {
      if (_favoriteIds.contains(placeId)) {
        _favoriteIds.remove(placeId);
      } else {
        _favoriteIds.add(placeId);
      }
    });
    await _saveFavorites();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _currentLocation = const LatLng(3.1390, 101.6869);
        _statusMessage = 'Loading food banks and contributions...';
      });
      await _searchFoodBanks(_currentLocation.latitude, _currentLocation.longitude);
      await _loadCommunityContributions();
      _updateMarkersAndList();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
      print('Error initializing map: $e');
    }
  }

Future _loadCommunityContributions() async {
  try {
    // Load from Firestore FIRST
    final snapshot = await FirebaseFirestore.instance
        .collection('contributions')
        .where('status', isEqualTo: 'active')
        .get();
    
    for (var doc in snapshot.docs) {
      final contribution = doc.data();
      final endDate = DateTime.parse(contribution['endDate'] as String);
      
      // Only add if it's a Food or Both type (filter out Shelter-only)
      final type = (contribution['type'] ?? '').toString().toLowerCase();

      if (endDate.isAfter(DateTime.now()) &&
          (type == 'food' || type == 'community')) {
        double distance = _calculateDistance(
          _currentLocation.latitude,
          _currentLocation.longitude,
          contribution['lat'] as double,
          contribution['lng'] as double,
        );
        
        final contributionPlace = FoodBankPlace(
          placeId: 'contrib_${doc.id}',  // Use Firestore document ID
          name: '${contribution['type']} Contribution',
          address: contribution['location'] as String,
          lat: contribution['lat'] as double,
          lng: contribution['lng'] as double,
          distance: distance,
          isOpen: true,
          isContribution: true,
          contributionData: contribution,
        );
        _foodBanks.add(contributionPlace);
      }
    }
  } catch (e) {
    print('Error loading contributions from Firestore: $e');
    
    // FALLBACK to local storage if Firestore fails
    final prefs = await SharedPreferences.getInstance();
    final String? contributionsJson = prefs.getString('global_contributions');
    
    if (contributionsJson != null) {
      final List decoded = json.decode(contributionsJson);
      final contributions = decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      
      for (var contribution in contributions) {
        if (contribution['status'] == 'active') {
          final endDate = DateTime.parse(contribution['endDate'] as String);
          
          // Only add if it's a Food or Both type (filter out Shelter-only)
          final type = (contribution['type'] ?? '').toString().toLowerCase();

          if (endDate.isAfter(DateTime.now()) &&
              (type == 'food' || type == 'community')) {
            double distance = _calculateDistance(
              _currentLocation.latitude,
              _currentLocation.longitude,
              contribution['lat'] as double,
              contribution['lng'] as double,
            );
            
            final contributionPlace = FoodBankPlace(
              placeId: 'contrib_${contribution['id']}',
              name: '${contribution['type']} Contribution',
              address: contribution['location'] as String,
              lat: contribution['lat'] as double,
              lng: contribution['lng'] as double,
              distance: distance,
              isOpen: true,
              isContribution: true,
              contributionData: contribution,
            );
            _foodBanks.add(contributionPlace);
          }
        }
      }
    }
  }
}

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m away';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km away';
    }
  }

  Future<void> _fetchPlaceDetails(FoodBankPlace place) async {
    if (place.isContribution) return; // Skip API call for contributions

    final url =
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${place.placeId}'
        '&fields=formatted_phone_number,opening_hours,rating,user_ratings_total,photos'
        '&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] != null) {
          final result = data['result'];
          
          place.phoneNumber = result['formatted_phone_number'];
          place.rating = result['rating']?.toDouble();
          place.userRatingsTotal = result['user_ratings_total'];
          
          if (result['opening_hours'] != null) {
            place.isOpen = result['opening_hours']['open_now'] ?? true;
            if (result['opening_hours']['weekday_text'] != null) {
              place.openingHours = (result['opening_hours']['weekday_text'] as List)
                  .join('\n');
            }
          }

          if (result['photos'] != null && (result['photos'] as List).isNotEmpty) {
            place.photos = (result['photos'] as List).take(3).map((photo) {
              final photoReference = photo['photo_reference'];
              return 'https://maps.googleapis.com/maps/api/place/photo'
                  '?maxwidth=400&photo_reference=$photoReference&key=$googleApiKey';
            }).toList();
          }
        }
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }
  }

  Future<void> _searchFoodBanks(double lat, double lng) async {
    List<Map<String, dynamic>> allPlaces = [];
    List<String> keywordsLower = keywords.map((k) => k.toLowerCase()).toList();

    for (String keyword in keywords) {
      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng'
          '&radius=10000'
          '&type=establishment'
          '&keyword=${keyword.replaceAll(' ', '+')}'
          '&key=$googleApiKey';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data['status'] == 'REQUEST_DENIED') {
            setState(() {
              _statusMessage = 'API Error: ${data['error_message']}';
              _isLoading = false;
            });
            return;
          }

          final results = data['results'] ?? [];

          for (var place in results) {
            String name = (place['name'] ?? '').toString().toLowerCase();
            bool containsKeyword = keywordsLower.any((k) => name.contains(k));

            if (containsKeyword) {
              bool alreadyExists = allPlaces.any((p) => p['place_id'] == place['place_id']);
              if (!alreadyExists) {
                allPlaces.add(place);
              }
            }
          }
        }
      } catch (e) {
        print('Error searching with keyword $keyword: $e');
      }
    }

    for (var place in allPlaces) {
      double placeLat = place['geometry']['location']['lat'];
      double placeLng = place['geometry']['location']['lng'];
      double distance = _calculateDistance(lat, lng, placeLat, placeLng);

      final foodBank = FoodBankPlace(
        placeId: place['place_id'],
        name: place['name'],
        address: place['vicinity'] ?? '',
        lat: placeLat,
        lng: placeLng,
        distance: distance,
        isOpen: place['opening_hours']?['open_now'] ?? true,
        isContribution: false,
      );

      _foodBanks.add(foodBank);
    }
  }

  void _updateMarkersAndList() {
    _markers.clear();
    
    final displayList = _showContributionsOnly 
        ? _foodBanks.where((f) => f.isContribution).toList()
        : _foodBanks;
    
    for (var place in displayList) {
      final marker = Marker(
        markerId: MarkerId(place.placeId),
        position: LatLng(place.lat, place.lng),
        infoWindow: InfoWindow(
          title: place.name,
          snippet: _formatDistance(place.distance),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          place.isContribution 
              ? BitmapDescriptor.hueViolet
              : _favoriteIds.contains(place.placeId) 
                  ? BitmapDescriptor.hueRed 
                  : BitmapDescriptor.hueOrange,
        ),
        onTap: () => _showPlaceDetailsDialog(place),
      );
      
      _markers.add(marker);
    }

    _foodBanks.sort((a, b) => a.distance.compareTo(b.distance));

    setState(() {
      _isLoading = false;
      final contributionCount = _foodBanks.where((f) => f.isContribution).length;
      final foodBankCount = _foodBanks.length - contributionCount;
      _statusMessage = 'Found $foodBankCount food bank(s) and $contributionCount contribution(s)';
    });

    if (_markers.isNotEmpty && mapController != null && _isMapView) {
      _fitMarkersInView();
    }
  }

  void _showPlaceDetailsDialog(FoodBankPlace place) async {
    if (place.isContribution) {
      _showContributionDetailsDialog(place);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await _fetchPlaceDetails(place);
    
    if (mounted) Navigator.pop(context);

    if (mounted) {
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _favoriteIds.contains(place.placeId)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                            size: 30,
                          ),
                          onPressed: () {
                            _toggleFavorite(place.placeId);
                            setState(() {});
                            Navigator.pop(context);
                            _showPlaceDetailsDialog(place);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: place.isOpen ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            place.isOpen ? 'Open Now' : 'Closed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (place.rating != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${place.rating} (${place.userRatingsTotal ?? 0})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 15),

                    if (place.photos != null && place.photos!.isNotEmpty) ...[
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: place.photos!.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  place.photos![index],
                                  width: 200,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 200,
                                      height: 150,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.error),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],

                    _buildInfoRow(Icons.location_on, 'Address', place.address),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.directions_walk, 'Distance', _formatDistance(place.distance)),
                    const SizedBox(height: 10),

                    if (place.phoneNumber != null) ...[
                      _buildInfoRow(
                        Icons.phone,
                        'Phone',
                        place.phoneNumber!,
                        onTap: () => _launchPhone(place.phoneNumber!),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (place.openingHours != null) ...[
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(Icons.access_time, color: Colors.grey),
                          SizedBox(width: 10),
                          Text(
                            'Opening Hours',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        place.openingHours!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 15),
                    ],

                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_isMapView) {
                                mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(place.lat, place.lng),
                                    16,
                                  ),
                                );
                                Navigator.pop(context);
                              } else {
                                setState(() {
                                  _isMapView = true;
                                });
                                Navigator.pop(context);
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(place.lat, place.lng),
                                      16,
                                    ),
                                  );
                                });
                              }
                            },
                            icon: const Icon(Icons.map),
                            label: const Text('Show on Map'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _openDirections(place.lat, place.lng),
                            icon: const Icon(Icons.directions),
                            label: const Text('Directions'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(15),
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  void _showContributionDetailsDialog(FoodBankPlace place) {
    final contribution = place.contributionData!;
    final startDate = DateTime.parse(contribution['startDate']);
    final endDate = DateTime.parse(contribution['endDate']);

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          contribution['type'] == 'Food' 
                              ? Icons.restaurant 
                              : Icons.home,
                          color: Colors.purple[700],
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
                              contribution['type'],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contribution['description'],
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildInfoRow(
                    Icons.numbers,
                    'Quantity',
                    '${contribution['quantity']} ${contribution['type'] == 'Food' ? 'meals/packages' : 'people'}',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.location_on,
                    'Location',
                    contribution['location'],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.directions_walk,
                    'Distance',
                    _formatDistance(place.distance),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Available',
                    '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.access_time,
                    'Hours',
                    '${contribution['startTime']} - ${contribution['endTime']}',
                  ),

                  if (contribution['contact'] != null && 
                      contribution['contact'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.phone,
                      'Contact',
                      contribution['contact'],
                      onTap: () => _launchPhone(contribution['contact']),
                    ),
                  ],

                  if ((contribution['tags'] as List).isNotEmpty) ...[
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
                      children: (contribution['tags'] as List).map((tag) {
                        return Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.purple[50],
                          padding: const EdgeInsets.all(4),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_isMapView) {
                              mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(place.lat, place.lng),
                                  16,
                                ),
                              );
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                _isMapView = true;
                              });
                              Navigator.pop(context);
                              Future.delayed(const Duration(milliseconds: 500), () {
                                mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(place.lat, place.lng),
                                    16,
                                  ),
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('Show on Map'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openDirections(place.lat, place.lng),
                          icon: const Icon(Icons.directions),
                          label: const Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(15),
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                    ],
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

  void _fitMarkersInView() {
    if (_markers.isEmpty) return;

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

    mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  Widget _buildListView() {
    final displayList = _showContributionsOnly 
        ? _foodBanks.where((f) => f.isContribution).toList()
        : _foodBanks;

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _showContributionsOnly 
                  ? 'No community contributions yet' 
                  : _statusMessage,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: displayList.length,
      padding: const EdgeInsets.all(10),
      itemBuilder: (context, index) {
        final place = displayList[index];
        final isFavorite = _favoriteIds.contains(place.placeId);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 3,
          child: ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: place.isContribution 
                  ? Colors.purple 
                  : place.isOpen ? Colors.green : Colors.grey,
              child: Icon(
                place.isContribution 
                    ? Icons.volunteer_activism
                    : isFavorite ? Icons.favorite : Icons.restaurant,
                color: Colors.white,
              ),
            ),
            title: Text(
              place.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 5),
                Text(place.address),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_walk,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDistance(place.distance),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: place.isContribution 
                            ? Colors.purple 
                            : place.isOpen ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        place.isContribution 
                            ? 'Contribution' 
                            : place.isOpen ? 'Open' : 'Closed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: place.isContribution 
                ? const Icon(Icons.volunteer_activism, color: Colors.purple)
                : IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      _toggleFavorite(place.placeId);
                    },
                  ),
            onTap: () => _showPlaceDetailsDialog(place),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMapView ? "Map View" : "List View"),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list : Icons.map),
            tooltip: _isMapView ? 'List View' : 'Map View',
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) {
              setState(() {
                if (value == 'contributions') {
                  _showContributionsOnly = !_showContributionsOnly;
                  _updateMarkersAndList();
                } else if (value == 'favorites') {
                  if (_foodBanks.any((p) => !_favoriteIds.contains(p.placeId))) {
                    _foodBanks = _foodBanks
                        .where((p) => _favoriteIds.contains(p.placeId))
                        .toList();
                    _updateMarkersAndList();
                  } else {
                    _markers.clear();
                    _foodBanks.clear();
                    _isLoading = true;
                    _initializeMap();
                  }
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'contributions',
                child: Row(
                  children: [
                    Icon(
                      _showContributionsOnly 
                          ? Icons.check_box 
                          : Icons.check_box_outline_blank,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    const Text('Show Contributions Only'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'favorites',
                child: Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Filter Favorites'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _markers.clear();
                _foodBanks.clear();
                _isLoading = true;
                _statusMessage = 'Refreshing...';
                _showContributionsOnly = false;
              });
              _initializeMap();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _isMapView
              ? GoogleMap(
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
                )
              : _buildListView(),

          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          if (!_isLoading && _isMapView) ...[
            if (_markers.isEmpty)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Card(
                  color: Colors.green[700],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Legend
            Positioned(
              bottom: 20,
              left: 10,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Legend:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.location_on, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Food Banks', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.location_on, color: Colors.purple, size: 20),
                          SizedBox(width: 8),
                          Text('Contributions', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.location_on, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Favorites', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}