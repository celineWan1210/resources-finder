import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Default location (Kuala Lumpur)
  static const LatLng defaultLocation = LatLng(3.1390, 101.6869);
  static const String defaultLocationName = 'Kuala Lumpur, Malaysia';

  /// Gets the user's current location with proper permission handling
  /// Returns the location if successful, or default KL location if permission denied/error
  static Future<LocationResult> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          location: defaultLocation,
          locationName: defaultLocationName,
          message: 'Location services disabled. Using Kuala Lumpur.',
          isDefault: true,
        );
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            location: defaultLocation,
            locationName: defaultLocationName,
            message: 'Location permission denied. Using Kuala Lumpur.',
            isDefault: true,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          location: defaultLocation,
          locationName: defaultLocationName,
          message: 'Location permission permanently denied. Using Kuala Lumpur.',
          isDefault: true,
        );
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );

      // Get address from coordinates using reverse geocoding
      String locationName = defaultLocationName;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          // Build a readable address
          List<String> addressParts = [];
          
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            addressParts.add(place.country!);
          }
          
          locationName = addressParts.isNotEmpty 
              ? addressParts.join(', ') 
              : defaultLocationName;
        }
      } catch (e) {
        print('Error getting address from coordinates: $e');
        // If geocoding fails, just use coordinates as location name
        locationName = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      return LocationResult(
        location: LatLng(position.latitude, position.longitude),
        locationName: locationName,
        message: 'Location retrieved successfully',
        isDefault: false,
      );
    } catch (e) {
      print('Error getting location: $e');
      return LocationResult(
        location: defaultLocation,
        locationName: defaultLocationName,
        message: 'Could not get location. Using Kuala Lumpur.',
        isDefault: true,
      );
    }
  }

  /// Checks if location permission is granted (without requesting)
  static Future<bool> hasLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Requests location permission (if not already granted)
  static Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Calculate distance between two points in kilometers
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m away';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km away';
    }
  }
}

/// Result object returned by getCurrentLocation
class LocationResult {
  final LatLng location;
  final String? locationName;
  final String message;
  final bool isDefault;

  LocationResult({
    required this.location,
    this.locationName,
    required this.message,
    required this.isDefault,
  });

  double get latitude => location.latitude;
  double get longitude => location.longitude;
}