// ============================================================================
// MaaS Platform - Plan Trip Use Case
// Application business logic for trip planning
// ============================================================================

import '../entities/route_entities.dart';
import '../repositories/routing_repository.dart';

class PlanTripUseCase {
  final RoutingRepository _repository;

  PlanTripUseCase(this._repository);

  Future<TripPlanResponse> call(TripPlanRequest request) async {
    // Business logic validation
    if (request.origin.lat == request.destination.lat &&
        request.origin.lng == request.destination.lng) {
      throw ArgumentError('Origin and destination cannot be the same');
    }

    // Distance check (rough estimate) - don't plan trips > 50km
    final distance = _calculateRoughDistance(
      request.origin.lat,
      request.origin.lng,
      request.destination.lat,
      request.destination.lng,
    );

    if (distance > 50) {
      throw ArgumentError('Distance too large for multimodal planning (max 50km)');
    }

    return _repository.planTrip(request);
  }

  /// Rough distance calculation in km using Haversine approximation
  double _calculateRoughDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorSin(x + 1.5707963267948966);
  double _sqrt(double x) => x > 0 ? _newtonSqrt(x) : 0;
  double _atan2(double y, double x) {
    if (x > 0) return _taylorAtan(y / x);
    if (x < 0 && y >= 0) return _taylorAtan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _taylorAtan(y / x) - 3.14159265359;
    if (y > 0) return 1.5707963267948966;
    if (y < 0) return -1.5707963267948966;
    return 0;
  }

  double _taylorSin(double x) {
    // Normalize to [-pi, pi]
    while (x > 3.14159265359) x -= 6.28318530718;
    while (x < -3.14159265359) x += 6.28318530718;
    
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / (2 * i * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _taylorAtan(double x) {
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * 1.5707963267948966 - _taylorAtan(1 / x);
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 20; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  double _newtonSqrt(double x) {
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
