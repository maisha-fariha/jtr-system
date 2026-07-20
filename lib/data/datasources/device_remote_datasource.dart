import 'package:dio/dio.dart';

import '../../core/config/device_activation_bypass.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/lan_connection_message.dart';
import '../../utils/api_log.dart';
import '../mappers/device_activation_mapper.dart';
import '../models/api_envelope.dart';
import '../models/device_activation_models.dart';

class DeviceRemoteDataSource {
  DeviceRemoteDataSource(this._client);

  final ApiClient _client;

  Future<DeviceSessionInfo> fetchSession() async {
    final path = ApiEndpoints.deviceSession;
    final baseUrl = _client.dio.options.baseUrl;
    final request = {
      'baseUrl': baseUrl,
      'headers': {
        'X-Tenant-Schema':
            _client.dio.options.headers['X-Tenant-Schema']?.toString(),
        'X-Device-Id':
            _client.dio.options.headers['X-Device-Id']?.toString(),
        'X-Device-Token':
            _client.dio.options.headers['X-Device-Token']?.toString(),
      },
    };

    logDeviceApi(
      method: 'GET',
      path: path,
      baseUrl: baseUrl,
      request: request,
    );

    try {
      // Accept any HTTP status so we can always print RESPONSE body.
      final response = await _client.dio.get<dynamic>(
        path,
        options: Options(validateStatus: (_) => true),
      );
      final raw = _asJsonMap(response.data);
      logDeviceApi(
        method: 'GET',
        path: path,
        baseUrl: baseUrl,
        request: request,
        response: raw ?? response.data,
        statusCode: response.statusCode,
      );

      if (response.statusCode != null &&
          (response.statusCode! < 200 || response.statusCode! >= 300)) {
        throw ApiException(
          message: _messageFromBody(raw) ??
              'Session poste impossible (${response.statusCode}).',
          statusCode: response.statusCode,
          responseBody: raw ?? response.data,
        );
      }

      if (raw == null) {
        throw ApiException(
          message: 'Réponse session invalide.',
          statusCode: response.statusCode,
          responseBody: response.data,
        );
      }

      final envelope = ApiEnvelope.parseResponse(raw);
      if (!envelope.success || envelope.data is! Map) {
        throw ApiException(
          message:
              envelope.message ?? 'Impossible de récupérer la session poste.',
          statusCode: envelope.status,
          responseBody: raw,
        );
      }
      return DeviceActivationMapper.sessionFromJson(
        Map<String, dynamic>.from(envelope.data as Map),
      );
    } on DioException catch (e) {
      logDeviceApi(
        method: 'GET',
        path: path,
        baseUrl: baseUrl,
        request: request,
        response: e.response?.data,
        statusCode: e.response?.statusCode,
        error: e.message ?? e.toString(),
      );
      throw ApiException(
        message: lanPosConnectionUserMessage(
          error: e,
          targetHost: hostFromBaseUrl(baseUrl),
        ),
        statusCode: e.response?.statusCode,
        responseBody: e.response?.data,
      );
    } on ApiException catch (e) {
      if (e.responseBody == null) {
        logDeviceApi(
          method: 'GET',
          path: path,
          baseUrl: baseUrl,
          request: request,
          statusCode: e.statusCode,
          error: e.message,
        );
      }
      rethrow;
    } catch (e) {
      logDeviceApi(
        method: 'GET',
        path: path,
        baseUrl: baseUrl,
        request: request,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// GET an absolute URL and return the JSON body (always logged).
  Future<Map<String, dynamic>> fetchJsonFromAbsoluteUrl(String absoluteUrl) async {
    final url = absoluteUrl.trim();
    final request = {'url': url, 'method': 'GET'};

    logDeviceApi(
      method: 'GET',
      path: url,
      request: request,
    );

    try {
      final response = await _client.dio.getUri<dynamic>(
        Uri.parse(url),
        options: Options(validateStatus: (_) => true),
      );
      final raw = _asJsonMap(response.data);

      logDeviceApi(
        method: 'GET',
        path: url,
        request: request,
        response: raw ?? response.data ?? '(empty body)',
        statusCode: response.statusCode,
      );

      if (response.statusCode != null &&
          (response.statusCode! < 200 || response.statusCode! >= 300)) {
        throw ApiException(
          message: _messageFromBody(raw) ??
              'Activation impossible (${response.statusCode}).',
          statusCode: response.statusCode,
          responseBody: raw ?? response.data,
        );
      }

      if (raw == null) {
        throw ApiException(
          message: 'Réponse d\'activation invalide (corps non-JSON).',
          statusCode: response.statusCode,
          responseBody: response.data,
        );
      }

      return raw;
    } on DioException catch (e) {
      logDeviceApi(
        method: 'GET',
        path: url,
        request: request,
        response: e.response?.data ?? '(no HTTP response — network/timeout)',
        statusCode: e.response?.statusCode,
        error: e.message ?? e.toString(),
      );
      throw ApiException(
        message: lanPosConnectionUserMessage(
          error: e,
          targetHost: hostFromBaseUrl(url),
        ),
        statusCode: e.response?.statusCode,
        responseBody: e.response?.data,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      logDeviceApi(
        method: 'GET',
        path: url,
        request: request,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// GET an absolute activation URL (e.g. mocki.io) and parse the envelope.
  ///
  /// Always logs REQUEST + RESPONSE to the console.
  Future<DeviceActivationResult> activateFromUrl(String absoluteUrl) async {
    final raw = await fetchJsonFromAbsoluteUrl(absoluteUrl);

    final envelope = ApiEnvelope.parseResponse(raw);
    if (!envelope.success || envelope.data is! Map) {
      throw ApiException(
        message: envelope.message?.trim().isNotEmpty == true
            ? envelope.message!.trim()
            : 'Activation impossible.',
        statusCode: envelope.status,
        responseBody: raw,
      );
    }

    try {
      return DeviceActivationMapper.activationFromJson(
        Map<String, dynamic>.from(envelope.data as Map),
        message: envelope.message,
      );
    } on FormatException catch (e) {
      throw ApiException(
        message: e.message,
        statusCode: envelope.status,
        responseBody: raw,
      );
    }
  }

  /// Activate without requiring existing device headers.
  ///
  /// Hits `{qr api_base_url origin}/api/devices/activate` and always prints
  /// the HTTP RESPONSE body (success or error).
  Future<DeviceActivationResult> activate({
    required String code,
    required String tenantSchema,
    required String originBaseUrl,
    String appVersion = '1.0.0',
    String? fingerprint,
    Map<String, dynamic>? metadata,
  }) async {
    final previousBase = _client.dio.options.baseUrl;
    final previousTenant =
        _client.dio.options.headers['X-Tenant-Schema']?.toString();
    final previousDeviceId =
        _client.dio.options.headers['X-Device-Id']?.toString();
    final previousDeviceToken =
        _client.dio.options.headers['X-Device-Token']?.toString();

    _client.dio.options.baseUrl = originBaseUrl;
    _client.dio.options.headers['X-Tenant-Schema'] = tenantSchema;
    _client.dio.options.headers.remove('X-Device-Id');
    _client.dio.options.headers.remove('X-Device-Token');
    _client.dio.options.headers.remove('Authorization');

    final path = ApiEndpoints.deviceActivate;
    final normalizedCode = DeviceActivationMapper.normalizeCode(code);
    final isBypass = DeviceActivationBypass.enabled &&
        normalizedCode == DeviceActivationBypass.activationCode;
    // Bypass contract: { code, type } only. Full LAN activate may include extras.
    final body = isBypass
        ? <String, dynamic>{
            'code': DeviceActivationBypass.activationCode,
            'type': DeviceActivationBypass.deviceType,
          }
        : <String, dynamic>{
            'code': code,
            'type': 'mobile',
            'app_version': appVersion,
            'public_key': null,
            if (fingerprint?.isNotEmpty == true) 'fingerprint': fingerprint,
            if (metadata != null) 'metadata': metadata,
          };
    final request = {
      'baseUrl': originBaseUrl,
      'url': '$originBaseUrl$path',
      'headers': {'X-Tenant-Schema': tenantSchema},
      'body': body,
    };

    logDeviceApi(
      method: 'POST',
      path: path,
      baseUrl: originBaseUrl,
      request: request,
    );

    try {
      // Use Dio directly + accept all statuses so RESPONSE always logs.
      final response = await _client.dio.post<dynamic>(
        path,
        data: body,
        options: Options(
          headers: {
            'X-Tenant-Schema': tenantSchema,
          },
          validateStatus: (_) => true,
        ),
      );

      final raw = _asJsonMap(response.data);
      logDeviceApi(
        method: 'POST',
        path: path,
        baseUrl: originBaseUrl,
        request: request,
        response: raw ?? response.data ?? '(empty body)',
        statusCode: response.statusCode,
      );

      if (response.statusCode != null &&
          (response.statusCode! < 200 || response.statusCode! >= 300)) {
        throw ApiException(
          message: _messageFromBody(raw) ??
              'Activation impossible (${response.statusCode}).',
          statusCode: response.statusCode,
          responseBody: raw ?? response.data,
        );
      }

      if (raw == null) {
        throw ApiException(
          message: 'Réponse d\'activation invalide (corps non-JSON).',
          statusCode: response.statusCode,
          responseBody: response.data,
        );
      }

      final envelope = ApiEnvelope.parseResponse(raw);
      if (!envelope.success || envelope.data is! Map) {
        throw ApiException(
          message: envelope.message?.trim().isNotEmpty == true
              ? envelope.message!.trim()
              : 'Activation impossible.',
          statusCode: envelope.status,
          responseBody: raw,
        );
      }

      try {
        return DeviceActivationMapper.activationFromJson(
          Map<String, dynamic>.from(envelope.data as Map),
          message: envelope.message,
          // Bypass may omit these; persist values used for the request.
          fallbackTenantSchema: tenantSchema,
          fallbackApiBaseUrl: originBaseUrl,
        );
      } on FormatException catch (e) {
        throw ApiException(
          message: e.message,
          statusCode: envelope.status,
          responseBody: raw,
        );
      }
    } on DioException catch (e) {
      logDeviceApi(
        method: 'POST',
        path: path,
        baseUrl: originBaseUrl,
        request: request,
        response: e.response?.data ?? '(no HTTP response — network/timeout)',
        statusCode: e.response?.statusCode,
        error: e.message ?? e.toString(),
      );
      throw ApiException(
        message: lanPosConnectionUserMessage(
          error: e,
          targetHost: hostFromBaseUrl(originBaseUrl),
        ),
        statusCode: e.response?.statusCode,
        responseBody: e.response?.data,
      );
    } on ApiException catch (e) {
      // Response already logged above when we had an HTTP body.
      if (e.responseBody == null) {
        logDeviceApi(
          method: 'POST',
          path: path,
          baseUrl: originBaseUrl,
          request: request,
          statusCode: e.statusCode,
          error: e.message,
        );
      }
      rethrow;
    } catch (e) {
      logDeviceApi(
        method: 'POST',
        path: path,
        baseUrl: originBaseUrl,
        request: request,
        error: e.toString(),
      );
      rethrow;
    } finally {
      _client.dio.options.baseUrl = previousBase;
      if (previousTenant != null) {
        _client.dio.options.headers['X-Tenant-Schema'] = previousTenant;
      }
      if (previousDeviceId != null) {
        _client.dio.options.headers['X-Device-Id'] = previousDeviceId;
      }
      if (previousDeviceToken != null) {
        _client.dio.options.headers['X-Device-Token'] = previousDeviceToken;
      }
    }
  }

  static Map<String, dynamic>? _asJsonMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static String? _messageFromBody(Map<String, dynamic>? raw) {
    final message = raw?['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    return null;
  }
}
