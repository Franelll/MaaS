// ============================================================================
// MaaS Platform - Trip Card Widget
// Beautiful route summary card component
// ============================================================================

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/route_entities.dart';

class TripCard extends StatelessWidget {
  final PlannedRoute route;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onStartNavigation;

  const TripCard({
    super.key,
    required this.route,
    this.isSelected = false,
    this.onTap,
    this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.05) 
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route summary with segments
                  _buildSegmentsSummary(context),
                  
                  const SizedBox(height: 16),
                  
                  // Time and cost row
                  _buildTimeAndCost(context),
                  
                  const SizedBox(height: 12),
                  
                  // Additional info
                  _buildAdditionalInfo(context),
                ],
              ),
            ),
            
            // Action button (only if selected)
            if (isSelected) ...[
              const Divider(height: 1),
              _buildActionButton(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentsSummary(BuildContext context) {
    final segments = route.segments;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < segments.length; i++) ...[
            _SegmentChip(segment: segments[i]),
            if (i < segments.length - 1) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTimeAndCost(BuildContext context) {
    return Row(
      children: [
        // Duration
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                route.durationFormatted,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Cost
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.payments_outlined,
                size: 18,
                color: AppTheme.secondaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                route.costFormatted,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Score indicator
        _buildScoreIndicator(),
      ],
    );
  }

  Widget _buildScoreIndicator() {
    final score = route.score.overall;
    Color scoreColor;
    String scoreLabel;
    
    if (score >= 0.8) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent';
    } else if (score >= 0.6) {
      scoreColor = Colors.orange;
      scoreLabel = 'Good';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Fair';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            size: 14,
            color: scoreColor,
          ),
          const SizedBox(width: 4),
          Text(
            scoreLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scoreColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(BuildContext context) {
    return Row(
      children: [
        // Walking distance
        _InfoChip(
          icon: Icons.directions_walk,
          label: '${(route.walkDistance / 1000).toStringAsFixed(1)} km walk',
        ),
        
        const SizedBox(width: 12),
        
        // Transfers
        if (route.transfers > 0)
          _InfoChip(
            icon: Icons.swap_horiz,
            label: '${route.transfers} transfer${route.transfers > 1 ? 's' : ''}',
          ),
        
        const Spacer(),
        
        // Departure time
        Text(
          _formatTime(route.departureTime),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const Text(' → '),
        Text(
          _formatTime(route.arrivalTime),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return InkWell(
      onTap: onStartNavigation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.navigation,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Start Navigation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }
}

// ============================================================================
// Segment Chip Widget
// ============================================================================

class _SegmentChip extends StatelessWidget {
  final RouteSegment segment;

  const _SegmentChip({required this.segment});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getSegmentColor(segment.type.name);
    final icon = AppTheme.getSegmentIcon(segment.type.name);
    final minutes = (segment.duration / 60).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            '$minutes min',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          // Show line name for transit
          if (segment.line != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _parseColor(segment.line!.color),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                segment.line!.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ============================================================================
// Info Chip Widget
// ============================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
