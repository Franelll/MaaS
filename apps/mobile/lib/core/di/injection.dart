// ============================================================================
// MaaS Platform - Dependency Injection Configuration
// Using get_it + injectable
// ============================================================================

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async => getIt.init();

@module
abstract class RegisterModule {
  @lazySingleton
  Dio get dio => Dio(
        BaseOptions(
          // Use localhost for web, 10.0.2.2 for Android emulator
          baseUrl: kIsWeb 
              ? 'http://localhost:3000/api/v1'
              : const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'http://10.0.2.2:3000/api/v1',
                ),
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      )..interceptors.addAll([
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            error: true,
          ),
        ]);
}
