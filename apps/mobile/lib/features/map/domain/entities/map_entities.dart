// ============================================================================
// MaaS Platform - Map Entities
// Domain entities for map features
// ============================================================================

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum VehicleType {
  scooter,
  bike,
  ebike,
  car,
  moped,
  bus,
  tram;

  static VehicleType fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_realtime', '');
    return VehicleType.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => VehicleType.scooter,
    );
  }
}

class Vehicle extends Equatable {
  final String id;
  final VehicleType type;
  final String provider;
  final double lat;
  final double lng;
  final int batteryLevel;
  final double? range;
  final bool isAvailable;
  final VehiclePricing? pricing;
  final String? routeShortName; // Line number for transit
  final String? headsign;

  const Vehicle({
    required this.id,
    required this.type,
    required this.provider,
    required this.lat,
    required this.lng,
    required this.batteryLevel,
    this.range,
    this.isAvailable = true,
    this.pricing,
    this.routeShortName,
    this.headsign,
  });

  LatLng get location => LatLng(lat, lng);

  String get displayName {
    if (type == VehicleType.bus || type == VehicleType.tram) {
      return routeShortName ?? provider;
    }
    return '${provider.toUpperCase()} ${type.name}';
  }

  String get batteryDisplay => '$batteryLevel%';

  String get rangeDisplay => range != null ? '${range!.toStringAsFixed(1)} km' : 'N/A';

  @override
  List<Object?> get props => [
        id,
        type,
        provider,
        lat,
        lng,
        batteryLevel,
        range,
        isAvailable,
        pricing,
        routeShortName,
        headsign,
      ];
}

class VehiclePricing extends Equatable {
  final double unlockFee;
  final double perMinute;
  final String currency;

  const VehiclePricing({
    required this.unlockFee,
    required this.perMinute,
    this.currency = 'PLN',
  });

  String get displayPrice => '${unlockFee.toStringAsFixed(2)} $currency + ${perMinute.toStringAsFixed(2)}/min';

  @override
  List<Object?> get props => [unlockFee, perMinute, currency];
}

class TransitStop extends Equatable {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type; // bus, tram, metro
  final List<String> lines;

  const TransitStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    this.lines = const [],
  });

  LatLng get location => LatLng(lat, lng);

  @override
  List<Object?> get props => [id, name, lat, lng, type, lines];
}
