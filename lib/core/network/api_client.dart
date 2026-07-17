import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../config/api_config.dart';
import 'api_exception.dart';

class ApiClient extends GetxService {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Tenant-Schema': ApiConfig.tenantSchema,
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Accept'] = 'application/json';
          options.headers['Content-Type'] = 'application/json';
          options.headers['X-Tenant-Schema'] = ApiConfig.tenantSchema;

          final deviceId = ApiConfig.deviceId;
          final deviceToken = ApiConfig.deviceToken;
          if (deviceId != null && deviceId.isNotEmpty) {
            options.headers['X-Device-Id'] = deviceId;
          } else {
            options.headers.remove('X-Device-Id');
          }
          if (deviceToken != null && deviceToken.isNotEmpty) {
            options.headers['X-Device-Token'] = deviceToken;
          } else {
            options.headers.remove('X-Device-Token');
          }

          final token = _authToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;
  String? _authToken;

  Dio get dio => _dio;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Sync Dio base URL / default tenant after restore or successful activation.
  void applyRuntimeConfig() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.headers['X-Tenant-Schema'] = ApiConfig.tenantSchema;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  ApiException _mapError(DioException error) {
    final response = error.response;
    final body = response?.data;
    if (body is Map<String, dynamic>) {
      final message = body['message'] as String?;
      if (message != null && message.isNotEmpty) {
        return ApiException(
          message: message,
          statusCode: response?.statusCode,
          responseBody: body,
        );
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException(
          message: ApiConfig.isLocalPosBaseUrl
              ? 'Délai dépassé vers le poste Windows. Vérifiez l\'IP et le réseau.'
              : 'Connection timed out. Please try again.',
          statusCode: response?.statusCode,
          responseBody: body,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: ApiConfig.isLocalPosBaseUrl
              ? 'Impossible de joindre le poste Windows. '
                  'Vérifiez le Wi‑Fi et l\'adresse IP du poste.'
              : 'No internet connection.',
          statusCode: response?.statusCode,
          responseBody: body,
        );
      default:
        return ApiException(
          message: error.message ?? 'An unexpected error occurred.',
          statusCode: response?.statusCode,
          responseBody: body,
        );
    }
  }
}
