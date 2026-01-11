// ============================================================================
// MaaS Platform - App Router
// Named routes configuration
// ============================================================================

import 'package:flutter/material.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/routing/presentation/screens/route_details_screen.dart';
import '../../features/navigation/presentation/screens/active_navigation_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/routing/domain/entities/route_entities.dart';

class AppRouter {
  AppRouter._();

  // Route names
  static const String home = '/';
  static const String routeDetails = '/route-details';
  static const String activeNavigation = '/navigation';
  static const String settings = '/settings';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );

      case routeDetails:
        final route = settings.arguments as PlannedRoute?;
        if (route == null) {
          return _errorRoute('Route details requires a PlannedRoute argument');
        }
        return MaterialPageRoute(
          builder: (_) => RouteDetailsScreen(route: route),
        );

      case activeNavigation:
        return MaterialPageRoute(
          builder: (_) => const ActiveNavigationScreen(),
        );

      case AppRouter.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );

      default:
        return _errorRoute('No route defined for ${settings.name}');
    }
  }

  static MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Błąd nawigacji')),
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}

// Route arguments classes (kept for potential future use)
class RouteDetailsArgs {
  final String routeId;

  const RouteDetailsArgs({required this.routeId});
}

class ActiveNavigationArgs {
  final String routeId;
  final int segmentIndex;

  const ActiveNavigationArgs({
    required this.routeId,
    this.segmentIndex = 0,
  });
}
