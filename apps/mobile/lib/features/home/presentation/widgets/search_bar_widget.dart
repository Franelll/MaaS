// ============================================================================
// MaaS Platform - Search Bar Widget
// Destination search with real-time geocoding suggestions
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/datasources/geocoding_remote_datasource.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final void Function(LatLng location, String name) onDestinationSelected;
  final LatLng? userLocation; // Optional: bias results towards user location

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onDestinationSelected,
    this.userLocation,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  bool _showSuggestions = false;
  bool _isLoading = false;
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  
  // Geocoding data source - nullable to handle DI not being set up
  GeocodingRemoteDataSource? _geocodingDataSource;
  
  // Search results
  List<GeocodingResult> _suggestions = [];
  
  // Fallback suggestions for quick access (Warsaw landmarks)
  static final List<GeocodingResult> _quickAccessPlaces = [
    GeocodingResult(
      id: 'quick_1',
      name: 'Metro Centrum',
      displayName: 'Metro Centrum, Marszałkowska, Śródmieście',
      type: GeocodingResultType.transit,
      location: const LatLng(52.2290, 21.0030),
      district: 'Śródmieście',
    ),
    GeocodingResult(
      id: 'quick_2',
      name: 'Dworzec Centralny',
      displayName: 'Warszawa Centralna, Aleje Jerozolimskie 54',
      type: GeocodingResultType.transit,
      location: const LatLng(52.2282, 21.0027),
      street: 'Aleje Jerozolimskie',
      houseNumber: '54',
      district: 'Śródmieście',
    ),
    GeocodingResult(
      id: 'quick_3',
      name: 'Lotnisko Chopina',
      displayName: 'Port Lotniczy Warszawa-Okęcie',
      type: GeocodingResultType.poi,
      location: const LatLng(52.1657, 20.9671),
      district: 'Włochy',
    ),
    GeocodingResult(
      id: 'quick_4',
      name: 'Stadion Narodowy',
      displayName: 'PGE Narodowy, al. Poniatowskiego 1',
      type: GeocodingResultType.poi,
      location: const LatLng(52.2395, 21.0453),
      street: 'al. Poniatowskiego',
      houseNumber: '1',
      district: 'Praga-Południe',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _suggestions = _quickAccessPlaces;
    
    // Try to get geocoding data source from DI
    try {
      _geocodingDataSource = GetIt.I<GeocodingRemoteDataSource>();
    } catch (e) {
      print('[SearchBar] ⚠️ GeocodingRemoteDataSource not registered, using fallback');
    }
    
    _focusNode.addListener(() {
      setState(() => _showSuggestions = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = _quickAccessPlaces;
        _isLoading = false;
      });
      return;
    }
    
    // If no geocoding service, use local filtering
    if (_geocodingDataSource == null) {
      setState(() {
        _suggestions = _filterQuickAccess(query);
      });
      return;
    }
    
    // Show loading state
    setState(() => _isLoading = true);
    
    // Debounce API calls (300ms)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (query.length < 2) {
        setState(() {
          _suggestions = _quickAccessPlaces;
          _isLoading = false;
        });
        return;
      }
      
      try {
        // Call geocoding API with user location bias
        final results = await _geocodingDataSource!.autocomplete(
          query,
          near: widget.userLocation ?? const LatLng(52.2297, 21.0122), // Warsaw center
          limit: 8,
        );
        
        if (mounted) {
          setState(() {
            _suggestions = results.isNotEmpty ? results : _filterQuickAccess(query);
            _isLoading = false;
          });
        }
      } catch (e) {
        print('[SearchBar] ❌ Geocoding error: $e');
        if (mounted) {
          setState(() {
            _suggestions = _filterQuickAccess(query);
            _isLoading = false;
          });
        }
      }
    });
  }

  List<GeocodingResult> _filterQuickAccess(String query) {
    return _quickAccessPlaces
        .where((s) =>
            s.name.toLowerCase().contains(query.toLowerCase()) ||
            s.displayName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  void _selectSuggestion(GeocodingResult suggestion) {
    widget.controller.text = suggestion.name;
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
    widget.onDestinationSelected(suggestion.location, suggestion.name);
  }

  IconData _getIconForType(GeocodingResultType type) {
    switch (type) {
      case GeocodingResultType.transit:
        return Icons.directions_transit;
      case GeocodingResultType.poi:
        return Icons.place;
      case GeocodingResultType.address:
        return Icons.home;
      case GeocodingResultType.street:
        return Icons.add_road;
      case GeocodingResultType.city:
        return Icons.location_city;
      case GeocodingResultType.district:
        return Icons.map;
      default:
        return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Dokąd jedziesz?',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                    )
                  : const Icon(Icons.search, color: AppTheme.primaryColor),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.controller.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),

        // Suggestions dropdown
        if (_showSuggestions && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 350),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return _SuggestionTile(
                    suggestion: suggestion,
                    icon: _getIconForType(suggestion.type),
                    onTap: () => _selectSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
        ],
        
        // Empty state
        if (_showSuggestions && _suggestions.isEmpty && !_isLoading) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'Nie znaleziono wyników',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// Suggestion Tile Widget
// ============================================================================

class _SuggestionTile extends StatelessWidget {
  final GeocodingResult suggestion;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.suggestion,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getColorForType(suggestion.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: _getColorForType(suggestion.type),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.shortAddress,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (suggestion.distance != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDistance(suggestion.distance!),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.north_east,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForType(GeocodingResultType type) {
    switch (type) {
      case GeocodingResultType.transit:
        return Colors.blue;
      case GeocodingResultType.poi:
        return Colors.orange;
      case GeocodingResultType.address:
        return AppTheme.primaryColor;
      case GeocodingResultType.street:
        return Colors.teal;
      case GeocodingResultType.city:
        return Colors.purple;
      case GeocodingResultType.district:
        return Colors.indigo;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
