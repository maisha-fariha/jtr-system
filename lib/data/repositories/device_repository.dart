import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/device_secure_storage.dart';
import '../../utils/api_log.dart';
import '../datasources/device_remote_datasource.dart';
import '../mappers/device_activation_mapper.dart';
import '../models/api_envelope.dart';
import '../models/device_activation_models.dart';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

class DeviceRepository {
  DeviceRepository({
    required DeviceRemoteDataSource remote,
    required DeviceSecureStorage secureStorage,
    required ApiClient apiClient,
  })  : _remote = remote,
        _secureStorage = secureStorage,
        _apiClient = apiClient;

  final DeviceRemoteDataSource _remote;
  final DeviceSecureStorage _secureStorage;
  final ApiClient _apiClient;

  static const appVersion = '1.0.0';

  Future<bool> get hasStoredCredentials => _secureStorage.hasCredentials;

  Future<DeviceCredentials?> readStoredCredentials() =>
      _secureStorage.readCredentials();

  /// Applies saved device credentials to [ApiConfig] + Dio.
  Future<bool> restoreRuntimeFromStorage() async {
    final creds = await _secureStorage.readCredentials();
    if (creds == null) {
      ApiConfig.resetToDefaults();
      _apiClient.applyRuntimeConfig();
      return false;
    }

    ApiConfig.applyRuntime(
      baseUrl: creds.apiBaseUrl,
      tenantSchema: creds.tenantSchema,
      deviceId: creds.deviceId,
      deviceToken: creds.deviceToken,
    );
    _apiClient.applyRuntimeConfig();
    return true;
  }

  /// Sync Dio to current [ApiConfig] (e.g. after QR sets POS URL).
  void applyRuntimeConfigOnly() => _apiClient.applyRuntimeConfig();

  Future<DeviceGateOutcome> resolveStartupGate() async {
    final hasCreds = await _secureStorage.hasCredentials;
    if (!hasCreds) {
      ApiConfig.resetToDefaults();
      _apiClient.applyRuntimeConfig();
      logDeviceActivation(phase: 'GATE_NO_CREDENTIALS');
      return DeviceGateOutcome.needsActivation;
    }

    await restoreRuntimeFromStorage();
    logDeviceActivation(
      phase: 'GATE_CREDS_RESTORED',
      posUrl: ApiConfig.baseUrl,
      response: {
        'tenant_schema': ApiConfig.tenantSchema,
        'device_id': ApiConfig.deviceId,
        'has_token': ApiConfig.deviceToken?.isNotEmpty == true,
      },
    );

    try {
      final session = await _remote.fetchSession();
      if (session.isActive) {
        logDeviceActivation(
          phase: 'GATE_SESSION_ACTIVE',
          response: {
            'device_id': session.deviceId,
            'status': session.status,
            'label': session.label,
          },
        );
        return DeviceGateOutcome.active;
      }
      if (session.isDeactivated) {
        logDeviceActivation(phase: 'GATE_SESSION_DEACTIVATED');
        return DeviceGateOutcome.deactivated;
      }
      logDeviceActivation(
        phase: 'GATE_SESSION_OTHER_STATUS',
        response: {'status': session.status},
      );
      return DeviceGateOutcome.deactivated;
    } on ApiException catch (e) {
      final outcome =
          DeviceActivationMapper.mapSessionErrorMessage(e.message);
      logDeviceActivation(
        phase: 'GATE_SESSION_ERROR',
        error: e.message,
        response: {
          'mapped_outcome': outcome.name,
          'statusCode': e.statusCode,
          'body': e.responseBody,
        },
      );
      // Only wipe storage on explicit revoke / invalid device credentials.
      if (outcome == DeviceGateOutcome.needsActivation) {
        await clearDeviceCredentials();
        logDeviceActivation(phase: 'GATE_CREDENTIALS_CLEARED');
      }
      return outcome;
    } catch (e) {
      // Network/unknown: keep credentials so reopen still reaches login/home.
      logDeviceActivation(
        phase: 'GATE_SESSION_NETWORK',
        error: e.toString(),
      );
      return DeviceGateOutcome.active;
    }
  }

  Future<DeviceActivationResult> activateWithCode({
    required String code,
    required String tenantSchema,
    required String apiBaseUrl,
  }) async {
    final normalizedCode = DeviceActivationMapper.normalizeCode(code);
    if (normalizedCode.length < 8) {
      throw const FormatException('Code d\'activation invalide.');
    }
    final payload = ActivationQrPayload(
      version: 1,
      apiBaseUrl: DeviceActivationMapper.normalizePosApiBaseUrl(apiBaseUrl),
      code: normalizedCode,
      type: 'mobile',
      tenantSchema: DeviceActivationMapper.normalizeTenantSchema(tenantSchema),
    );
    return _activatePayload(payload);
  }

  Future<DeviceActivationResult> activateFromQrText(String qrText) async {
    final payload = DeviceActivationMapper.parseQrText(qrText);
    if (!payload.isMobile) {
      throw ApiException(message: 'Le type d\'activation doit être "mobile".');
    }
    return _activatePayload(payload);
  }

  /// GET a full activation URL from the QR (mock / dashboard deep link).
  ///
  /// If the GET body is a QR payload (`code`, `api_base_url`, …), chains
  /// `POST /api/devices/activate` on that host. Otherwise expects a full
  /// activate envelope with `device_token`.
  Future<DeviceActivationResult> activateFromAbsoluteUrl(
    String url, {
    String? fallbackTenantSchema,
    String? fallbackApiBaseUrl,
  }) async {
    final raw = await _remote.fetchJsonFromAbsoluteUrl(url);

    final qrPayload =
        DeviceActivationMapper.tryActivationQrPayloadFromResponse(raw);
    if (qrPayload != null) {
      logDeviceActivation(
        phase: 'ACTIVATE_URL_QR_PAYLOAD',
        posUrl: qrPayload.apiBaseUrl,
        qrPayload: {
          'code': qrPayload.code,
          'type': qrPayload.type,
          'tenant_schema': qrPayload.tenantSchema,
          'api_base_url': qrPayload.apiBaseUrl,
          'next': 'POST /api/devices/activate',
        },
      );
      return _activatePayload(qrPayload);
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
      final result = DeviceActivationMapper.activationFromJson(
        Map<String, dynamic>.from(envelope.data as Map),
        message: envelope.message,
        fallbackTenantSchema: fallbackTenantSchema,
        fallbackApiBaseUrl: fallbackApiBaseUrl,
      );
      return _persistActivationResult(
        result: result,
        contactedApiBaseUrl: result.apiBaseUrl,
      );
    } on FormatException catch (e) {
      throw ApiException(
        message: e.message,
        statusCode: envelope.status,
        responseBody: raw,
      );
    }
  }

  Future<DeviceActivationResult> _activatePayload(
    ActivationQrPayload payload,
  ) async {
    // Contact the POS using the real LAN IP from the QR / typed address.
    final contactedApiBaseUrl =
        DeviceActivationMapper.normalizePosApiBaseUrl(payload.apiBaseUrl);
    final origin = ApiConfig.normalizeOriginBaseUrl(contactedApiBaseUrl);
    final fingerprint = await _stableFingerprint();

    final result = await _remote.activate(
      code: payload.code,
      tenantSchema: payload.tenantSchema,
      originBaseUrl: origin,
      appVersion: appVersion,
      fingerprint: fingerprint,
      metadata: {
        'platform': defaultTargetPlatform.name,
        'app': 'jtr_system',
      },
    );

    return _persistActivationResult(
      result: result,
      contactedApiBaseUrl: contactedApiBaseUrl,
    );
  }

  Future<DeviceActivationResult> _persistActivationResult({
    required DeviceActivationResult result,
    required String contactedApiBaseUrl,
  }) async {
    // Never persist 127.0.0.1 / localhost from the activate response — keep the
    // LAN IP that successfully reached the Windows POS when available.
    final storedApiBaseUrl =
        DeviceActivationMapper.resolveStoredPosApiBaseUrl(
      contactedApiBaseUrl: contactedApiBaseUrl,
      responseApiBaseUrl: result.apiBaseUrl,
    );

    logDeviceActivation(
      phase: 'STORE_RUNTIME',
      posUrl: storedApiBaseUrl,
      response: {
        'contacted_api_base_url': contactedApiBaseUrl,
        'response_api_base_url': result.apiBaseUrl,
        'stored_api_base_url': storedApiBaseUrl,
        'device_id': result.deviceId,
        'tenant_schema': result.tenantSchema,
      },
    );

    final credentials = DeviceCredentials(
      deviceId: result.deviceId,
      deviceToken: result.deviceToken,
      tenantSchema: result.tenantSchema,
      apiBaseUrl: storedApiBaseUrl,
      deviceUuid: result.deviceUuid,
      label: result.label,
    );
    await _secureStorage.saveCredentials(credentials);

    ApiConfig.applyRuntime(
      baseUrl: credentials.apiBaseUrl,
      tenantSchema: credentials.tenantSchema,
      deviceId: credentials.deviceId,
      deviceToken: credentials.deviceToken,
    );
    _apiClient.applyRuntimeConfig();

    return DeviceActivationResult(
      deviceId: result.deviceId,
      deviceToken: result.deviceToken,
      tenantSchema: result.tenantSchema,
      apiBaseUrl: storedApiBaseUrl,
      deviceUuid: result.deviceUuid,
      label: result.label,
      companyCode: result.companyCode,
      bootstrap: result.bootstrap,
      message: result.message,
    );
  }

  Future<void> clearDeviceCredentials() async {
    await _secureStorage.clearCredentials();
    ApiConfig.clearDeviceCredentials();
    ApiConfig.resetToDefaults();
    _apiClient.applyRuntimeConfig();
    _apiClient.setAuthToken(null);
  }

  /// Decodes a QR PNG/JPEG from bytes (dashboard export).
  String decodeQrImageBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw ApiException(message: 'Impossible de lire l\'image QR.');
    }

    final luminance = RGBLuminanceSource(
      decoded.width,
      decoded.height,
      Int32List.fromList(
        [
          for (final pixel in decoded)
            (255 << 24) |
                (pixel.r.toInt() << 16) |
                (pixel.g.toInt() << 8) |
                pixel.b.toInt(),
        ],
      ),
    );
    final bitmap = BinaryBitmap(HybridBinarizer(luminance));
    try {
      final result = QRCodeReader().decode(bitmap);
      final text = result.text.trim();
      if (text.isEmpty) {
        throw ApiException(message: 'QR vide.');
      }
      return text;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Aucun QR valide détecté dans l\'image.',
      );
    }
  }

  Future<String> decodeQrImageFile(File file) async {
    final bytes = await file.readAsBytes();
    return decodeQrImageBytes(bytes);
  }

  Future<String> _stableFingerprint() async {
    final existing = await _secureStorage.readFingerprint();
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final fp = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _secureStorage.saveFingerprint(fp);
    return fp;
  }
}
