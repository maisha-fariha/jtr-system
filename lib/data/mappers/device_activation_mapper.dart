import 'dart:convert';

import '../models/device_activation_models.dart';

class DeviceActivationMapper {
  DeviceActivationMapper._();

  static String normalizeCode(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String normalizeTenantSchema(String raw) => raw.trim().toLowerCase();

  /// Normalizes a Windows POS address from QR or manual entry to `…/api`.
  ///
  /// Accepts `http://192.168.1.10/api`, `http://192.168.1.10`, or `192.168.1.10`.
  static String normalizePosApiBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      throw const FormatException('Adresse du poste Windows requise.');
    }
    if (!value.contains('://')) {
      value = 'http://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException(
        'Adresse du poste invalide (ex. 192.168.1.10 ou http://192.168.1.10/api).',
      );
    }
    // Strip path back to origin, then append /api (QR / activate contract).
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$origin/api';
  }

  /// True when the host is only reachable on the POS itself (useless for mobile).
  static bool isUnreachableFromMobileHost(String apiBaseUrlOrOrigin) {
    final host =
        Uri.tryParse(normalizePosApiBaseUrl(apiBaseUrlOrOrigin))?.host
            .toLowerCase() ??
        '';
    return host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '0.0.0.0';
  }

  /// Prefer the LAN IP the phone used to reach the POS (from QR / typed IP).
  ///
  /// Activate responses often echo `http://127.0.0.1/api` because the Windows
  /// service binds locally — that must not overwrite the real POS LAN address.
  static String resolveStoredPosApiBaseUrl({
    required String contactedApiBaseUrl,
    required String responseApiBaseUrl,
  }) {
    final contacted = normalizePosApiBaseUrl(contactedApiBaseUrl);
    if (responseApiBaseUrl.trim().isEmpty) return contacted;

    final response = normalizePosApiBaseUrl(responseApiBaseUrl);
    if (isUnreachableFromMobileHost(response) &&
        !isUnreachableFromMobileHost(contacted)) {
      return contacted;
    }
    return response;
  }

  /// Reads POS base URL / IP from QR JSON (dashboard may use several keys).
  static String? posApiBaseUrlFromQrMap(Map<String, dynamic> map) {
    const keys = <String>[
      'api_base_url',
      'apiBaseUrl',
      'base_url',
      'baseUrl',
      'server_url',
      'pos_url',
      'ip',
      'host',
      'server_ip',
      'pos_ip',
      'lan_ip',
    ];
    for (final key in keys) {
      final raw = map[key]?.toString().trim() ?? '';
      if (raw.isEmpty) continue;
      try {
        return normalizePosApiBaseUrl(raw);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// True when [raw] is a bare http(s) URL (e.g. mock activate endpoint).
  static bool isAbsoluteHttpUrl(String raw) {
    final text = raw.trim();
    if (text.startsWith('{')) return false;
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// POS base only (`http://host` or `http://host/api`) — not a mock/deep path.
  static bool isPosBaseOnlyUrl(String raw) {
    if (!isAbsoluteHttpUrl(raw) && !raw.trim().contains('://')) {
      // Bare IP like 192.168.1.42 — treat as POS base.
      try {
        normalizePosApiBaseUrl(raw);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (!isAbsoluteHttpUrl(raw)) return false;
    final path = Uri.parse(raw.trim()).path;
    return path.isEmpty || path == '/' || RegExp(r'^/api/?$').hasMatch(path);
  }

  /// Extracts a GET activation URL from QR text (bare URL or JSON field).
  ///
  /// Used for mocks like https://mocki.io/v1/... where POST /devices/activate
  /// is not available.
  static String? activationUrlFromQrText(String raw) {
    final text = raw.trim();
    if (text.startsWith('\uFEFF')) {
      return activationUrlFromQrText(text.substring(1));
    }
    if (isAbsoluteHttpUrl(text) && !isPosBaseOnlyUrl(text)) {
      return text;
    }
    if (!text.startsWith('{')) return null;

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      const keys = <String>[
        'activation_url',
        'activate_url',
        'url',
        'api_base_url',
        'apiBaseUrl',
        'base_url',
        'baseUrl',
      ];
      for (final key in keys) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        if (isAbsoluteHttpUrl(value) && !isPosBaseOnlyUrl(value)) {
          return value;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

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
        map['tenant_schema']?.toString() ??
            map['tenantSchema']?.toString() ??
            '',
      );
      final apiBaseUrl = posApiBaseUrlFromQrMap(map);
      if (code.isEmpty || tenant.isEmpty || apiBaseUrl == null) {
        throw const FormatException(
          'QR incomplet (code, tenant_schema, api_base_url / IP requis).',
        );
      }

      final versionRaw = map['v'] ?? map['version'];
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

    // Plain code only — require known POS base URL + tenant.
    final code = normalizeCode(text);
    if (code.length < 8) {
      throw const FormatException('Code d\'activation invalide.');
    }
    final api = (fallbackApiBaseUrl ?? '').trim();
    final tenant = normalizeTenantSchema(fallbackTenantSchema ?? '');
    if (api.isEmpty || tenant.isEmpty) {
      throw const FormatException(
        'Saisissez l\'adresse du poste Windows et le schéma restaurant '
        '(ou importez un QR JSON).',
      );
    }
    return ActivationQrPayload(
      version: 1,
      apiBaseUrl: normalizePosApiBaseUrl(api),
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

  static DeviceActivationResult activationFromJson(
    Map<String, dynamic> data, {
    String? message,
  }) {
    final deviceId = data['device_id'];
    final token = data['device_token']?.toString() ?? '';
    final tenant = data['tenant_schema']?.toString() ?? '';
    final apiRaw = data['api_base_url']?.toString() ?? '';
    if (token.isEmpty || tenant.isEmpty || apiRaw.isEmpty) {
      throw FormatException(
        message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'Réponse d\'activation incomplète.',
      );
    }

    return DeviceActivationResult(
      deviceId: deviceId is num
          ? '${deviceId.toInt()}'
          : deviceId?.toString() ?? '',
      deviceToken: token,
      tenantSchema: tenant,
      apiBaseUrl: normalizePosApiBaseUrl(apiRaw),
      deviceUuid: data['device_uuid']?.toString(),
      label: data['label']?.toString(),
      companyCode: data['company_code']?.toString(),
      bootstrap: data['bootstrap'] is Map<String, dynamic>
          ? data['bootstrap'] as Map<String, dynamic>
          : null,
      message: message?.trim().isNotEmpty == true ? message!.trim() : null,
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
    // Doc: only wipe on revoke / invalid device credentials.
    if (lower.contains('revoked') ||
        lower.contains('révoqué') ||
        lower.contains('revoque') ||
        lower.contains('invalid device') ||
        lower.contains('identifiants poste') ||
        lower.contains('device credentials') ||
        lower.contains('unknown device')) {
      return DeviceGateOutcome.needsActivation;
    }
    // Network / unknown API errors: keep credentials (handled by caller).
    return DeviceGateOutcome.active;
  }
}
