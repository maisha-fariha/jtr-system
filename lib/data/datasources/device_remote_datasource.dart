import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../utils/api_log.dart';
import '../mappers/device_activation_mapper.dart';
import '../models/api_envelope.dart';
import '../models/device_activation_models.dart';

class DeviceRemoteDataSource {
  DeviceRemoteDataSource(this._client);

  final ApiClient _client;

  Future<DeviceSessionInfo> fetchSession() async {
    final path = ApiEndpoints.deviceSession;
    final request = {
      'baseUrl': _client.dio.options.baseUrl,
      'headers': {
        'X-Tenant-Schema':
            _client.dio.options.headers['X-Tenant-Schema']?.toString(),
        'X-Device-Id':
            _client.dio.options.headers['X-Device-Id']?.toString(),
        'X-Device-Token':
            _client.dio.options.headers['X-Device-Token']?.toString(),
      },
    };

    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      final raw = response.data ?? const <String, dynamic>{};
      logDeviceApi(
        method: 'GET',
        path: path,
        request: request,
        response: raw,
        statusCode: response.statusCode,
      );

      final envelope = ApiEnvelope.parseResponse(raw);
      if (!envelope.success || envelope.data is! Map) {
        throw ApiException(
          message:
              envelope.message ?? 'Impossible de récupérer la session poste.',
          statusCode: envelope.status,
        );
      }
      return DeviceActivationMapper.sessionFromJson(
        Map<String, dynamic>.from(envelope.data as Map),
      );
    } on DioException catch (e) {
      logDeviceApi(
        method: 'GET',
        path: path,
        request: request,
        response: e.response?.data,
        statusCode: e.response?.statusCode,
        error: e.message ?? e.toString(),
      );
      rethrow;
    } catch (e) {
      if (e is! ApiException) {
        logDeviceApi(
          method: 'GET',
          path: path,
          request: request,
          error: e.toString(),
        );
      }
      rethrow;
    }
  }

  /// Activate without requiring existing device headers.
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
    final body = <String, dynamic>{
      'code': code,
      'type': 'mobile',
      'app_version': appVersion,
      'public_key': null,
      if (fingerprint?.isNotEmpty == true) 'fingerprint': fingerprint,
      if (metadata != null) 'metadata': metadata,
    };
    final request = {
      'baseUrl': originBaseUrl,
      'headers': {'X-Tenant-Schema': tenantSchema},
      'body': body,
    };

    try {
      final response = await _client.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(
          headers: {
            'X-Tenant-Schema': tenantSchema,
          },
        ),
      );

      final raw = response.data ?? const <String, dynamic>{};
      logDeviceApi(
        method: 'POST',
        path: path,
        request: request,
        response: raw,
        statusCode: response.statusCode,
      );

      final envelope = ApiEnvelope.parseResponse(raw);
      if (!envelope.success || envelope.data is! Map) {
        throw ApiException(
          message: envelope.message ?? 'Activation impossible.',
          statusCode: envelope.status,
        );
      }

      return DeviceActivationMapper.activationFromJson(
        Map<String, dynamic>.from(envelope.data as Map),
      );
    } on DioException catch (e) {
      logDeviceApi(
        method: 'POST',
        path: path,
        request: request,
        response: e.response?.data,
        statusCode: e.response?.statusCode,
        error: e.message ?? e.toString(),
      );
      rethrow;
    } catch (e) {
      if (e is! ApiException) {
        logDeviceApi(
          method: 'POST',
          path: path,
          request: request,
          error: e.toString(),
        );
      }
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
}
