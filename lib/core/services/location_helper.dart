// lib/core/services/location_helper.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:io';

// Add a geocoding API key if using Google/other paid services
// const String _apiKey = 'YOUR_API_KEY';

class LocationHelper {
  // Singleton implementation
  static final LocationHelper _instance = LocationHelper._internal();
  factory LocationHelper() => _instance;
  LocationHelper._internal();

  // Get address from coordinates (reverse geocoding)
  // Uses OpenStreetMap's Nominatim API (free, but rate limited)
  Future<String> getAddressFromLatLng(LatLng location) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1',
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ReMind App', // Required by Nominatim's usage policy
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Geocoding request timed out');
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['display_name'] != null) {
          return data['display_name'];
        } else {
          return 'Unknown location';
        }
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        return 'Service temporarily unavailable (rate limit)';
      } else {
        return 'Error fetching address: Status ${response.statusCode}';
      }
    } on TimeoutException {
      return 'Request timed out';
    } on SocketException {
      return 'Network connection issue';
    } catch (e) {
      return 'Error: $e';
    }
  }
  
  // Get coordinates from address (forward geocoding)
  Future<LatLng?> getLatLngFromAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedAddress&limit=1',
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ReMind App', // Required by Nominatim's usage policy
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  
  // Search for locations by name
  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=5',
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'ReMind App', // Required by Nominatim's usage policy
        },
      );
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        
        return data.map((item) {
          return {
            'name': item['display_name'],
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
          };
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
  
  // Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }
  
  // Check if location services are enabled
  Future<bool> checkLocationServices() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  // Request location permissions
  Future<LocationPermission> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }
}