// ============================================================================
// MaaS Platform - Routing Repository Interface
// Domain layer contract for routing operations
// ============================================================================

import '../entities/route_entities.dart';

abstract class RoutingRepository {
  /// Plan a multimodal trip
  Future<TripPlanResponse> planTrip(TripPlanRequest request);

  /// Get available transport modes
  Future<List<TransportMode>> getAvailableModes();

  /// Check routing service health
  Future<bool> checkHealth();
}

// Additional entities for modes
class TransportMode {
  final String id;
  final String name;
  final String icon;
  final bool available;
  final List<String>? providers;

  const TransportMode({
    required this.id,
    required this.name,
    required this.icon,
    required this.available,
    this.providers,
  });
}
