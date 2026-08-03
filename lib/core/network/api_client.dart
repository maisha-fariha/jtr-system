import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../utils/app_navigation.dart';
import '../config/api_config.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'lan_connection_message.dart';

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

          final skipDevice = options.extra['skipDevice'] == true;
          final skipAuth = options.extra['skipAuth'] == true;

          if (!skipDevice) {
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
          } else {
            options.headers.remove('X-Tenant-Schema');
            options.headers.remove('X-Device-Id');
            options.headers.remove('X-Device-Token');
          }

          if (!skipAuth) {
            final token = _authToken;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              options.headers.remove('Authorization');
            }
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

  String? get authToken => _authToken;

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
    late final ApiException mapped;
    if (body is Map<String, dynamic>) {
      final message = body['message'] as String?;
      if (message != null && message.isNotEmpty) {
        mapped = ApiException(
          message: message,
          statusCode: response?.statusCode,
          responseBody: body,
        );
        _maybeForceLogout(mapped, error.requestOptions.path);
        return mapped;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        mapped = ApiException(
          message: ApiConfig.isLocalPosBaseUrl
              ? lanPosConnectionUserMessage(
                  error: error,
                  targetHost: hostFromBaseUrl(ApiConfig.baseUrl),
                )
              : (error.type == DioExceptionType.connectionError
                  ? 'No internet connection.'
                  : 'Connection timed out. Please try again.'),
          statusCode: response?.statusCode,
          responseBody: body,
        );
      default:
        if (ApiConfig.isLocalPosBaseUrl &&
            (error.message ?? '').toLowerCase().contains('refused')) {
          mapped = ApiException(
            message: lanPosConnectionUserMessage(
              error: error,
              targetHost: hostFromBaseUrl(ApiConfig.baseUrl),
            ),
            statusCode: response?.statusCode,
            responseBody: body,
          );
        } else {
          mapped = ApiException(
            message: error.message ?? 'An unexpected error occurred.',
            statusCode: response?.statusCode,
            responseBody: body,
          );
        }
    }

    _maybeForceLogout(mapped, error.requestOptions.path);
    return mapped;
  }

  void _maybeForceLogout(ApiException exception, String requestPath) {
    if (!exception.isUnauthenticated) return;
    if (_isAuthLoginPath(requestPath)) return;
    AppNavigation.scheduleForceLogoutForUnauthenticated();
  }

  static bool _isAuthLoginPath(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains(ApiEndpoints.login) ||
        normalized.contains(ApiEndpoints.loginUsers) ||
        normalized.contains(ApiEndpoints.loginRoles);
  }
}
