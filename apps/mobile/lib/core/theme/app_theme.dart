// ============================================================================
// MaaS Platform - App Theme Configuration
// Material Design 3 Theme
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand Colors
  static const Color primaryColor = Color(0xFF2563EB); // Blue 600
  static const Color primaryDarkColor = Color(0xFF1D4ED8); // Blue 700
  static const Color secondaryColor = Color(0xFF10B981); // Emerald 500
  static const Color accentColor = Color(0xFFF59E0B); // Amber 500
  
  // Segment Colors for different transport modes
  static const Color walkColor = Color(0xFF6B7280); // Gray 500
  static const Color busColor = Color(0xFFEF4444); // Red 500
  static const Color tramColor = Color(0xFFF97316); // Orange 500
  static const Color metroColor = Color(0xFFDC2626); // Red 600
  static const Color railColor = Color(0xFF7C3AED); // Violet 600
  static const Color scooterColor = Color(0xFF10B981); // Emerald 500
  static const Color bikeColor = Color(0xFF06B6D4); // Cyan 500
  static const Color taxiColor = Color(0xFFFBBF24); // Yellow 400
  static const Color carColor = Color(0xFF3B82F6); // Blue 500
  
  // Surface Colors
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color surfaceDark = Color(0xFF1F2937);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceLight,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceDark,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Helper method to get color for transport mode
  static Color getSegmentColor(String segmentType) {
    switch (segmentType.toUpperCase()) {
      case 'WALK':
        return walkColor;
      case 'BUS':
        return busColor;
      case 'TRAM':
        return tramColor;
      case 'METRO':
        return metroColor;
      case 'RAIL':
        return railColor;
      case 'SCOOTER':
        return scooterColor;
      case 'BIKE':
        return bikeColor;
      case 'TAXI':
        return taxiColor;
      default:
        return primaryColor;
    }
  }

  // Helper method to get icon for transport mode
  static IconData getSegmentIcon(String segmentType) {
    switch (segmentType.toUpperCase()) {
      case 'WALK':
        return Icons.directions_walk;
      case 'BUS':
        return Icons.directions_bus;
      case 'TRAM':
        return Icons.tram;
      case 'METRO':
        return Icons.subway;
      case 'RAIL':
        return Icons.train;
      case 'SCOOTER':
        return Icons.electric_scooter;
      case 'BIKE':
        return Icons.pedal_bike;
      case 'TAXI':
        return Icons.local_taxi;
      default:
        return Icons.directions;
    }
  }
}
