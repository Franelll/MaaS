// ============================================================================
// MaaS Platform - Active Navigation Screen
// Turn-by-turn navigation view with real-time updates
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../routing/domain/entities/route_entities.dart';
import '../../../routing/presentation/bloc/routing_bloc.dart';
import '../../../home/presentation/widgets/route_polyline_layer.dart';

class ActiveNavigationScreen extends StatefulWidget {
  const ActiveNavigationScreen({super.key});

  @override
  State<ActiveNavigationScreen> createState() => _ActiveNavigationScreenState();
}

class _ActiveNavigationScreenState extends State<ActiveNavigationScreen> {
  final MapController _mapController = MapController();
  Timer? _locationTimer;
  int _currentSegmentIndex = 0;
  bool _isFollowMode = true;

  // Simulated position (in real app, use GPS)
  LatLng _currentPosition = const LatLng(52.2297, 21.0122);

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startLocationUpdates() {
    // In real app, use geolocator stream
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      // Simulate movement along route
      _updatePosition();
    });
  }

  void _updatePosition() {
    // In real app, get actual GPS position
    // For demo, we'll simulate movement
    setState(() {
      // Small random movement for demo
      _currentPosition = LatLng(
        _currentPosition.latitude + 0.0001,
        _currentPosition.longitude + 0.0001,
      );
    });

    if (_isFollowMode) {
      _mapController.move(_currentPosition, 17);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutingBloc, RoutingState>(
      builder: (context, state) {
        final route = state.selectedRoute;
        if (route == null) {
          return const Scaffold(
            body: Center(child: Text('Brak wybranej trasy')),
          );
        }

        final currentSegment = _currentSegmentIndex < route.segments.length
            ? route.segments[_currentSegmentIndex]
            : route.segments.last;

        return Scaffold(
          body: Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition,
                  initialZoom: 17,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      setState(() => _isFollowMode = false);
                    }
                  },
                ),
                children: [
                  // Map tiles
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'pl.maas.app',
                  ),

                  // Route polyline
                  RoutePolylineLayer(route: route),

                  // Current position marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition,
                        width: 50,
                        height: 50,
                        child: _buildCurrentPositionMarker(),
                      ),
                    ],
                  ),

                  // Next stop marker
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentSegment.to.location.toLatLng(),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.flag,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Top instruction card
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: _buildInstructionCard(currentSegment),
                ),
              ),

              // Back button
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                child: _buildBackButton(),
              ),

              // Re-center button
              if (!_isFollowMode)
                Positioned(
                  bottom: 200,
                  right: 16,
                  child: _buildRecenterButton(),
                ),

              // Bottom info panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomPanel(route, currentSegment),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentPositionMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse animation circle
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
        // Direction indicator
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: const Icon(
            Icons.navigation,
            color: Colors.white,
            size: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        onTap: () => _showExitDialog(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.close),
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        onTap: () {
          setState(() => _isFollowMode = true);
          _mapController.move(_currentPosition, 17);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: const Icon(
            Icons.my_location,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard(RouteSegment segment) {
    final color = AppTheme.getSegmentColor(segment.type.name);
    final icon = AppTheme.getSegmentIcon(segment.type.name);
    final durationMinutes = (segment.duration / 60).ceil();

    return Container(
      margin: const EdgeInsets.fromLTRB(60, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getNavigationInstruction(segment),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  segment.to.name,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${segment.distance} m',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$durationMinutes min',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(PlannedRoute route, RouteSegment currentSegment) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            _buildProgressBar(route),
            const SizedBox(height: 16),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.schedule,
                  'Pozostało',
                  '${_calculateRemainingTime(route)} min',
                ),
                _buildStatItem(
                  Icons.place,
                  'Do celu',
                  '${_calculateRemainingDistance(route).toStringAsFixed(1)} km',
                ),
                _buildStatItem(
                  Icons.directions,
                  'Etap',
                  '${_currentSegmentIndex + 1}/${route.segments.length}',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // End navigation button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showExitDialog(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                child: const Text('Zakończ nawigację'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(PlannedRoute route) {
    final progress = (_currentSegmentIndex + 1) / route.segments.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Postęp podróży',
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getNavigationInstruction(RouteSegment segment) {
    switch (segment.type) {
      case SegmentType.walk:
        return 'Idź pieszo';
      case SegmentType.bus:
        return 'Wsiądź do autobusu ${segment.line?.name ?? ""}';
      case SegmentType.tram:
        return 'Wsiądź do tramwaju ${segment.line?.name ?? ""}';
      case SegmentType.metro:
        return 'Wsiądź do metra';
      case SegmentType.rail:
        return 'Wsiądź do pociągu';
      case SegmentType.scooter:
        return 'Jedź hulajnogą';
      case SegmentType.bike:
        return 'Jedź rowerem';
      default:
        return 'Kontynuuj';
    }
  }

  int _calculateRemainingTime(PlannedRoute route) {
    int remaining = 0;
    for (int i = _currentSegmentIndex; i < route.segments.length; i++) {
      remaining += (route.segments[i].duration / 60).ceil();
    }
    return remaining;
  }

  double _calculateRemainingDistance(PlannedRoute route) {
    double remaining = 0;
    for (int i = _currentSegmentIndex; i < route.segments.length; i++) {
      remaining += route.segments[i].distance;
    }
    return remaining / 1000; // Convert to km
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zakończyć nawigację?'),
        content: const Text(
          'Czy na pewno chcesz zakończyć nawigację? '
          'Możesz ją wznowić w dowolnym momencie.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              context.read<RoutingBloc>().add(CancelNavigation());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Zakończ'),
          ),
        ],
      ),
    );
  }
}
