// ============================================================================
// MaaS Platform - Home Screen
// Main screen with fullscreen map and search
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../map/presentation/bloc/map_bloc.dart';
import '../../../routing/presentation/bloc/routing_bloc.dart';
import '../../../routing/domain/entities/route_entities.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/route_polyline_layer.dart';
import '../widgets/vehicle_markers_layer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  final _searchController = TextEditingController();
  bool _showRouteSheet = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          BlocBuilder<MapBloc, MapState>(
            builder: (context, mapState) {
              return BlocBuilder<RoutingBloc, RoutingState>(
                builder: (context, routingState) {
                  return FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: mapState.center,
                      initialZoom: mapState.zoom,
                      minZoom: 10,
                      maxZoom: 18,
                      onTap: (tapPosition, point) {
                        _handleMapTap(context, point);
                      },
                      onLongPress: (tapPosition, point) {
                        _handleMapLongPress(context, point);
                      },
                      // Vehicles are NOT loaded by default - only shown when route is planned
                    ),
                    children: [
                      // Base map layer (OpenStreetMap)
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.maas.app',
                        maxZoom: 19,
                      ),
                      
                      // Route polylines (if route selected)
                      if (routingState.selectedRoute != null)
                        RoutePolylineLayer(
                          route: routingState.selectedRoute!,
                        ),
                      
                      // Vehicle markers disabled - too many to render
                      // VehicleMarkersLayer(
                      //   vehicles: mapState.vehicles,
                      //   selectedVehicle: mapState.selectedVehicle,
                      //   onVehicleTap: (vehicle) {
                      //     context.read<MapBloc>().add(MapSelectVehicle(vehicle.id));
                      //   },
                      // ),
                      
                      // Origin/Destination markers
                      if (routingState.origin != null || routingState.destination != null)
                        MarkerLayer(
                          markers: _buildLocationMarkers(routingState),
                        ),
                      
                      // User location marker
                      if (mapState.userLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: mapState.userLocation!,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              );
            },
          ),

          // Search bar overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SearchBarWidget(
                    controller: _searchController,
                    onDestinationSelected: (location, name) {
                      _handleDestinationSelected(context, location, name);
                    },
                  ),
                ],
              ),
            ),
          ),

          // My location button
          Positioned(
            right: 16,
            bottom: _showRouteSheet ? 320 : 100,
            child: _buildMyLocationButton(context),
          ),

          // Route selection bottom sheet
          if (_showRouteSheet)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildRouteBottomSheet(context),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildLocationMarkers(RoutingState state) {
    final markers = <Marker>[];
    
    if (state.origin != null) {
      markers.add(
        Marker(
          point: state.origin!.toLatLng(),
          width: 40,
          height: 40,
          child: const _LocationMarker(
            color: AppTheme.primaryColor,
            icon: Icons.trip_origin,
          ),
        ),
      );
    }
    
    if (state.destination != null) {
      markers.add(
        Marker(
          point: state.destination!.toLatLng(),
          width: 40,
          height: 40,
          child: const _LocationMarker(
            color: AppTheme.secondaryColor,
            icon: Icons.place,
          ),
        ),
      );
    }
    
    return markers;
  }

  Widget _buildMyLocationButton(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'myLocation',
      mini: true,
      backgroundColor: Colors.white,
      onPressed: () => _goToMyLocation(context),
      child: const Icon(
        Icons.my_location,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildRouteBottomSheet(BuildContext context) {
    return BlocBuilder<RoutingBloc, RoutingState>(
      builder: (context, state) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Content
              Expanded(
                child: _buildRouteContent(context, state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteContent(BuildContext context, RoutingState state) {
    if (state.status == RoutingStatus.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding routes...'),
          ],
        ),
      );
    }

    if (state.status == RoutingStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(state.errorMessage ?? 'Error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _closeRouteSheet(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    if (state.routes.isEmpty) {
      return const Center(child: Text('No routes found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.routes.length,
      itemBuilder: (context, index) {
        final route = state.routes[index];
        final isSelected = state.selectedRoute?.id == route.id;
        
        return _buildRouteCard(context, route, isSelected);
      },
    );
  }

  Widget _buildRouteCard(BuildContext context, PlannedRoute route, bool isSelected) {
    return GestureDetector(
      onTap: () {
        context.read<RoutingBloc>().add(SelectRoute(route.id));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segments row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < route.segments.length; i++) ...[
                    _buildSegmentBadge(route.segments[i]),
                    if (i < route.segments.length - 1) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Time and cost
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 4),
                Text(
                  route.durationFormatted,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payments_outlined, size: 18, color: AppTheme.secondaryColor),
                const SizedBox(width: 4),
                Text(
                  route.costFormatted,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentBadge(RouteSegment segment) {
    final color = AppTheme.getSegmentColor(segment.type.name);
    final icon = AppTheme.getSegmentIcon(segment.type.name);
    final minutes = (segment.duration / 60).ceil();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$minutes min',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  void _handleMapTap(BuildContext context, LatLng point) {
    // Close vehicle selection if any
    context.read<MapBloc>().add(const MapClearSelection());
  }

  void _handleMapLongPress(BuildContext context, LatLng point) {
    // Set destination
    final destination = GeoLocation(lat: point.latitude, lng: point.longitude);
    
    // Get origin: user location or map center
    final mapState = context.read<MapBloc>().state;
    final origin = GeoLocation(
      lat: mapState.userLocation?.latitude ?? mapState.center.latitude,
      lng: mapState.userLocation?.longitude ?? mapState.center.longitude,
    );
    
    debugPrint('[HomeScreen] Long press - planning route');
    debugPrint('[HomeScreen] Origin: ${origin.lat}, ${origin.lng}');
    debugPrint('[HomeScreen] Destination: ${destination.lat}, ${destination.lng}');
    
    // Update origin and destination in state
    context.read<RoutingBloc>().add(UpdateOrigin(origin, originName: 'Current location'));
    context.read<RoutingBloc>().add(UpdateDestination(destination, destinationName: 'Selected location'));
    
    // Plan trip directly with both coordinates
    context.read<RoutingBloc>().add(PlanTripRequested(
      origin: origin,
      destination: destination,
    ));
    
    // Show route sheet
    setState(() => _showRouteSheet = true);
  }

  void _handleDestinationSelected(BuildContext context, LatLng location, String name) {
    final destination = GeoLocation(lat: location.latitude, lng: location.longitude);
    context.read<RoutingBloc>().add(UpdateDestination(destination, destinationName: name));
    
    // Use current map center as origin if not set
    final routingState = context.read<RoutingBloc>().state;
    if (routingState.origin == null) {
      final mapState = context.read<MapBloc>().state;
      final origin = GeoLocation(
        lat: mapState.userLocation?.latitude ?? mapState.center.latitude,
        lng: mapState.userLocation?.longitude ?? mapState.center.longitude,
      );
      context.read<RoutingBloc>().add(UpdateOrigin(origin, originName: 'Current location'));
    }
    
    _planTrip(context);
  }

  void _planTrip(BuildContext context) {
    final state = context.read<RoutingBloc>().state;
    if (state.origin != null && state.destination != null) {
      context.read<RoutingBloc>().add(PlanTripRequested(
        origin: state.origin!,
        destination: state.destination!,
      ));
      setState(() => _showRouteSheet = true);
    }
  }

  void _closeRouteSheet() {
    setState(() => _showRouteSheet = false);
    context.read<RoutingBloc>().add(const ClearRoutes());
  }

  void _goToMyLocation(BuildContext context) {
    final mapState = context.read<MapBloc>().state;
    if (mapState.userLocation != null) {
      _mapController.move(mapState.userLocation!, 15);
    } else {
      // Default to Warsaw center
      _mapController.move(const LatLng(52.2297, 21.0122), 14);
    }
  }
}

// ============================================================================
// Location Marker Widget
// ============================================================================

class _LocationMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _LocationMarker({
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}
