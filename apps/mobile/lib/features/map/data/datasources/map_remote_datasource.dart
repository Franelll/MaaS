// ============================================================================
// MaaS Platform - Map Remote Data Source
// API communication for map endpoints
// ============================================================================

import 'package:dio/dio.dart';

import '../../domain/entities/map_entities.dart';

abstract class MapRemoteDataSource {
  Future<List<Vehicle>> getNearbyVehicles(
    double lat,
    double lng,
    double radiusMeters,
  );
  Future<List<Vehicle>> getVehiclesInBounds(
    double north,
    double south,
    double east,
    double west,
  );
  Future<List<TransitStop>> getNearbyStops(
    double lat,
    double lng,
    double radiusMeters,
  );
  Future<String?> getVehicleDeeplink(String vehicleId);
}

class MapRemoteDataSourceImpl implements MapRemoteDataSource {
  final Dio _dio;

  MapRemoteDataSourceImpl(this._dio);

  @override
  Future<List<Vehicle>> getNearbyVehicles(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    // Convert radius to approximate bounding box
    final delta = radiusMeters / 111000; // rough conversion to degrees
    return getVehiclesInBounds(
      lat + delta,
      lat - delta,
      lng + delta,
      lng - delta,
    );
  }

  @override
  Future<List<Vehicle>> getVehiclesInBounds(
    double north,
    double south,
    double east,
    double west,
  ) async {
    try {
      print('[MapDataSource] 🌐 Fetching vehicles: N=$north, S=$south, E=$east, W=$west');
      
      final response = await _dio.get(
        '/map/entities',
        queryParameters: {
          'north': north,
          'south': south,
          'east': east,
          'west': west,
        },
      );

      print('[MapDataSource] 📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List 
            ? response.data 
            : (response.data['entities'] ?? response.data['vehicles'] ?? []);
        print('[MapDataSource] ✅ Received ${data.length} vehicles from API');
        final vehicles = data.map((v) => _parseVehicle(v)).toList();
        print('[MapDataSource] 🚗 Parsed vehicle types: ${vehicles.map((v) => v.type).toSet()}');
        return vehicles;
      }
      return [];
    } catch (error) {
      print('[MapDataSource] ❌ Error fetching vehicles: $error');
      return [];
    }
  }

  @override
  Future<List<TransitStop>> getNearbyStops(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    try {
      final response = await _dio.get(
        '/map/nearby/transit',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': radiusMeters.toInt(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['stops'] ?? [];
        return data.map((s) => _parseStop(s)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String?> getVehicleDeeplink(String vehicleId) async {
    try {
      final response = await _dio.get('/map/deeplink/$vehicleId');
      if (response.statusCode == 200) {
        return response.data['deeplink'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Vehicle _parseVehicle(Map<String, dynamic> json) {
    // Handle ZTM API format
    final location = json['location'] as Map<String, dynamic>?;
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final provider = json['provider'] as Map<String, dynamic>?;
    
    final double lat = location != null 
        ? (location['lat'] as num).toDouble()
        : (json['lat'] as num).toDouble();
    final double lng = location != null 
        ? (location['lng'] as num).toDouble()
        : (json['lng'] as num).toDouble();
    
    final String vehicleType = json['type'] as String? ?? json['vehicleType'] as String? ?? 'scooter';
    final String providerName = provider != null 
        ? (provider['name'] as String? ?? 'Unknown')
        : (json['provider'] as String? ?? 'Unknown');
    
    return Vehicle(
      id: json['id'] as String,
      type: VehicleType.fromString(vehicleType),
      provider: providerName,
      lat: lat,
      lng: lng,
      batteryLevel: json['batteryLevel'] as int? ?? 100,
      range: (json['range'] as num?)?.toDouble(),
      isAvailable: json['isAvailable'] as bool? ?? true,
      routeShortName: metadata?['routeShortName'] as String?,
      headsign: metadata?['headsign'] as String?,
      pricing: json['pricing'] != null
          ? VehiclePricing(
              unlockFee: (json['pricing']['unlockFee'] as num?)?.toDouble() ?? 0,
              perMinute: (json['pricing']['perMinute'] as num?)?.toDouble() ?? 0,
              currency: json['pricing']['currency'] as String? ?? 'PLN',
            )
          : null,
    );
  }

  TransitStop _parseStop(Map<String, dynamic> json) {
    return TransitStop(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      type: json['type'] as String? ?? 'bus',
      lines: (json['lines'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}
