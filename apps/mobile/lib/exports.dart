// ============================================================================
// MaaS Platform - Main Exports
// Barrel file for easier imports
// ============================================================================

// Core
export 'core/di/injection.dart';
export 'core/theme/app_theme.dart';
export 'core/router/app_router.dart';

// Features - Routing
export 'features/routing/domain/entities/route_entities.dart';
export 'features/routing/domain/repositories/routing_repository.dart';
export 'features/routing/domain/usecases/plan_trip_usecase.dart';
export 'features/routing/data/models/route_models.dart';
export 'features/routing/data/datasources/routing_remote_datasource.dart';
export 'features/routing/data/repositories/routing_repository_impl.dart';
export 'features/routing/presentation/bloc/routing_bloc.dart';
export 'features/routing/presentation/widgets/trip_card.dart';
export 'features/routing/presentation/widgets/route_selection_sheet.dart';
export 'features/routing/presentation/screens/route_details_screen.dart';

// Features - Map
export 'features/map/domain/entities/map_entities.dart';
export 'features/map/domain/repositories/map_repository.dart';
export 'features/map/data/datasources/map_remote_datasource.dart';
export 'features/map/data/repositories/map_repository_impl.dart';
export 'features/map/presentation/bloc/map_bloc.dart';

// Features - Home
export 'features/home/presentation/screens/home_screen.dart';
export 'features/home/presentation/widgets/search_bar_widget.dart';
export 'features/home/presentation/widgets/route_polyline_layer.dart';
export 'features/home/presentation/widgets/vehicle_markers_layer.dart';

// Features - Navigation
export 'features/navigation/presentation/screens/active_navigation_screen.dart';

// Features - Settings
export 'features/settings/presentation/screens/settings_screen.dart';
