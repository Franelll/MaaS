// ============================================================================
// MaaS Platform - Route Selection Bottom Sheet
// Draggable panel for choosing routes
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/routing_bloc.dart';
import 'trip_card.dart';

class RouteSelectionSheet extends StatelessWidget {
  final VoidCallback? onStartNavigation;

  const RouteSelectionSheet({
    super.key,
    this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.15, 0.4, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              _buildHandle(),
              
              // Content
              Expanded(
                child: BlocBuilder<RoutingBloc, RoutingState>(
                  builder: (context, state) {
                    if (state.status == RoutingStatus.loading) {
                      return _buildLoadingState();
                    }
                    
                    if (state.status == RoutingStatus.error) {
                      return _buildErrorState(context, state.errorMessage);
                    }
                    
                    if (state.routes.isEmpty) {
                      return _buildEmptyState();
                    }
                    
                    return _buildRoutesList(context, state, scrollController);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Finding best routes...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<RoutingBloc>().add(const ClearRoutes());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            SizedBox(height: 16),
            Text(
              'Select destination to find routes',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutesList(
    BuildContext context,
    RoutingState state,
    ScrollController scrollController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text(
                '${state.routes.length} routes found',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Filter chips
              _FilterChip(
                label: 'Fastest',
                isSelected: true,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Cheapest',
                isSelected: false,
                onTap: () {},
              ),
            ],
          ),
        ),
        
        // Routes list
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: state.routes.length,
            itemBuilder: (context, index) {
              final route = state.routes[index];
              final isSelected = state.selectedRoute?.id == route.id;
              
              return TripCard(
                route: route,
                isSelected: isSelected,
                onTap: () {
                  context.read<RoutingBloc>().add(SelectRoute(route.id));
                },
                onStartNavigation: () {
                  context.read<RoutingBloc>().add(StartNavigation(route.id));
                  onStartNavigation?.call();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Filter Chip
// ============================================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
