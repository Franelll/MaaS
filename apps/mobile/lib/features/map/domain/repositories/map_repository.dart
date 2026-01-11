// ============================================================================
// MaaS Platform - Map Repository Interface
// Domain layer contract for map operations
// ============================================================================

import '../entities/map_entities.dart';

abstract class MapRepository {
  /// Get vehicles near a location
  Future<List<Vehicle>> getNearbyVehicles(
    double lat,
    double lng,
    double radiusMeters,
  );

  /// Get vehicles within bounding box (preferred for viewport culling)
  Future<List<Vehicle>> getVehiclesInBounds(
    double north,
    double south,
    double east,
    double west,
  );

  /// Get transit stops near a location
  Future<List<TransitStop>> getNearbyStops(
    double lat,
    double lng,
    double radiusMeters,
  );

  /// Get vehicle details by ID
  Future<Vehicle?> getVehicleById(String id);

  /// Get deep link for vehicle unlock
  Future<String?> getVehicleDeeplink(String vehicleId);
}
