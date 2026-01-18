// ============================================================================
// MaaS Platform - Geocoding Remote Data Source
// API communication for geocoding endpoints (Photon/OSM integration)
// ============================================================================

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';

// ============================================================================
// Geocoding Result Model
// ============================================================================

enum GeocodingResultType {
  address,
  street,
  poi,
  transit,
  city,
  district,
  unknown,
}

class GeocodingResult {
  final String id;
  final String name;
  final String displayName;
  final GeocodingResultType type;
  final LatLng location;
  final String? street;
  final String? houseNumber;
  final String? city;
  final String? district;
  final String? postalCode;
  final double? distance;

  const GeocodingResult({
    required this.id,
    required this.name,
    required this.displayName,
    required this.type,
    required this.location,
    this.street,
    this.houseNumber,
    this.city,
    this.district,
    this.postalCode,
    this.distance,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    // Handle nested location object from API
    final locationData = json['location'];
    double lat = 0.0;
    double lng = 0.0;
    
    if (locationData is Map<String, dynamic>) {
      lat = (locationData['lat'] ?? 0).toDouble();
      lng = (locationData['lng'] ?? locationData['lon'] ?? 0).toDouble();
    } else {
      // Fallback to flat structure
      lat = (json['lat'] ?? 0).toDouble();
      lng = (json['lon'] ?? json['lng'] ?? 0).toDouble();
    }
    
    // Handle nested details object from API
    final details = json['details'] as Map<String, dynamic>?;
    
    return GeocodingResult(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      displayName: json['label'] ?? json['displayName'] ?? json['name'] ?? '',
      type: _parseType(json['type']),
      location: LatLng(lat, lng),
      street: details?['street'] ?? json['street'],
      houseNumber: details?['houseNumber'] ?? json['houseNumber'],
      city: details?['city'] ?? json['city'],
      district: details?['district'] ?? json['district'],
      postalCode: details?['postcode'] ?? json['postalCode'],
      distance: json['distance']?.toDouble(),
    );
  }

  static GeocodingResultType _parseType(String? type) {
    switch (type) {
      case 'address':
        return GeocodingResultType.address;
      case 'street':
        return GeocodingResultType.street;
      case 'poi':
        return GeocodingResultType.poi;
      case 'transit':
        return GeocodingResultType.transit;
      case 'city':
        return GeocodingResultType.city;
      case 'district':
        return GeocodingResultType.district;
      default:
        return GeocodingResultType.unknown;
    }
  }

  /// Get a short address description
  String get shortAddress {
    final parts = <String>[];
    if (street != null) {
      parts.add(street!);
      if (houseNumber != null) {
        parts[parts.length - 1] += ' $houseNumber';
      }
    }
    if (district != null) {
      parts.add(district!);
    } else if (city != null) {
      parts.add(city!);
    }
    return parts.isNotEmpty ? parts.join(', ') : displayName;
  }
}

// ============================================================================
// Abstract Data Source
// ============================================================================

abstract class GeocodingRemoteDataSource {
  /// Search for places by query text with optional location bias
  Future<List<GeocodingResult>> search(
    String query, {
    LatLng? near,
    int limit,
  });

  /// Autocomplete search with debouncing (for real-time suggestions)
  Future<List<GeocodingResult>> autocomplete(
    String query, {
    LatLng? near,
    int limit,
  });

  /// Reverse geocode coordinates to address
  Future<GeocodingResult?> reverse(LatLng location);

  /// Search for transit stops only
  Future<List<GeocodingResult>> searchStops(
    String query, {
    LatLng? near,
    int limit,
  });
}

// ============================================================================
// Implementation
// ============================================================================

@LazySingleton(as: GeocodingRemoteDataSource)
class GeocodingRemoteDataSourceImpl implements GeocodingRemoteDataSource {
  final Dio _dio;
  
  // Debounce timer for autocomplete
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 300);

  GeocodingRemoteDataSourceImpl(this._dio);

  @override
  Future<List<GeocodingResult>> search(
    String query, {
    LatLng? near,
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      print('[Geocoding] 🔍 Searching: "$query"');
      
      final queryParams = <String, dynamic>{
        'q': query,
        'limit': limit,
      };
      
      if (near != null) {
        queryParams['lat'] = near.latitude;
        queryParams['lon'] = near.longitude;
      }

      final response = await _dio.get('/geocode', queryParameters: queryParams);

      if (response.statusCode == 200) {
        // API returns {success: true, data: {results: [...], count: N}}
        List<dynamic> results = [];
        final responseData = response.data;
        
        if (responseData is Map<String, dynamic>) {
          if (responseData['data'] is Map<String, dynamic>) {
            results = (responseData['data']['results'] as List<dynamic>?) ?? [];
          } else if (responseData['results'] is List) {
            results = responseData['results'] as List<dynamic>;
          }
        } else if (responseData is List) {
          results = responseData;
        }
        
        print('[Geocoding] ✅ Found ${results.length} results');
        return results.map((json) => GeocodingResult.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (error) {
      print('[Geocoding] ❌ Search error: $error');
      return [];
    }
  }

  @override
  Future<List<GeocodingResult>> autocomplete(
    String query, {
    LatLng? near,
    int limit = 5,
  }) async {
    if (query.trim().length < 2) return [];

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Create completer to handle debounced result
    final completer = Completer<List<GeocodingResult>>();
    
    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        print('[Geocoding] 🔤 Autocomplete: "$query"');
        
        final queryParams = <String, dynamic>{
          'q': query,
          'limit': limit,
        };
        
        if (near != null) {
          queryParams['lat'] = near.latitude;
          queryParams['lon'] = near.longitude;
        }

        final response = await _dio.get(
          '/geocode/autocomplete',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200) {
          // API returns {success: true, data: {results: [...], count: N}}
          List<dynamic> results = [];
          final responseData = response.data;
          
          if (responseData is Map<String, dynamic>) {
            // New API format: {success, data: {results}}
            if (responseData['data'] is Map<String, dynamic>) {
              results = (responseData['data']['results'] as List<dynamic>?) ?? [];
            } else if (responseData['results'] is List) {
              // Alternative format: {results}
              results = responseData['results'] as List<dynamic>;
            }
          } else if (responseData is List) {
            // Direct list format
            results = responseData;
          }
          
          print('[Geocoding] ✅ Autocomplete found ${results.length} results');
          completer.complete(
            results.map((json) => GeocodingResult.fromJson(json as Map<String, dynamic>)).toList(),
          );
        } else {
          completer.complete([]);
        }
      } catch (error) {
        print('[Geocoding] ❌ Autocomplete error: $error');
        completer.complete([]);
      }
    });

    return completer.future;
  }

  @override
  Future<GeocodingResult?> reverse(LatLng location) async {
    try {
      print('[Geocoding] 📍 Reverse geocode: ${location.latitude}, ${location.longitude}');
      
      final response = await _dio.get(
        '/geocode/reverse',
        queryParameters: {
          'lat': location.latitude,
          'lon': location.longitude,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        print('[Geocoding] ✅ Reverse geocode result: ${response.data['name']}');
        return GeocodingResult.fromJson(response.data);
      }
      return null;
    } catch (error) {
      print('[Geocoding] ❌ Reverse geocode error: $error');
      return null;
    }
  }

  @override
  Future<List<GeocodingResult>> searchStops(
    String query, {
    LatLng? near,
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      print('[Geocoding] 🚏 Searching stops: "$query"');
      
      final queryParams = <String, dynamic>{
        'q': query,
        'limit': limit,
      };
      
      if (near != null) {
        queryParams['lat'] = near.latitude;
        queryParams['lon'] = near.longitude;
      }

      final response = await _dio.get(
        '/geocode/stops',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        print('[Geocoding] ✅ Found ${data.length} stops');
        return data.map((json) => GeocodingResult.fromJson(json)).toList();
      }
      return [];
    } catch (error) {
      print('[Geocoding] ❌ Stop search error: $error');
      return [];
    }
  }
}
