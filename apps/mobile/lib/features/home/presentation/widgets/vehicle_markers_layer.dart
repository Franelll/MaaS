// ============================================================================
// MaaS Platform - Vehicle Markers Layer
// Renders available vehicles (scooters, bikes) on the map
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../map/domain/entities/map_entities.dart';

class VehicleMarkersLayer extends StatelessWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selectedVehicle;
  final void Function(Vehicle vehicle)? onVehicleTap;

  const VehicleMarkersLayer({
    super.key,
    required this.vehicles,
    this.selectedVehicle,
    this.onVehicleTap,
  });

  @override
  Widget build(BuildContext context) {
    // Vehicles are already filtered server-side by bbox - render all
    return MarkerLayer(
      markers: vehicles.map((vehicle) => _buildMarker(vehicle)).toList(),
    );
  }

  Marker _buildMarker(Vehicle vehicle) {
    final isSelected = selectedVehicle?.id == vehicle.id;
    
    return Marker(
      point: vehicle.location,
      width: isSelected ? 44 : 36,
      height: isSelected ? 44 : 36,
      child: GestureDetector(
        onTap: () => onVehicleTap?.call(vehicle),
        child: VehicleMarkerWidget(
          vehicle: vehicle,
          isSelected: isSelected,
        ),
      ),
    );
  }
}

class VehicleMarkerWidget extends StatelessWidget {
  final Vehicle vehicle;
  final bool isSelected;

  const VehicleMarkerWidget({
    super.key,
    required this.vehicle,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getVehicleColor();
    final icon = _getVehicleIcon();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isSelected ? 0.6 : 0.4),
            blurRadius: isSelected ? 10 : 6,
            spreadRadius: isSelected ? 2 : 1,
          ),
        ],
        border: Border.all(
          color: isSelected ? color : Colors.white,
          width: isSelected ? 3 : 2,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: isSelected ? color : Colors.white,
          size: isSelected ? 20 : 18,
        ),
      ),
    );
  }

  Color _getVehicleColor() {
    switch (vehicle.type) {
      case VehicleType.scooter:
        return AppTheme.scooterColor;
      case VehicleType.bike:
        return AppTheme.bikeColor;
      case VehicleType.ebike:
        return AppTheme.bikeColor;
      case VehicleType.moped:
        return AppTheme.scooterColor;
      case VehicleType.car:
        return AppTheme.carColor;
      case VehicleType.bus:
        return const Color(0xFFE30613); // ZTM red
      case VehicleType.tram:
        return const Color(0xFFFFD800); // ZTM yellow
    }
  }

  IconData _getVehicleIcon() {
    switch (vehicle.type) {
      case VehicleType.scooter:
        return Icons.electric_scooter;
      case VehicleType.bike:
        return Icons.pedal_bike;
      case VehicleType.ebike:
        return Icons.electric_bike;
      case VehicleType.moped:
        return Icons.moped;
      case VehicleType.car:
        return Icons.directions_car;
      case VehicleType.bus:
        return Icons.directions_bus;
      case VehicleType.tram:
        return Icons.tram;
      default:
        return Icons.help_outline;
    }
  }
}

// ============================================================================
// Vehicle Info Popup
// Bottom sheet with vehicle details
// ============================================================================

class VehicleInfoSheet extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onBook;
  final VoidCallback? onClose;

  const VehicleInfoSheet({
    super.key,
    required this.vehicle,
    this.onBook,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Provider and type
          Row(
            children: [
              VehicleMarkerWidget(vehicle: vehicle),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.provider.toUpperCase(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getVehicleTypeName(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildBatteryIndicator(),
            ],
          ),
          const SizedBox(height: 20),
          
          // Pricing info
          if (vehicle.pricing != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPriceItem(
                    'Odblokowanie',
                    '${vehicle.pricing!.unlockFee.toStringAsFixed(2)} ${vehicle.pricing!.currency}',
                    Icons.lock_open,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildPriceItem(
                    'Za minutę',
                    '${vehicle.pricing!.perMinute.toStringAsFixed(2)} ${vehicle.pricing!.currency}',
                    Icons.timer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // Book button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: vehicle.isAvailable ? onBook : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                vehicle.isAvailable ? 'Zarezerwuj pojazd' : 'Niedostępny',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBatteryIndicator() {
    final level = vehicle.batteryLevel;
    final color = level > 50 
        ? Colors.green 
        : level > 20 
            ? Colors.orange 
            : Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            level > 80 
                ? Icons.battery_full 
                : level > 50 
                    ? Icons.battery_5_bar 
                    : level > 20 
                        ? Icons.battery_3_bar 
                        : Icons.battery_1_bar,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(height: 8),
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

  String _getVehicleTypeName() {
    switch (vehicle.type) {
      case VehicleType.scooter:
        return 'Hulajnoga elektryczna';
      case VehicleType.bike:
        return 'Rower miejski';
      case VehicleType.ebike:
        return 'Rower elektryczny';
      case VehicleType.moped:
        return 'Skuter';
      case VehicleType.car:
        return 'Samochód';
      default:
        return 'Pojazd';
    }
  }
}
