// ============================================================================
// MaaS Platform - Routing Remote Data Source
// API communication for routing endpoints
// ============================================================================

import 'package:dio/dio.dart';

import '../models/route_models.dart';

abstract class RoutingRemoteDataSource {
  Future<TripPlanResponseModel> planTrip(TripPlanRequestModel request);
  Future<bool> checkHealth();
}

class RoutingRemoteDataSourceImpl implements RoutingRemoteDataSource {
  final Dio _dio;

  RoutingRemoteDataSourceImpl(this._dio);

  @override
  Future<TripPlanResponseModel> planTrip(TripPlanRequestModel request) async {
    try {
      final response = await _dio.post(
        '/routing/plan',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return TripPlanResponseModel.fromJson(response.data);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to plan trip: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/routing/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Exception _handleDioError(DioException e) {
    // Log error for debugging
    print('[RoutingDataSource] DioException: ${e.type} - ${e.message}');
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException('Connection timeout. Please try again.');
      case DioExceptionType.connectionError:
        // For localhost, this usually means server is down, not "no internet"
        return NetworkException('Cannot connect to server. Is the API running?');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final message = e.response?.data?['message'] ?? 'Unknown error';
        if (statusCode == 400) {
          return ValidationException(message.toString());
        } else if (statusCode == 404) {
          return NotFoundException('Route not found.');
        } else if (statusCode >= 500) {
          return ServerException('Server error. Please try again later.');
        }
        return ApiException(message.toString());
      default:
        return ApiException('An unexpected error occurred.');
    }
  }
}

// Custom exceptions
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(super.message);
}

class TimeoutException extends ApiException {
  TimeoutException(super.message);
}

class ValidationException extends ApiException {
  ValidationException(super.message);
}

class NotFoundException extends ApiException {
  NotFoundException(super.message);
}

class ServerException extends ApiException {
  ServerException(super.message);
}
