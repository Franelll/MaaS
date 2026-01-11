// ============================================================================
// MaaS Platform - Route Polyline Layer
// Renders multimodal route on map with different colors per segment
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../routing/domain/entities/route_entities.dart';

class RoutePolylineLayer extends StatelessWidget {
  final PlannedRoute route;

  const RoutePolylineLayer({
    super.key,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return PolylineLayer(
      polylines: _buildPolylines(),
    );
  }

  List<Polyline> _buildPolylines() {
    final polylines = <Polyline>[];

    for (final segment in route.segments) {
      final points = _decodePolyline(segment.polyline);
      if (points.isEmpty) continue;

      final color = AppTheme.getSegmentColor(segment.type.name);
      final isWalk = segment.type == SegmentType.walk;

      polylines.add(
        Polyline(
          points: points,
          color: color,
          strokeWidth: isWalk ? 4.0 : 6.0,
          isDotted: isWalk,
          borderColor: Colors.white,
          borderStrokeWidth: isWalk ? 1.0 : 2.0,
        ),
      );
    }

    return polylines;
  }

  /// Decode Google-encoded polyline string to list of LatLng
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    if (encoded.isEmpty) return points;

    int index = 0;
    int lat = 0;
    int lng = 0;

    try {
      while (index < encoded.length) {
        // Decode latitude
        int shift = 0;
        int result = 0;
        int byte;
        do {
          if (index >= encoded.length) break;
          byte = encoded.codeUnitAt(index++) - 63;
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20 && index < encoded.length);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        // Decode longitude
        shift = 0;
        result = 0;
        do {
          if (index >= encoded.length) break;
          byte = encoded.codeUnitAt(index++) - 63;
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20 && index < encoded.length);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.add(LatLng(lat / 1E5, lng / 1E5));
      }
    } catch (e) {
      debugPrint('[RoutePolylineLayer] Error decoding polyline: $e');
    }

    return points;
  }
}

// ============================================================================
// Route Segment Markers
// Markers for transit stops and transfer points
// ============================================================================

class RouteSegmentMarkers extends StatelessWidget {
  final PlannedRoute route;
  final void Function(RouteSegment segment)? onSegmentTap;

  const RouteSegmentMarkers({
    super.key,
    required this.route,
    this.onSegmentTap,
  });

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: _buildMarkers(),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (int i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      final color = AppTheme.getSegmentColor(segment.type.name);
      final icon = AppTheme.getSegmentIcon(segment.type.name);

      // Add start marker for non-walk segments
      if (segment.type != SegmentType.walk) {
        markers.add(
          Marker(
            point: segment.from.location.toLatLng(),
            width: 32,
            height: 32,
            child: _SegmentMarker(
              color: color,
              icon: icon,
              label: segment.line?.name,
            ),
          ),
        );
      }

      // Add end marker for last segment
      if (i == route.segments.length - 1) {
        markers.add(
          Marker(
            point: segment.to.location.toLatLng(),
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.place,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }
}

class _SegmentMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String? label;

  const _SegmentMarker({
    required this.color,
    required this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: label != null
            ? Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              )
            : Icon(icon, size: 16, color: color),
      ),
    );
  }
}
