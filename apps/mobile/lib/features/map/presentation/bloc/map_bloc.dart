// ============================================================================
// MaaS Platform - Map BLoC
// State management for map features
// ============================================================================

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../domain/repositories/map_repository.dart';
import '../../domain/entities/map_entities.dart';

// ============================================================================
// Events
// ============================================================================

abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

class MapInitialize extends MapEvent {
  const MapInitialize();
}

class MapMoveToLocation extends MapEvent {
  final LatLng location;
  final double? zoom;

  const MapMoveToLocation(this.location, {this.zoom});

  @override
  List<Object?> get props => [location, zoom];
}

class MapLoadVehicles extends MapEvent {
  final LatLng center;
  final double radius;

  const MapLoadVehicles(this.center, {this.radius = 1000});

  @override
  List<Object?> get props => [center, radius];
}

/// Load vehicles within bounding box (preferred for viewport culling)
class MapLoadVehiclesInBounds extends MapEvent {
  final double north;
  final double south;
  final double east;
  final double west;

  const MapLoadVehiclesInBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  @override
  List<Object?> get props => [north, south, east, west];
}

class MapSelectVehicle extends MapEvent {
  final String vehicleId;

  const MapSelectVehicle(this.vehicleId);

  @override
  List<Object?> get props => [vehicleId];
}

class MapClearSelection extends MapEvent {
  const MapClearSelection();
}

class MapUpdateUserLocation extends MapEvent {
  final LatLng location;

  const MapUpdateUserLocation(this.location);

  @override
  List<Object?> get props => [location];
}

// Extension for convenience
extension MapEventExtension on MapEvent {
  static const initialize = MapInitialize();
}

// ============================================================================
// State
// ============================================================================

enum MapStatus {
  initial,
  loading,
  loaded,
  error,
}

class MapState extends Equatable {
  final MapStatus status;
  final LatLng center;
  final double zoom;
  final LatLng? userLocation;
  final List<Vehicle> vehicles;
  final Vehicle? selectedVehicle;
  final String? errorMessage;

  const MapState({
    this.status = MapStatus.initial,
    this.center = const LatLng(52.2297, 21.0122), // Warsaw center
    this.zoom = 14.0,
    this.userLocation,
    this.vehicles = const [],
    this.selectedVehicle,
    this.errorMessage,
  });

  MapState copyWith({
    MapStatus? status,
    LatLng? center,
    double? zoom,
    LatLng? userLocation,
    List<Vehicle>? vehicles,
    Vehicle? selectedVehicle,
    String? errorMessage,
    bool clearVehicle = false,
    bool clearError = false,
  }) {
    return MapState(
      status: status ?? this.status,
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      userLocation: userLocation ?? this.userLocation,
      vehicles: vehicles ?? this.vehicles,
      selectedVehicle: clearVehicle ? null : (selectedVehicle ?? this.selectedVehicle),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        center,
        zoom,
        userLocation,
        vehicles,
        selectedVehicle,
        errorMessage,
      ];
}

// ============================================================================
// BLoC
// ============================================================================

/// Debounce transformer for map events - prevents API spam during pan/zoom
EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class MapBloc extends Bloc<MapEvent, MapState> {
  final MapRepository _mapRepository;

  MapBloc({
    required MapRepository mapRepository,
  })  : _mapRepository = mapRepository,
        super(const MapState()) {
    on<MapInitialize>(_onInitialize);
    on<MapMoveToLocation>(_onMoveToLocation);
    on<MapLoadVehicles>(_onLoadVehicles);
    // Debounce bbox loading to avoid API spam during pan/zoom
    on<MapLoadVehiclesInBounds>(
      _onLoadVehiclesInBounds,
      transformer: debounce(const Duration(milliseconds: 300)),
    );
    on<MapSelectVehicle>(_onSelectVehicle);
    on<MapClearSelection>(_onClearSelection);
    on<MapUpdateUserLocation>(_onUpdateUserLocation);
  }

  Future<void> _onInitialize(
    MapInitialize event,
    Emitter<MapState> emit,
  ) async {
    emit(state.copyWith(status: MapStatus.loading));
    
    try {
      // Load initial vehicles around default center (Warsaw)
      final vehicles = await _mapRepository.getNearbyVehicles(
        state.center.latitude,
        state.center.longitude,
        5000, // 5km radius for initial load
      );
      
      emit(state.copyWith(
        status: MapStatus.loaded,
        vehicles: vehicles,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MapStatus.loaded, // Don't fail on vehicle load error
        vehicles: [],
      ));
    }
  }

  void _onMoveToLocation(
    MapMoveToLocation event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(
      center: event.location,
      zoom: event.zoom,
    ));
  }

  Future<void> _onLoadVehicles(
    MapLoadVehicles event,
    Emitter<MapState> emit,
  ) async {
    try {
      final vehicles = await _mapRepository.getNearbyVehicles(
        event.center.latitude,
        event.center.longitude,
        event.radius,
      );
      
      // REPLACE vehicles entirely (not append)
      emit(state.copyWith(vehicles: vehicles));
    } catch (e) {
      debugPrint('[MapBloc] Error loading vehicles: $e');
    }
  }

  /// Load vehicles strictly within bounding box - REPLACES all vehicles
  Future<void> _onLoadVehiclesInBounds(
    MapLoadVehiclesInBounds event,
    Emitter<MapState> emit,
  ) async {
    debugPrint('[MapBloc] Loading vehicles in bounds: N=${event.north.toStringAsFixed(4)}, S=${event.south.toStringAsFixed(4)}');
    
    try {
      final vehicles = await _mapRepository.getVehiclesInBounds(
        event.north,
        event.south,
        event.east,
        event.west,
      );
      
      debugPrint('[MapBloc] ✅ Loaded ${vehicles.length} vehicles (REPLACING old list)');
      
      // CRITICAL: REPLACE the entire vehicle list, don't append
      emit(state.copyWith(vehicles: vehicles));
    } catch (e) {
      debugPrint('[MapBloc] ❌ Error loading vehicles in bounds: $e');
    }
  }

  void _onSelectVehicle(
    MapSelectVehicle event,
    Emitter<MapState> emit,
  ) {
    final vehicle = state.vehicles.firstWhere(
      (v) => v.id == event.vehicleId,
      orElse: () => state.vehicles.first,
    );
    emit(state.copyWith(selectedVehicle: vehicle));
  }

  void _onClearSelection(
    MapClearSelection event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(clearVehicle: true));
  }

  void _onUpdateUserLocation(
    MapUpdateUserLocation event,
    Emitter<MapState> emit,
  ) {
    emit(state.copyWith(userLocation: event.location));
  }
}
