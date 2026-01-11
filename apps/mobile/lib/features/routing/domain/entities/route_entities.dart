// ============================================================================
// MaaS Platform - Domain Entities
// Core business entities for routing
// ============================================================================

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

// ============================================================================
// GeoLocation
// ============================================================================
class GeoLocation extends Equatable {
  final double lat;
  final double lng;

  const GeoLocation({
    required this.lat,
    required this.lng,
  });

  LatLng toLatLng() => LatLng(lat, lng);

  @override
  List<Object?> get props => [lat, lng];
}

// ============================================================================
// LocationDetail
// ============================================================================
class LocationDetail extends Equatable {
  final String name;
  final GeoLocation location;
  final String? stopId;
  final String? stationId;

  const LocationDetail({
    required this.name,
    required this.location,
    this.stopId,
    this.stationId,
  });

  @override
  List<Object?> get props => [name, location, stopId, stationId];
}

// ============================================================================
// TransitLine
// ============================================================================
class TransitLine extends Equatable {
  final String name;
  final String? longName;
  final String color;
  final String? agency;

  const TransitLine({
    required this.name,
    this.longName,
    required this.color,
    this.agency,
  });

  @override
  List<Object?> get props => [name, longName, color, agency];
}

// ============================================================================
// RouteSegment
// ============================================================================
enum SegmentType {
  walk,
  bus,
  tram,
  metro,
  rail,
  scooter,
  bike,
  taxi,
  car;

  static SegmentType fromString(String value) {
    return SegmentType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => SegmentType.walk,
    );
  }
}

class RouteSegment extends Equatable {
  final SegmentType type;
  final String? provider;
  final LocationDetail from;
  final LocationDetail to;
  final int duration; // seconds
  final int distance; // meters
  final String polyline;
  final double cost;
  final TransitLine? line;
  final String? departureTime;
  final String? arrivalTime;
  final int? numStops;
  final bool isRented;

  const RouteSegment({
    required this.type,
    this.provider,
    required this.from,
    required this.to,
    required this.duration,
    required this.distance,
    required this.polyline,
    required this.cost,
    this.line,
    this.departureTime,
    this.arrivalTime,
    this.numStops,
    this.isRented = false,
  });

  String get durationFormatted {
    final minutes = (duration / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}min';
  }

  @override
  List<Object?> get props => [
        type,
        provider,
        from,
        to,
        duration,
        distance,
        polyline,
        cost,
        line,
        departureTime,
        arrivalTime,
        numStops,
        isRented,
      ];
}

// ============================================================================
// RouteScore
// ============================================================================
class RouteScore extends Equatable {
  final double overall;
  final double time;
  final double cost;
  final double comfort;

  const RouteScore({
    required this.overall,
    required this.time,
    required this.cost,
    required this.comfort,
  });

  @override
  List<Object?> get props => [overall, time, cost, comfort];
}

// ============================================================================
// PlannedRoute
// ============================================================================
class PlannedRoute extends Equatable {
  final String id;
  final String summary;
  final int duration; // seconds
  final int walkTime; // seconds
  final int waitTime; // seconds
  final int walkDistance; // meters
  final int transfers;
  final double estimatedCost;
  final String departureTime;
  final String arrivalTime;
  final RouteScore score;
  final List<RouteSegment> segments;

  const PlannedRoute({
    required this.id,
    required this.summary,
    required this.duration,
    required this.walkTime,
    required this.waitTime,
    required this.walkDistance,
    required this.transfers,
    required this.estimatedCost,
    required this.departureTime,
    required this.arrivalTime,
    required this.score,
    required this.segments,
  });

  String get durationFormatted {
    final minutes = (duration / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}min';
  }

  String get costFormatted => '${estimatedCost.toStringAsFixed(2)} PLN';

  // Get distinct transport modes used in this route
  List<SegmentType> get modesUsed {
    return segments.map((s) => s.type).toSet().toList();
  }

  @override
  List<Object?> get props => [
        id,
        summary,
        duration,
        walkTime,
        waitTime,
        walkDistance,
        transfers,
        estimatedCost,
        departureTime,
        arrivalTime,
        score,
        segments,
      ];
}

// ============================================================================
// TripPlanResponse
// ============================================================================
class TripPlanResponse extends Equatable {
  final List<PlannedRoute> routes;
  final TripPlanMetadata metadata;

  const TripPlanResponse({
    required this.routes,
    required this.metadata,
  });

  @override
  List<Object?> get props => [routes, metadata];
}

class TripPlanMetadata extends Equatable {
  final String computedAt;
  final String otpVersion;

  const TripPlanMetadata({
    required this.computedAt,
    required this.otpVersion,
  });

  @override
  List<Object?> get props => [computedAt, otpVersion];
}

// ============================================================================
// TripPlanRequest
// ============================================================================
enum OptimizationMode {
  fastest,
  cheapest,
  comfortable;

  static OptimizationMode fromString(String value) {
    return OptimizationMode.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => OptimizationMode.fastest,
    );
  }
}

class TripPlanRequest extends Equatable {
  final GeoLocation origin;
  final GeoLocation destination;
  final String? departureTime;
  final String? arrivalTime;
  final TripPreferences preferences;

  const TripPlanRequest({
    required this.origin,
    required this.destination,
    this.departureTime,
    this.arrivalTime,
    this.preferences = const TripPreferences(),
  });

  @override
  List<Object?> get props => [
        origin,
        destination,
        departureTime,
        arrivalTime,
        preferences,
      ];
}

class TripPreferences extends Equatable {
  final OptimizationMode mode;
  final bool allowScooters;
  final bool allowBikes;
  final int maxWalkDistance;
  final bool wheelchairAccessible;
  final int numAlternatives;

  const TripPreferences({
    this.mode = OptimizationMode.fastest,
    this.allowScooters = true,
    this.allowBikes = true,
    this.maxWalkDistance = 1000,
    this.wheelchairAccessible = false,
    this.numAlternatives = 3,
  });

  @override
  List<Object?> get props => [
        mode,
        allowScooters,
        allowBikes,
        maxWalkDistance,
        wheelchairAccessible,
        numAlternatives,
      ];
}
