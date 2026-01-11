// ============================================================================
// MaaS Platform - Search Bar Widget
// Destination search with suggestions
// ============================================================================

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';

class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final void Function(LatLng location, String name) onDestinationSelected;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.onDestinationSelected,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  bool _showSuggestions = false;
  final _focusNode = FocusNode();

  // Mock suggestions - in production, use Nominatim or similar
  final List<_PlaceSuggestion> _mockSuggestions = const [
    _PlaceSuggestion(
      name: 'Metro Centrum',
      address: 'Marszałkowska, Śródmieście',
      location: LatLng(52.2290, 21.0030),
      icon: Icons.subway,
    ),
    _PlaceSuggestion(
      name: 'Dworzec Centralny',
      address: 'Aleje Jerozolimskie 54, Śródmieście',
      location: LatLng(52.2282, 21.0027),
      icon: Icons.train,
    ),
    _PlaceSuggestion(
      name: 'Metro Kabaty',
      address: 'Al. KEN, Ursynów',
      location: LatLng(52.1316, 21.0653),
      icon: Icons.subway,
    ),
    _PlaceSuggestion(
      name: 'Lotnisko Chopina',
      address: 'Żwirki i Wigury 1, Włochy',
      location: LatLng(52.1657, 20.9671),
      icon: Icons.flight,
    ),
    _PlaceSuggestion(
      name: 'Stadion Narodowy',
      address: 'al. Poniatowskiego 1, Praga-Południe',
      location: LatLng(52.2395, 21.0453),
      icon: Icons.stadium,
    ),
    _PlaceSuggestion(
      name: 'Złote Tarasy',
      address: 'Złota 59, Śródmieście',
      location: LatLng(52.2299, 21.0022),
      icon: Icons.shopping_bag,
    ),
  ];

  List<_PlaceSuggestion> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _filteredSuggestions = _mockSuggestions;
    _focusNode.addListener(() {
      setState(() => _showSuggestions = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSuggestions = _mockSuggestions;
      } else {
        _filteredSuggestions = _mockSuggestions
            .where((s) =>
                s.name.toLowerCase().contains(query.toLowerCase()) ||
                s.address.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectSuggestion(_PlaceSuggestion suggestion) {
    widget.controller.text = suggestion.name;
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
    widget.onDestinationSelected(suggestion.location, suggestion.name);
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
              prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
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
        if (_showSuggestions && _filteredSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
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
                itemCount: _filteredSuggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = _filteredSuggestions[index];
                  return _SuggestionTile(
                    suggestion: suggestion,
                    onTap: () => _selectSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// Place Suggestion Model
// ============================================================================

class _PlaceSuggestion {
  final String name;
  final String address;
  final LatLng location;
  final IconData icon;

  const _PlaceSuggestion({
    required this.name,
    required this.address,
    required this.location,
    required this.icon,
  });
}

// ============================================================================
// Suggestion Tile Widget
// ============================================================================

class _SuggestionTile extends StatelessWidget {
  final _PlaceSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.suggestion,
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
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                suggestion.icon,
                color: AppTheme.primaryColor,
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
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.address,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
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
}
