import 'dart:convert';

import '../models/device_activation_models.dart';

class DeviceActivationMapper {
  DeviceActivationMapper._();

  static String normalizeCode(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String normalizeTenantSchema(String raw) => raw.trim().toLowerCase();

  /// Parses QR text. Accepts JSON payload or plain activation code.
  static ActivationQrPayload parseQrText(
    String raw, {
    String? fallbackApiBaseUrl,
    String? fallbackTenantSchema,
  }) {
    var text = raw.trim();
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1).trim();
    }

    if (text.startsWith('{')) {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('QR JSON invalide.');
      }
      final map = Map<String, dynamic>.from(decoded);
      final type = (map['type']?.toString() ?? '').trim().toLowerCase();
      if (type.isNotEmpty && type != 'mobile') {
        throw FormatException(
          'Ce QR est de type "$type". L\'app mobile exige type "mobile".',
        );
      }

      final code = normalizeCode(map['code']?.toString() ?? '');
      final tenant = normalizeTenantSchema(
        map['tenant_schema']?.toString() ?? '',
      );
      final apiBaseUrl = (map['api_base_url']?.toString() ?? '').trim();
      if (code.isEmpty || tenant.isEmpty || apiBaseUrl.isEmpty) {
        throw const FormatException(
          'QR incomplet (code, tenant_schema, api_base_url requis).',
        );
      }

      final versionRaw = map['v'];
      final version = versionRaw is num
          ? versionRaw.toInt()
          : int.tryParse(versionRaw?.toString() ?? '') ?? 1;

      return ActivationQrPayload(
        version: version,
        apiBaseUrl: apiBaseUrl,
        code: code,
        type: type.isEmpty ? 'mobile' : type,
        tenantSchema: tenant,
      );
    }

    // Plain code only — require known base URL + tenant.
    final code = normalizeCode(text);
    if (code.length < 8) {
      throw const FormatException('Code d\'activation invalide.');
    }
    final api = (fallbackApiBaseUrl ?? '').trim();
    final tenant = normalizeTenantSchema(fallbackTenantSchema ?? '');
    if (api.isEmpty || tenant.isEmpty) {
      throw const FormatException(
        'Saisissez aussi le schéma restaurant (ou importez un QR JSON).',
      );
    }
    return ActivationQrPayload(
      version: 1,
      apiBaseUrl: api,
      code: code,
      type: 'mobile',
      tenantSchema: tenant,
    );
  }

  static DeviceSessionInfo sessionFromJson(Map<String, dynamic> data) {
    return DeviceSessionInfo(
      deviceId: (data['device_id'] as num?)?.toInt() ?? 0,
      deviceUuid: data['device_uuid']?.toString(),
      status: data['status']?.toString() ?? '',
      label: data['label']?.toString(),
    );
  }

  static DeviceActivationResult activationFromJson(Map<String, dynamic> data) {
    final deviceId = data['device_id'];
    final token = data['device_token']?.toString() ?? '';
    final tenant = data['tenant_schema']?.toString() ?? '';
    final apiBaseUrl = data['api_base_url']?.toString() ?? '';
    if (token.isEmpty || tenant.isEmpty || apiBaseUrl.isEmpty) {
      throw const FormatException('Réponse d\'activation incomplète.');
    }

    return DeviceActivationResult(
      deviceId: deviceId is num
          ? '${deviceId.toInt()}'
          : deviceId?.toString() ?? '',
      deviceToken: token,
      tenantSchema: tenant,
      apiBaseUrl: apiBaseUrl,
      deviceUuid: data['device_uuid']?.toString(),
      label: data['label']?.toString(),
      companyCode: data['company_code']?.toString(),
      bootstrap: data['bootstrap'] is Map<String, dynamic>
          ? data['bootstrap'] as Map<String, dynamic>
          : null,
    );
  }

  static DeviceGateOutcome mapSessionErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('license') ||
        lower.contains('expired') ||
        lower.contains('installation') ||
        lower.contains('licence')) {
      return DeviceGateOutcome.licenseBlocked;
    }
    if (lower.contains('deactivated') || lower.contains('désactivé')) {
      return DeviceGateOutcome.deactivated;
    }
    // revoked / invalid credentials → re-activate
    return DeviceGateOutcome.needsActivation;
  }
}
