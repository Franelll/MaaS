// ============================================================================
// MaaS Platform - Map Repository Implementation
// Data layer implementation of map repository
// ============================================================================

import '../../domain/entities/map_entities.dart';
import '../../domain/repositories/map_repository.dart';
import '../datasources/map_remote_datasource.dart';

class MapRepositoryImpl implements MapRepository {
  final MapRemoteDataSource _remoteDataSource;

  MapRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Vehicle>> getNearbyVehicles(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    return _remoteDataSource.getNearbyVehicles(lat, lng, radiusMeters);
  }

  @override
  Future<List<Vehicle>> getVehiclesInBounds(
    double north,
    double south,
    double east,
    double west,
  ) async {
    return _remoteDataSource.getVehiclesInBounds(north, south, east, west);
  }

  @override
  Future<List<TransitStop>> getNearbyStops(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    return _remoteDataSource.getNearbyStops(lat, lng, radiusMeters);
  }

  @override
  Future<Vehicle?> getVehicleById(String id) async {
    // Would need dedicated endpoint - for now search nearby
    return null;
  }

  @override
  Future<String?> getVehicleDeeplink(String vehicleId) async {
    return _remoteDataSource.getVehicleDeeplink(vehicleId);
  }
}
