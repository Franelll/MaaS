// ============================================================================
// MaaS Platform - Routing BLoC
// State management for trip planning
// ============================================================================

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/route_entities.dart';
import '../../domain/usecases/plan_trip_usecase.dart';

// ============================================================================
// Events
// ============================================================================

abstract class RoutingEvent extends Equatable {
  const RoutingEvent();

  @override
  List<Object?> get props => [];
}

class PlanTripRequested extends RoutingEvent {
  final GeoLocation origin;
  final GeoLocation destination;
  final TripPreferences preferences;

  const PlanTripRequested({
    required this.origin,
    required this.destination,
    this.preferences = const TripPreferences(),
  });

  @override
  List<Object?> get props => [origin, destination, preferences];
}

class SelectRoute extends RoutingEvent {
  final String routeId;

  const SelectRoute(this.routeId);

  @override
  List<Object?> get props => [routeId];
}

class ClearRoutes extends RoutingEvent {
  const ClearRoutes();
}

class UpdateOrigin extends RoutingEvent {
  final GeoLocation origin;
  final String? originName;

  const UpdateOrigin(this.origin, {this.originName});

  @override
  List<Object?> get props => [origin, originName];
}

class UpdateDestination extends RoutingEvent {
  final GeoLocation destination;
  final String? destinationName;

  const UpdateDestination(this.destination, {this.destinationName});

  @override
  List<Object?> get props => [destination, destinationName];
}

class StartNavigation extends RoutingEvent {
  final PlannedRoute route;

  const StartNavigation(this.route);

  @override
  List<Object?> get props => [route];
}

class CancelNavigation extends RoutingEvent {
  const CancelNavigation();
}

class StopNavigation extends RoutingEvent {
  const StopNavigation();
}

// ============================================================================
// State
// ============================================================================

enum RoutingStatus {
  initial,
  loading,
  loaded,
  error,
  navigating,
}

class RoutingState extends Equatable {
  final RoutingStatus status;
  final GeoLocation? origin;
  final String? originName;
  final GeoLocation? destination;
  final String? destinationName;
  final List<PlannedRoute> routes;
  final PlannedRoute? selectedRoute;
  final String? errorMessage;
  final int? currentSegmentIndex;
  final TripPlanMetadata? metadata;

  const RoutingState({
    this.status = RoutingStatus.initial,
    this.origin,
    this.originName,
    this.destination,
    this.destinationName,
    this.routes = const [],
    this.selectedRoute,
    this.errorMessage,
    this.currentSegmentIndex,
    this.metadata,
  });

  RoutingState copyWith({
    RoutingStatus? status,
    GeoLocation? origin,
    String? originName,
    GeoLocation? destination,
    String? destinationName,
    List<PlannedRoute>? routes,
    PlannedRoute? selectedRoute,
    String? errorMessage,
    int? currentSegmentIndex,
    TripPlanMetadata? metadata,
    bool clearSelectedRoute = false,
    bool clearError = false,
  }) {
    return RoutingState(
      status: status ?? this.status,
      origin: origin ?? this.origin,
      originName: originName ?? this.originName,
      destination: destination ?? this.destination,
      destinationName: destinationName ?? this.destinationName,
      routes: routes ?? this.routes,
      selectedRoute: clearSelectedRoute ? null : (selectedRoute ?? this.selectedRoute),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get canPlanTrip => origin != null && destination != null;
  
  bool get hasRoutes => routes.isNotEmpty;
  
  bool get isNavigating => status == RoutingStatus.navigating;

  @override
  List<Object?> get props => [
        status,
        origin,
        originName,
        destination,
        destinationName,
        routes,
        selectedRoute,
        errorMessage,
        currentSegmentIndex,
        metadata,
      ];
}

// ============================================================================
// BLoC
// ============================================================================

class RoutingBloc extends Bloc<RoutingEvent, RoutingState> {
  final PlanTripUseCase _planTripUseCase;

  RoutingBloc({
    required PlanTripUseCase planTripUseCase,
  })  : _planTripUseCase = planTripUseCase,
        super(const RoutingState()) {
    on<PlanTripRequested>(_onPlanTripRequested);
    on<SelectRoute>(_onSelectRoute);
    on<ClearRoutes>(_onClearRoutes);
    on<UpdateOrigin>(_onUpdateOrigin);
    on<UpdateDestination>(_onUpdateDestination);
    on<StartNavigation>(_onStartNavigation);
    on<StopNavigation>(_onStopNavigation);
    on<CancelNavigation>(_onCancelNavigation);
  }

  Future<void> _onPlanTripRequested(
    PlanTripRequested event,
    Emitter<RoutingState> emit,
  ) async {
    debugPrint('[RoutingBloc] PlanTripRequested received');
    debugPrint('[RoutingBloc] From: ${event.origin.lat}, ${event.origin.lng}');
    debugPrint('[RoutingBloc] To: ${event.destination.lat}, ${event.destination.lng}');
    
    emit(state.copyWith(
      status: RoutingStatus.loading,
      clearError: true,
    ));

    try {
      final request = TripPlanRequest(
        origin: event.origin,
        destination: event.destination,
        preferences: event.preferences,
      );

      debugPrint('[RoutingBloc] Calling planTripUseCase...');
      final response = await _planTripUseCase(request);
      debugPrint('[RoutingBloc] Got ${response.routes.length} routes');

      if (response.routes.isEmpty) {
        emit(state.copyWith(
          status: RoutingStatus.error,
          errorMessage: 'No routes found for this trip.',
        ));
      } else {
        emit(state.copyWith(
          status: RoutingStatus.loaded,
          routes: response.routes,
          selectedRoute: response.routes.first,
          metadata: response.metadata,
        ));
      }
    } catch (e, stackTrace) {
      debugPrint('[RoutingBloc] Error: $e');
      debugPrint('[RoutingBloc] Stack: $stackTrace');
      emit(state.copyWith(
        status: RoutingStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onSelectRoute(
    SelectRoute event,
    Emitter<RoutingState> emit,
  ) {
    final route = state.routes.firstWhere(
      (r) => r.id == event.routeId,
      orElse: () => state.routes.first,
    );
    emit(state.copyWith(selectedRoute: route));
  }

  void _onClearRoutes(
    ClearRoutes event,
    Emitter<RoutingState> emit,
  ) {
    emit(const RoutingState());
  }

  void _onUpdateOrigin(
    UpdateOrigin event,
    Emitter<RoutingState> emit,
  ) {
    emit(state.copyWith(
      origin: event.origin,
      originName: event.originName,
      status: RoutingStatus.initial,
      routes: const [],
      clearSelectedRoute: true,
    ));
  }

  void _onUpdateDestination(
    UpdateDestination event,
    Emitter<RoutingState> emit,
  ) {
    emit(state.copyWith(
      destination: event.destination,
      destinationName: event.destinationName,
      status: RoutingStatus.initial,
      routes: const [],
      clearSelectedRoute: true,
    ));
  }

  void _onStartNavigation(
    StartNavigation event,
    Emitter<RoutingState> emit,
  ) {
    emit(state.copyWith(
      status: RoutingStatus.navigating,
      selectedRoute: event.route,
      currentSegmentIndex: 0,
    ));
  }

  void _onStopNavigation(
    StopNavigation event,
    Emitter<RoutingState> emit,
  ) {
    emit(state.copyWith(
      status: RoutingStatus.loaded,
      currentSegmentIndex: null,
    ));
  }

  void _onCancelNavigation(
    CancelNavigation event,
    Emitter<RoutingState> emit,
  ) {
    emit(state.copyWith(
      status: RoutingStatus.loaded,
      currentSegmentIndex: null,
    ));
  }
}
