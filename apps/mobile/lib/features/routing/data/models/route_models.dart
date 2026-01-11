// ============================================================================
// MaaS Platform - Routing Data Models
// JSON serializable models for API communication
// ============================================================================

import '../../domain/entities/route_entities.dart';

// ============================================================================
// Request Models
// ============================================================================

class TripPlanRequestModel {
  final GeoLocationModel origin;
  final GeoLocationModel destination;
  final String? departureTime;
  final String? arrivalTime;
  final TripPreferencesModel? preferences;

  TripPlanRequestModel({
    required this.origin,
    required this.destination,
    this.departureTime,
    this.arrivalTime,
    this.preferences,
  });

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        if (departureTime != null) 'departureTime': departureTime,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (preferences != null) 'preferences': preferences!.toJson(),
      };

  factory TripPlanRequestModel.fromEntity(TripPlanRequest entity) {
    return TripPlanRequestModel(
      origin: GeoLocationModel.fromEntity(entity.origin),
      destination: GeoLocationModel.fromEntity(entity.destination),
      departureTime: entity.departureTime,
      arrivalTime: entity.arrivalTime,
      preferences: TripPreferencesModel.fromEntity(entity.preferences),
    );
  }
}

class GeoLocationModel {
  final double lat;
  final double lng;

  GeoLocationModel({required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  factory GeoLocationModel.fromJson(Map<String, dynamic> json) {
    return GeoLocationModel(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  factory GeoLocationModel.fromEntity(GeoLocation entity) {
    return GeoLocationModel(lat: entity.lat, lng: entity.lng);
  }

  GeoLocation toEntity() => GeoLocation(lat: lat, lng: lng);
}

class TripPreferencesModel {
  final String mode;
  final bool allowScooters;
  final bool allowBikes;
  final int maxWalkDistance;
  final bool wheelchairAccessible;
  final int numAlternatives;

  TripPreferencesModel({
    this.mode = 'fastest',
    this.allowScooters = true,
    this.allowBikes = true,
    this.maxWalkDistance = 1000,
    this.wheelchairAccessible = false,
    this.numAlternatives = 3,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'allowScooters': allowScooters,
        'allowBikes': allowBikes,
        'maxWalkDistance': maxWalkDistance,
        'wheelchairAccessible': wheelchairAccessible,
        'numAlternatives': numAlternatives,
      };

  factory TripPreferencesModel.fromEntity(TripPreferences entity) {
    return TripPreferencesModel(
      mode: entity.mode.name,
      allowScooters: entity.allowScooters,
      allowBikes: entity.allowBikes,
      maxWalkDistance: entity.maxWalkDistance,
      wheelchairAccessible: entity.wheelchairAccessible,
      numAlternatives: entity.numAlternatives,
    );
  }
}

// ============================================================================
// Response Models
// ============================================================================

class TripPlanResponseModel {
  final bool success;
  final TripPlanDataModel data;

  TripPlanResponseModel({required this.success, required this.data});

  factory TripPlanResponseModel.fromJson(Map<String, dynamic> json) {
    return TripPlanResponseModel(
      success: json['success'] as bool,
      data: TripPlanDataModel.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  TripPlanResponse toEntity() => TripPlanResponse(
        routes: data.routes.map((r) => r.toEntity()).toList(),
        metadata: data.metadata.toEntity(),
      );
}

class TripPlanDataModel {
  final List<PlannedRouteModel> routes;
  final TripPlanMetadataModel metadata;

  TripPlanDataModel({required this.routes, required this.metadata});

  factory TripPlanDataModel.fromJson(Map<String, dynamic> json) {
    return TripPlanDataModel(
      routes: (json['routes'] as List<dynamic>?)
              ?.map((r) => PlannedRouteModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      metadata:
          TripPlanMetadataModel.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }
}

class TripPlanMetadataModel {
  final String computedAt;
  final String otpVersion;

  TripPlanMetadataModel({required this.computedAt, required this.otpVersion});

  factory TripPlanMetadataModel.fromJson(Map<String, dynamic> json) {
    return TripPlanMetadataModel(
      computedAt: json['computedAt'] as String,
      otpVersion: json['otpVersion'] as String,
    );
  }

  TripPlanMetadata toEntity() => TripPlanMetadata(
        computedAt: computedAt,
        otpVersion: otpVersion,
      );
}

class PlannedRouteModel {
  final String id;
  final String summary;
  final int duration;
  final int walkTime;
  final int waitTime;
  final int walkDistance;
  final int transfers;
  final double estimatedCost;
  final String departureTime;
  final String arrivalTime;
  final RouteScoreModel score;
  final List<RouteSegmentModel> segments;

  PlannedRouteModel({
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

  factory PlannedRouteModel.fromJson(Map<String, dynamic> json) {
    return PlannedRouteModel(
      id: json['id'] as String,
      summary: json['summary'] as String,
      duration: (json['duration'] as num).toInt(),
      walkTime: (json['walkTime'] as num).toInt(),
      waitTime: (json['waitTime'] as num).toInt(),
      walkDistance: (json['walkDistance'] as num).toInt(),
      transfers: (json['transfers'] as num).toInt(),
      estimatedCost: (json['estimatedCost'] as num).toDouble(),
      departureTime: json['departureTime'] as String,
      arrivalTime: json['arrivalTime'] as String,
      score: RouteScoreModel.fromJson(json['score'] as Map<String, dynamic>),
      segments: (json['segments'] as List<dynamic>)
          .map((s) => RouteSegmentModel.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  PlannedRoute toEntity() => PlannedRoute(
        id: id,
        summary: summary,
        duration: duration,
        walkTime: walkTime,
        waitTime: waitTime,
        walkDistance: walkDistance,
        transfers: transfers,
        estimatedCost: estimatedCost,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        score: score.toEntity(),
        segments: segments.map((s) => s.toEntity()).toList(),
      );
}

class RouteScoreModel {
  final double overall;
  final double time;
  final double cost;
  final double comfort;

  RouteScoreModel({
    required this.overall,
    required this.time,
    required this.cost,
    required this.comfort,
  });

  factory RouteScoreModel.fromJson(Map<String, dynamic> json) {
    return RouteScoreModel(
      overall: (json['overall'] as num).toDouble(),
      time: (json['time'] as num).toDouble(),
      cost: (json['cost'] as num).toDouble(),
      comfort: (json['comfort'] as num).toDouble(),
    );
  }

  RouteScore toEntity() => RouteScore(
        overall: overall,
        time: time,
        cost: cost,
        comfort: comfort,
      );
}

class RouteSegmentModel {
  final String type;
  final String? provider;
  final LocationDetailModel from;
  final LocationDetailModel to;
  final int duration;
  final int distance;
  final String polyline;
  final double cost;
  final TransitLineModel? line;
  final String? departureTime;
  final String? arrivalTime;
  final int? numStops;
  final bool? isRented;

  RouteSegmentModel({
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
    this.isRented,
  });

  factory RouteSegmentModel.fromJson(Map<String, dynamic> json) {
    return RouteSegmentModel(
      type: json['type'] as String,
      provider: json['provider'] as String?,
      from: LocationDetailModel.fromJson(json['from'] as Map<String, dynamic>),
      to: LocationDetailModel.fromJson(json['to'] as Map<String, dynamic>),
      duration: (json['duration'] as num).toInt(),
      distance: (json['distance'] as num).toInt(),
      polyline: json['polyline'] as String,
      cost: (json['cost'] as num).toDouble(),
      line: json['line'] != null
          ? TransitLineModel.fromJson(json['line'] as Map<String, dynamic>)
          : null,
      departureTime: json['departureTime'] as String?,
      arrivalTime: json['arrivalTime'] as String?,
      numStops: json['numStops'] != null ? (json['numStops'] as num).toInt() : null,
      isRented: json['isRented'] as bool?,
    );
  }

  RouteSegment toEntity() => RouteSegment(
        type: SegmentType.fromString(type),
        provider: provider,
        from: from.toEntity(),
        to: to.toEntity(),
        duration: duration,
        distance: distance,
        polyline: polyline,
        cost: cost,
        line: line?.toEntity(),
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        numStops: numStops,
        isRented: isRented ?? false,
      );
}

class LocationDetailModel {
  final String name;
  final GeoLocationModel location;
  final String? stopId;
  final String? stationId;

  LocationDetailModel({
    required this.name,
    required this.location,
    this.stopId,
    this.stationId,
  });

  factory LocationDetailModel.fromJson(Map<String, dynamic> json) {
    return LocationDetailModel(
      name: json['name'] as String,
      location:
          GeoLocationModel.fromJson(json['location'] as Map<String, dynamic>),
      stopId: json['stopId'] as String?,
      stationId: json['stationId'] as String?,
    );
  }

  LocationDetail toEntity() => LocationDetail(
        name: name,
        location: location.toEntity(),
        stopId: stopId,
        stationId: stationId,
      );
}

class TransitLineModel {
  final String name;
  final String? longName;
  final String color;
  final String? agency;

  TransitLineModel({
    required this.name,
    this.longName,
    required this.color,
    this.agency,
  });

  factory TransitLineModel.fromJson(Map<String, dynamic> json) {
    return TransitLineModel(
      name: json['name'] as String,
      longName: json['longName'] as String?,
      color: json['color'] as String,
      agency: json['agency'] as String?,
    );
  }

  TransitLine toEntity() => TransitLine(
        name: name,
        longName: longName,
        color: color,
        agency: agency,
      );
}
