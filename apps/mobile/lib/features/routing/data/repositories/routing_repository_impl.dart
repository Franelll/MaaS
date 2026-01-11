// ============================================================================
// MaaS Platform - Routing Repository Implementation
// Data layer implementation of routing repository
// ============================================================================

import '../../domain/entities/route_entities.dart';
import '../../domain/repositories/routing_repository.dart';
import '../datasources/routing_remote_datasource.dart';
import '../models/route_models.dart';

class RoutingRepositoryImpl implements RoutingRepository {
  final RoutingRemoteDataSource _remoteDataSource;

  RoutingRepositoryImpl(this._remoteDataSource);

  @override
  Future<TripPlanResponse> planTrip(TripPlanRequest request) async {
    final requestModel = TripPlanRequestModel.fromEntity(request);
    final response = await _remoteDataSource.planTrip(requestModel);
    return response.toEntity();
  }

  @override
  Future<List<TransportMode>> getAvailableModes() async {
    // Could fetch from /routing/modes endpoint
    // For now, return static list
    return const [
      TransportMode(
        id: 'walk',
        name: 'Walking',
        icon: '🚶',
        available: true,
      ),
      TransportMode(
        id: 'transit',
        name: 'Public Transit',
        icon: '🚌',
        available: true,
        providers: ['ztm-warsaw'],
      ),
      TransportMode(
        id: 'scooter',
        name: 'E-Scooter',
        icon: '🛴',
        available: true,
        providers: ['bolt', 'lime', 'tier'],
      ),
      TransportMode(
        id: 'bike',
        name: 'Bike',
        icon: '🚲',
        available: true,
        providers: ['veturilo', 'nextbike'],
      ),
    ];
  }

  @override
  Future<bool> checkHealth() async {
    return _remoteDataSource.checkHealth();
  }
}
