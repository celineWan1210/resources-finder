import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math'; // ✨ Import dart:math for trigonometric functions
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationCacheService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final String _googleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  /// Fetch locations from Firestore cache (FAST) - AUTO-POPULATES if empty
  static Future<List<Map<String, dynamic>>> getCachedLocations({
    required String type, // 'foodbank' or 'shelter'
    required double userLat,
    required double userLng,
    double radiusKm = 10.0,
  }) async {
    try {
      // Try to fetch from cache first
      List<Map<String, dynamic>> locations = await _fetchFromCache(
        type: type,
        userLat: userLat,
        userLng: userLng,
        radiusKm: radiusKm,
      );

      // ✨ AUTO-CACHE: If cache is empty, populate it first
      if (locations.isEmpty) {
        print('⚠️ Cache empty for $type. Fetching from Google Places API...');
        
        await updateLocationCache(
          type: type,
          lat: userLat,
          lng: userLng,
          radiusKm: 50.0, // Larger radius for caching
        );

        // Fetch again from newly populated cache
        locations = await _fetchFromCache(
          type: type,
          userLat: userLat,
          userLng: userLng,
          radiusKm: radiusKm,
        );
      }

      return locations;
    } catch (e) {
      print('❌ Error in getCachedLocations: $e');
      return [];
    }
  }

  /// Internal method: Fetch from Firestore cache only
  static Future<List<Map<String, dynamic>>> _fetchFromCache({
    required String type,
    required double userLat,
    required double userLng,
    double radiusKm = 10.0,
  }) async {
    try {
      // Query cached locations by type
      final snapshot = await _firestore
          .collection('cached_locations')
          .where('type', isEqualTo: type)
          .where('verified', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> locations = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'] as double;
        final lng = data['lng'] as double;

        // Calculate distance
        final distance = _calculateDistance(userLat, userLng, lat, lng);

        // Only include if within radius
        if (distance <= radiusKm) {
          locations.add({
            'id': doc.id,
            'placeId': data['placeId'],
            'name': data['name'],
            'address': data['address'],
            'lat': lat,
            'lng': lng,
            'distance': distance,
            'phoneNumber': data['phoneNumber'],
            'rating': data['rating'],
            'userRatingsTotal': data['userRatingsTotal'],
            'isOpen': data['isOpen'] ?? true,
            'lastUpdated': data['lastUpdated'],
          });
        }
      }

      // Sort by distance
      locations.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      if (locations.isNotEmpty) {
        print('✅ Loaded ${locations.length} cached $type locations within ${radiusKm}km');
      }
      
      return locations;
    } catch (e) {
      print('❌ Error fetching from cache: $e');
      return [];
    }
  }

  /// Background job: Populate/update Firestore cache from Google Places API
  /// This should be run periodically (e.g., daily) via Cloud Functions or admin panel
  static Future<void> updateLocationCache({
    required String type,
    required double lat,
    required double lng,
    double radiusKm = 50.0, // Larger radius for caching
  }) async {
    final keywords = type == 'foodbank'
    ? ['food bank', 'food charity', 'lost food project', 'food aid', 'charity food',
      'food pantry', 'meal program', 
      'food assistance', 'hunger relief', 'food rescue', 'community kitchen',
      'bank makanan', 'bantuan makanan', 'makanan amal', 'projek makanan',
      'dapur makanan', 'agihan makanan', 'bantuan kelaparan', 'makanan percuma',
      'pusat makanan', 'derma makanan', 'rumah makan amal']
     : ['homeless shelter', 'shelter', 'emergency housing', 'transit home', 
        'rumah perlindungan', 'refuge center', 'transitional housing', 
        'living center', 'living centre', 'gelandangan', 
        'anjung singgah', 'house of hope',
        'social services organization'];

    List<Map<String, dynamic>> allPlaces = [];
    Set<String> seenPlaceIds = {};

    for (String keyword in keywords) {
      final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng'
          '&radius=${radiusKm * 1000}'
          '&type=establishment'
          '&keyword=${keyword.replaceAll(' ', '+')}'
          '&key=$_googleApiKey';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] ?? [];

          for (var place in results) {
            final placeId = place['place_id'];
            
            // Skip duplicates
            if (seenPlaceIds.contains(placeId)) continue;
            seenPlaceIds.add(placeId);

            final name = (place['name'] ?? '').toString().toLowerCase();
            
            // Verify keyword match
            bool containsKeyword = keywords.any((k) => name.contains(k.toLowerCase()));
            if (!containsKeyword) {
              print('⚠️ Skipping: $name (keyword not found)');
              continue;
            }

            allPlaces.add({
              'placeId': placeId,
              'name': place['name'],
              'address': place['vicinity'] ?? '',
              'lat': place['geometry']['location']['lat'],
              'lng': place['geometry']['location']['lng'],
              'rating': place['rating'],
              'userRatingsTotal': place['user_ratings_total'],
              'isOpen': place['opening_hours']?['open_now'] ?? true,
            });
          }
        }
      } catch (e) {
        print('❌ Error fetching keyword "$keyword": $e');
      }
    }

    // Save to Firestore
    int savedCount = 0;
    for (var place in allPlaces) {
      try {
        await _firestore
            .collection('cached_locations')
            .doc(place['placeId'])
            .set({
          ...place,
          'type': type,
          'verified': true,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        savedCount++;
      } catch (e) {
        print('❌ Error saving ${place['name']}: $e');
      }
    }

    print('✅ Cached $savedCount $type locations to Firestore');
  }

  /// Fetch detailed place info and update cache
  static Future<void> updatePlaceDetails(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=formatted_phone_number,opening_hours,photos'
        '&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];

        if (result != null) {
          await _firestore
              .collection('cached_locations')
              .doc(placeId)
              .update({
            'phoneNumber': result['formatted_phone_number'],
            'openingHours': result['opening_hours']?['weekday_text'],
            'isOpen': result['opening_hours']?['open_now'] ?? true,
            'photos': (result['photos'] as List?)?.map((p) => p['photo_reference']).toList(),
            'detailsLastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('❌ Error updating details for $placeId: $e');
    }
  }

  /// Calculate distance in km using Haversine formula
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * 
         sin(dLng / 2) * sin(dLng / 2));
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * (pi / 180);
}