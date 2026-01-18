// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../../features/home/data/datasources/geocoding_remote_datasource.dart';
import '../../features/map/data/datasources/map_remote_datasource.dart';
import '../../features/map/data/repositories/map_repository_impl.dart';
import '../../features/map/domain/repositories/map_repository.dart';
import '../../features/map/presentation/bloc/map_bloc.dart';
import '../../features/routing/data/datasources/routing_remote_datasource.dart';
import '../../features/routing/data/repositories/routing_repository_impl.dart';
import '../../features/routing/domain/repositories/routing_repository.dart';
import '../../features/routing/domain/usecases/plan_trip_usecase.dart';
import '../../features/routing/presentation/bloc/routing_bloc.dart';
import 'injection.dart';

extension GetItInjectableX on GetIt {
  GetIt init({String? environment, EnvironmentFilter? environmentFilter}) {
    final gh = GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    
    // Core
    gh.lazySingleton<Dio>(() => registerModule.dio);
    
    // Data Sources
    gh.lazySingleton<RoutingRemoteDataSource>(
      () => RoutingRemoteDataSourceImpl(gh<Dio>()),
    );
    gh.lazySingleton<MapRemoteDataSource>(
      () => MapRemoteDataSourceImpl(gh<Dio>()),
    );
    gh.lazySingleton<GeocodingRemoteDataSource>(
      () => GeocodingRemoteDataSourceImpl(gh<Dio>()),
    );
    
    // Repositories
    gh.lazySingleton<RoutingRepository>(
      () => RoutingRepositoryImpl(gh<RoutingRemoteDataSource>()),
    );
    gh.lazySingleton<MapRepository>(
      () => MapRepositoryImpl(gh<MapRemoteDataSource>()),
    );
    
    // Use Cases
    gh.lazySingleton<PlanTripUseCase>(
      () => PlanTripUseCase(gh<RoutingRepository>()),
    );
    
    // BLoCs
    gh.factory<RoutingBloc>(
      () => RoutingBloc(planTripUseCase: gh<PlanTripUseCase>()),
    );
    gh.factory<MapBloc>(
      () => MapBloc(mapRepository: gh<MapRepository>()),
    );
    
    return this;
  }
}

class _$RegisterModule extends RegisterModule {}
