import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/config/api_config.dart';
import '../core/network/api_exception.dart';
import '../data/mappers/device_activation_mapper.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/session_repository.dart';
import '../pages/device_qr_scan_page.dart';
import '../routes/app_pages.dart';
import '../utils/api_log.dart';

/// Activates this mobile device against a local Windows POS (cashier) machine.
///
/// QR / activation code from the Admin Dashboard includes the POS LAN IP
/// (`api_base_url`). After success, all API calls go to that IP with device
/// headers — there is no central production server.
class DeviceActivationController extends GetxController {
  DeviceActivationController({
    required DeviceRepository deviceRepository,
    required AuthRepository authRepository,
  })  : _deviceRepository = deviceRepository,
        _authRepository = authRepository;

  final DeviceRepository _deviceRepository;
  final AuthRepository _authRepository;

  final codeController = TextEditingController();
  final tenantController = TextEditingController();

  /// POS URL from QR only (not shown as an input field).
  String? _posApiBaseUrlFromQr;

  final isSubmitting = false.obs;
  final isImportingQr = false.obs;
  final isScanningQr = false.obs;
  final errorMessage = RxnString();

  /// Last POS URL taken from QR (shown as read-only hint + logged).
  final resolvedPosUrl = RxnString();

  @override
  void onClose() {
    codeController.dispose();
    tenantController.dispose();
    super.onClose();
  }

  /// Live camera scan of the dashboard QR.
  Future<void> scanQrWithCamera() async {
    if (isSubmitting.value || isImportingQr.value || isScanningQr.value) {
      return;
    }
    errorMessage.value = null;
    isScanningQr.value = true;
    try {
      final raw = await Get.to<String>(() => const DeviceQrScanPage());
      if (raw == null || raw.trim().isEmpty) return;
      try {
        await applyQrText(raw);
      } on ApiException catch (e) {
        logDeviceActivation(phase: 'QR_SCAN_ERROR', error: e.message);
        errorMessage.value = e.message;
      } on FormatException catch (e) {
        logDeviceActivation(phase: 'QR_SCAN_ERROR', error: e.message);
        errorMessage.value = e.message;
      }
    } catch (e) {
      logDeviceActivation(phase: 'QR_SCAN_ERROR', error: e.toString());
      errorMessage.value =
          'Impossible d\'ouvrir la caméra. Vérifiez l\'autorisation caméra.';
    } finally {
      isScanningQr.value = false;
    }
  }

  Future<void> importQrPng() async {
    errorMessage.value = null;
    isImportingQr.value = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      late final String qrText;
      if (bytes != null && bytes.isNotEmpty) {
        qrText = _deviceRepository.decodeQrImageBytes(bytes);
      } else if (file.path != null) {
        qrText = await _deviceRepository.decodeQrImageFile(File(file.path!));
      } else {
        throw ApiException(message: 'Fichier QR inaccessible.');
      }

      await applyQrText(qrText);
    } on ApiException catch (e) {
      logDeviceActivation(phase: 'QR_ERROR', error: e.message);
      errorMessage.value = e.message;
    } on FormatException catch (e) {
      logDeviceActivation(phase: 'QR_ERROR', error: e.message);
      errorMessage.value = e.message;
    } catch (e) {
      logDeviceActivation(phase: 'QR_ERROR', error: e.toString());
      errorMessage.value = 'Impossible d\'importer le QR.';
    } finally {
      isImportingQr.value = false;
    }
  }

  /// Shared path for camera scan + PNG import.
  Future<void> applyQrText(String qrText) async {
    logDeviceActivation(
      phase: 'QR_RAW',
      qrPayload: {'raw': qrText},
    );

    // QR is a full activation URL (e.g. mocki.io) → GET it and log RESPONSE.
    final activationUrl = DeviceActivationMapper.activationUrlFromQrText(qrText);
    if (activationUrl != null) {
      await _activateFromQrUrl(activationUrl);
      return;
    }

    final payload = DeviceActivationMapper.parseQrText(qrText);
    final posUrl =
        DeviceActivationMapper.normalizePosApiBaseUrl(payload.apiBaseUrl);

    logDeviceActivation(
      phase: 'QR_PARSED',
      posUrl: posUrl,
      qrPayload: {
        'code': payload.code,
        'type': payload.type,
        'tenant_schema': payload.tenantSchema,
        'api_base_url': payload.apiBaseUrl,
        'v': payload.version,
      },
    );

    if (DeviceActivationMapper.isUnreachableFromMobileHost(posUrl)) {
      errorMessage.value =
          'Le QR contient 127.0.0.1 / localhost. '
          'Régénérez le QR depuis le dashboard avec l\'IP LAN du poste.';
      return;
    }

    codeController.text = payload.code;
    tenantController.text = payload.tenantSchema;
    _posApiBaseUrlFromQr = posUrl;
    resolvedPosUrl.value = posUrl;
    errorMessage.value = null;

    // Point Dio at the QR POS URL immediately (before activate completes).
    ApiConfig.applyRuntime(
      baseUrl: posUrl,
      tenantSchema: payload.tenantSchema,
    );
    _deviceRepository.applyRuntimeConfigOnly();

    // After a successful scan/import, activate immediately so the console
    // shows POST /api/devices/activate + request/response.
    await activate();
  }

  Future<void> _activateFromQrUrl(String url) async {
    errorMessage.value = null;
    resolvedPosUrl.value = url;
    logDeviceActivation(
      phase: 'ACTIVATE_URL_START',
      posUrl: url,
      request: {'method': 'GET', 'url': url},
    );

    isSubmitting.value = true;
    try {
      final result = await _deviceRepository.activateFromAbsoluteUrl(url);
      tenantController.text = result.tenantSchema;
      _posApiBaseUrlFromQr = result.apiBaseUrl;
      resolvedPosUrl.value = result.apiBaseUrl;

      logDeviceActivation(
        phase: 'ACTIVATE_URL_OK',
        posUrl: result.apiBaseUrl,
        response: {
          'device_id': result.deviceId,
          'tenant_schema': result.tenantSchema,
          'api_base_url': result.apiBaseUrl,
          'label': result.label,
          'device_uuid': result.deviceUuid,
          'company_code': result.companyCode,
          'runtime_baseUrl': ApiConfig.baseUrl,
        },
      );
      await _goToLoginRequiringAuth();
    } on ApiException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_URL_ERROR',
        posUrl: url,
        response: e.responseBody,
        error: e.message,
      );
      errorMessage.value = e.message;
    } on FormatException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_URL_ERROR',
        posUrl: url,
        error: e.message,
      );
      errorMessage.value = e.message;
    } catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_URL_ERROR',
        posUrl: url,
        error: e.toString(),
      );
      errorMessage.value =
          'Impossible d\'appeler l\'URL du QR. Vérifiez le réseau.';
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> activate() async {
    errorMessage.value = null;

    final code = DeviceActivationMapper.normalizeCode(codeController.text);
    final tenant =
        DeviceActivationMapper.normalizeTenantSchema(tenantController.text);
    final posServer = (_posApiBaseUrlFromQr ?? resolvedPosUrl.value ?? '').trim();

    if (code.length < 8) {
      errorMessage.value = 'Saisissez un code d\'activation valide.';
      return;
    }
    if (tenant.isEmpty) {
      errorMessage.value = 'Saisissez le schéma restaurant.';
      return;
    }
    if (posServer.isEmpty) {
      errorMessage.value =
          'Scannez ou importez le QR pour récupérer l\'adresse du poste.';
      return;
    }

    late final String apiBaseUrl;
    try {
      apiBaseUrl = DeviceActivationMapper.normalizePosApiBaseUrl(posServer);
      if (DeviceActivationMapper.isUnreachableFromMobileHost(apiBaseUrl)) {
        errorMessage.value =
            'Le QR contient 127.0.0.1 / localhost. '
            'Régénérez le QR avec l\'IP LAN du poste.';
        return;
      }
    } on FormatException catch (e) {
      errorMessage.value = e.message;
      return;
    }

    resolvedPosUrl.value = apiBaseUrl;
    _posApiBaseUrlFromQr = apiBaseUrl;
    logDeviceActivation(
      phase: 'ACTIVATE_START',
      posUrl: apiBaseUrl,
      request: {
        'code': code,
        'tenant_schema': tenant,
        'api_base_url': apiBaseUrl,
        'dio_baseUrl_will_be': ApiConfig.normalizeOriginBaseUrl(apiBaseUrl),
      },
    );

    // Use QR POS URL dynamically for the activate call.
    ApiConfig.applyRuntime(baseUrl: apiBaseUrl, tenantSchema: tenant);
    _deviceRepository.applyRuntimeConfigOnly();

    isSubmitting.value = true;
    try {
      final result = await _deviceRepository.activateWithCode(
        code: code,
        tenantSchema: tenant,
        apiBaseUrl: apiBaseUrl,
      );
      logDeviceActivation(
        phase: 'ACTIVATE_OK',
        posUrl: result.apiBaseUrl,
        response: {
          'device_id': result.deviceId,
          'tenant_schema': result.tenantSchema,
          'api_base_url': result.apiBaseUrl,
          'label': result.label,
          'device_uuid': result.deviceUuid,
          'runtime_baseUrl': ApiConfig.baseUrl,
        },
      );
      resolvedPosUrl.value = result.apiBaseUrl;
      _posApiBaseUrlFromQr = result.apiBaseUrl;
      await _goToLoginRequiringAuth();
    } on ApiException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_ERROR',
        posUrl: apiBaseUrl,
        response: e.responseBody,
        error: e.message,
      );
      errorMessage.value = e.message;
    } on FormatException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_ERROR',
        posUrl: apiBaseUrl,
        error: e.message,
      );
      errorMessage.value = e.message;
    } catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_ERROR',
        posUrl: apiBaseUrl,
        error: e.toString(),
      );
      errorMessage.value =
          'Activation impossible. Vérifiez que le téléphone est sur '
          'le même réseau que le poste Windows.';
    } finally {
      isSubmitting.value = false;
    }
  }

  /// After device activation, never skip login because of a restored Hive token
  /// (Android backup / reinstall often keeps the previous auth session).
  Future<void> _goToLoginRequiringAuth() async {
    await _authRepository.logout();
    if (Get.isRegistered<SessionRepository>()) {
      await Get.find<SessionRepository>().clearOpenOrdersCache();
    }
    Get.offAllNamed(AppRoutes.login);
  }
}
