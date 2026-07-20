import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/config/api_config.dart';
import '../core/config/device_activation_bypass.dart';
import '../core/network/api_exception.dart';
import '../data/mappers/device_activation_mapper.dart';
import '../data/models/device_activation_models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/session_repository.dart';
import '../pages/device_qr_scan_page.dart';
import '../routes/app_pages.dart';
import '../utils/api_log.dart';

/// Activates this mobile device against the configured API host.
///
/// Production / LAN: QR or manual code + POS IP. Test: [DeviceActivationBypass]
/// against https://api.goatech.ma with code `JTR-BYPASS`.
class DeviceActivationController extends GetxController {
  DeviceActivationController({
    required DeviceRepository deviceRepository,
    required AuthRepository authRepository,
  })  : _deviceRepository = deviceRepository,
        _authRepository = authRepository;

  final DeviceRepository _deviceRepository;
  final AuthRepository _authRepository;

  /// Prefill at construction so the first frame already shows bypass values.
  late final codeController = TextEditingController(
    text: DeviceActivationBypass.enabled
        ? DeviceActivationBypass.activationCode
        : '',
  );
  late final tenantController = TextEditingController(
    text: DeviceActivationBypass.enabled
        ? DeviceActivationBypass.tenantSchema
        : '',
  );
  late final apiBaseUrlController = TextEditingController(
    text: DeviceActivationBypass.enabled
        ? DeviceActivationBypass.apiBaseUrl
        : '',
  );

  final isSubmitting = false.obs;
  final isImportingQr = false.obs;
  final isScanningQr = false.obs;

  /// True after a successful camera/PNG QR parse (unlocks runtime API from QR).
  final qrApplied = false.obs;

  /// User-facing text from API `message` (or local validation).
  final feedbackMessage = RxnString();
  final feedbackIsError = false.obs;

  /// Bypass keeps a static API until the user scans/imports a QR.
  bool get usesStaticBypassApi =>
      DeviceActivationBypass.enabled && !qrApplied.value;

  /// Display-only host for bypass (never append `/api` in the input).
  String get bypassDisplayApiUrl => DeviceActivationBypass.apiBaseUrl;

  void _pinBypassDisplayUrl() {
    if (!usesStaticBypassApi) return;
    apiBaseUrlController.text = DeviceActivationBypass.apiBaseUrl;
  }

  @override
  void onClose() {
    codeController.dispose();
    tenantController.dispose();
    apiBaseUrlController.dispose();
    super.onClose();
  }

  void _clearFeedback() {
    feedbackMessage.value = null;
    feedbackIsError.value = false;
  }

  void _showError(String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    feedbackIsError.value = true;
    feedbackMessage.value = text;
  }

  void _showSuccess(String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    feedbackIsError.value = false;
    feedbackMessage.value = text;
  }

  String _apiMessage(ApiException e) {
    final fromBody = _messageFromBody(e.responseBody);
    if (fromBody != null) return fromBody;
    return e.message.trim().isNotEmpty
        ? e.message.trim()
        : 'Activation impossible.';
  }

  String? _messageFromBody(Object? body) {
    if (body is Map) {
      final message = body['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  /// Live camera scan of the dashboard QR.
  Future<void> scanQrWithCamera() async {
    if (isSubmitting.value || isImportingQr.value || isScanningQr.value) {
      return;
    }
    _clearFeedback();
    isScanningQr.value = true;
    try {
      final raw = await Get.to<String>(() => const DeviceQrScanPage());
      // Stop scan spinner before activate so only one loader is shown.
      isScanningQr.value = false;
      if (raw == null || raw.trim().isEmpty) return;
      try {
        await applyQrText(raw);
      } on ApiException catch (e) {
        logDeviceActivation(phase: 'QR_SCAN_ERROR', error: e.message);
        _showError(_apiMessage(e));
      } on FormatException catch (e) {
        logDeviceActivation(phase: 'QR_SCAN_ERROR', error: e.message);
        _showError(e.message);
      }
    } catch (e) {
      logDeviceActivation(phase: 'QR_SCAN_ERROR', error: e.toString());
      _showError(
        'Impossible d\'ouvrir la caméra. Vérifiez l\'autorisation caméra.',
      );
    } finally {
      isScanningQr.value = false;
    }
  }

  Future<void> importQrPng() async {
    _clearFeedback();
    if (isSubmitting.value || isScanningQr.value || isImportingQr.value) {
      return;
    }
    isImportingQr.value = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      // Stop import spinner before activate so only one loader is shown.
      isImportingQr.value = false;
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
      _showError(_apiMessage(e));
    } on FormatException catch (e) {
      logDeviceActivation(phase: 'QR_ERROR', error: e.message);
      _showError(e.message);
    } catch (e) {
      logDeviceActivation(phase: 'QR_ERROR', error: e.toString());
      _showError('Impossible d\'importer le QR.');
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

    // 1) Full JSON / jtrpos deep-link → POST on scanned api_base_url.
    if (DeviceActivationMapper.isStructuredActivationQr(qrText)) {
      await _activateFromParsedQr(qrText, format: 'structured');
      return;
    }

    // 2) QR is only POS IP / api base → POST using code + tenant from the form.
    final posBaseOnly = DeviceActivationMapper.tryParsePosBaseQrWithFallbacks(
      qrText,
      fallbackCode: codeController.text,
      fallbackTenantSchema: tenantController.text,
    );
    if (posBaseOnly != null) {
      await _activateFromPayload(posBaseOnly, format: 'pos_base_url');
      return;
    }

    // 3) Mock / dashboard GET URL (e.g. mocki.io).
    final activationUrl = DeviceActivationMapper.activationUrlFromQrText(qrText);
    if (activationUrl != null) {
      logDeviceActivation(
        phase: 'QR_ROUTE',
        posUrl: activationUrl,
        request: {'method': 'GET', 'reason': 'mock_activation_url'},
      );
      await _activateFromQrUrl(activationUrl);
      return;
    }

    // 4) Plain activation code in QR — needs POS URL + tenant on the form.
    await _activateFromParsedQr(
      qrText,
      format: 'plain_code',
      fallbackApiBaseUrl: apiBaseUrlController.text,
      fallbackTenantSchema: tenantController.text,
    );
  }

  Future<void> _activateFromParsedQr(
    String qrText, {
    required String format,
    String? fallbackApiBaseUrl,
    String? fallbackTenantSchema,
  }) async {
    final payload = DeviceActivationMapper.parseQrText(
      qrText,
      fallbackApiBaseUrl: fallbackApiBaseUrl,
      fallbackTenantSchema: fallbackTenantSchema,
    );
    await _activateFromPayload(payload, format: format);
  }

  Future<void> _activateFromPayload(
    ActivationQrPayload payload, {
    required String format,
  }) async {
    final posUrl =
        DeviceActivationMapper.normalizePosApiBaseUrl(payload.apiBaseUrl);

    logDeviceActivation(
      phase: 'QR_PARSED',
      posUrl: posUrl,
      qrPayload: {
        'format': format,
        'route': 'POST /api/devices/activate',
        'code': payload.code,
        'type': payload.type,
        'tenant_schema': payload.tenantSchema,
        'api_base_url': payload.apiBaseUrl,
        'dio_origin': ApiConfig.normalizeOriginBaseUrl(posUrl),
        'v': payload.version,
      },
    );

    if (DeviceActivationMapper.isUnreachableFromMobileHost(posUrl)) {
      logDeviceActivation(
        phase: 'QR_SKIPPED',
        posUrl: posUrl,
        error:
            'QR api_base_url is localhost/127.0.0.1 — regenerate with LAN IP.',
      );
      _showError(
        'Le QR contient 127.0.0.1 / localhost. '
        'Régénérez le QR depuis le dashboard avec l\'IP LAN du poste.',
      );
      return;
    }

    codeController.text = payload.code;
    tenantController.text = payload.tenantSchema;
    apiBaseUrlController.text = posUrl;
    qrApplied.value = true;
    _clearFeedback();

    // Point Dio at the QR POS URL immediately (before activate completes).
    ApiConfig.applyRuntime(
      baseUrl: posUrl,
      tenantSchema: payload.tenantSchema,
    );
    _deviceRepository.applyRuntimeConfigOnly();

    logDeviceActivation(
      phase: 'QR_ROUTE',
      posUrl: posUrl,
      request: {
        'method': 'POST',
        'path': '/api/devices/activate',
        'reason': 'qr_scan',
      },
    );

    // After a successful scan/import, activate immediately so the console
    // shows POST /api/devices/activate + request/response.
    await activate();
  }

  Future<void> _activateFromQrUrl(String url) async {
    _clearFeedback();
    logDeviceActivation(
      phase: 'ACTIVATE_URL_START',
      posUrl: url,
      request: {'method': 'GET', 'url': url},
    );

    isSubmitting.value = true;
    try {
      final result = await _deviceRepository.activateFromAbsoluteUrl(
        url,
        fallbackTenantSchema: tenantController.text.trim().isNotEmpty
            ? tenantController.text
            : DeviceActivationBypass.tenantSchema,
        fallbackApiBaseUrl: apiBaseUrlController.text.trim().isNotEmpty
            ? apiBaseUrlController.text
            : null,
      );
      qrApplied.value = true;
      tenantController.text = result.tenantSchema;
      apiBaseUrlController.text = result.apiBaseUrl;

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
          'message': result.message,
        },
      );
      _showSuccess(result.message ?? 'Device activated');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _goToLoginRequiringAuth();
    } on ApiException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_URL_ERROR',
        posUrl: url,
        response: e.responseBody,
        error: e.message,
      );
      _showError(_apiMessage(e));
    } on FormatException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_URL_ERROR',
        posUrl: url,
        error: e.message,
      );
      _showError(e.message);
    } catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_URL_ERROR',
        posUrl: url,
        error: e.toString(),
      );
      _showError('Impossible d\'appeler l\'URL du QR. Vérifiez le réseau.');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> activate() async {
    _clearFeedback();

    final code = DeviceActivationMapper.normalizeCode(codeController.text);
    final tenant =
        DeviceActivationMapper.normalizeTenantSchema(tenantController.text);
    final posServer = usesStaticBypassApi
        ? DeviceActivationBypass.apiBaseUrl
        : apiBaseUrlController.text.trim();

    if (code.length < 8) {
      logDeviceActivation(
        phase: 'ACTIVATE_VALIDATION',
        error: 'code too short',
      );
      _showError(
        usesStaticBypassApi
            ? 'Utilisez le code de bypass ${DeviceActivationBypass.activationCode}.'
            : 'Saisissez un code d\'activation valide.',
      );
      return;
    }
    if (tenant.isEmpty) {
      logDeviceActivation(
        phase: 'ACTIVATE_VALIDATION',
        error: 'tenant_schema empty',
      );
      _showError(
        usesStaticBypassApi
            ? 'Saisissez le schéma restaurant (X-Tenant-Schema), '
                'pas le code de bypass.'
            : 'Saisissez le schéma restaurant.',
      );
      return;
    }
    if (posServer.isEmpty) {
      logDeviceActivation(
        phase: 'ACTIVATE_VALIDATION',
        error: 'api_base_url empty',
      );
      _showError(
        usesStaticBypassApi
            ? 'Saisissez l\'URL API (ex. ${DeviceActivationBypass.apiBaseUrl}).'
            : 'Saisissez l\'URL / IP du poste (ex. 192.168.1.10) ou scannez le QR.',
      );
      return;
    }

    late final String apiBaseUrl;
    try {
      apiBaseUrl = DeviceActivationMapper.normalizePosApiBaseUrl(posServer);
      if (DeviceActivationMapper.isUnreachableFromMobileHost(apiBaseUrl)) {
        logDeviceActivation(
          phase: 'ACTIVATE_VALIDATION',
          posUrl: apiBaseUrl,
          error: 'localhost/127.0.0.1 not reachable from phone',
        );
        _showError(
          'Utilisez l\'IP LAN du poste (ex. 192.168.x.x), pas 127.0.0.1.',
        );
        return;
      }
    } on FormatException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_VALIDATION',
        error: e.message,
      );
      _showError(e.message);
      return;
    }

    if (usesStaticBypassApi) {
      _pinBypassDisplayUrl();
    } else {
      apiBaseUrlController.text = apiBaseUrl;
    }
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

    // Use typed / QR POS URL dynamically for the activate call.
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
          'message': result.message,
        },
      );
      if (!usesStaticBypassApi) {
        apiBaseUrlController.text = result.apiBaseUrl;
      }
      _showSuccess(result.message ?? 'Device activated');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _goToLoginRequiringAuth();
    } on ApiException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_ERROR',
        posUrl: apiBaseUrl,
        response: e.responseBody,
        error: e.message,
      );
      _showError(_apiMessage(e));
    } on FormatException catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_ERROR',
        posUrl: apiBaseUrl,
        error: e.message,
      );
      _showError(e.message);
    } catch (e) {
      logDeviceActivation(
        phase: 'ACTIVATE_ERROR',
        posUrl: apiBaseUrl,
        error: e.toString(),
      );
      _showError(
        usesStaticBypassApi
            ? 'Activation impossible. Vérifiez l\'URL API, le schéma '
                'et le réseau.'
            : 'Activation impossible. Vérifiez que le téléphone est sur '
                'le même réseau que le poste Windows.',
      );
    } finally {
      _pinBypassDisplayUrl();
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
