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

  /// Origin (scheme + host + port) used to compare contacted vs activate response.
  static Uri activationOriginFromApiBase(String apiBaseUrl) {
    final uri = Uri.parse(normalizePosApiBaseUrl(apiBaseUrl));
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort
          ? uri.port
          : (uri.scheme.toLowerCase() == 'https' ? 443 : 80),
    );
  }

  static bool activationOriginsMatch(
    String contactedApiBaseUrl,
    String responseApiBaseUrl,
  ) {
    final contacted = activationOriginFromApiBase(contactedApiBaseUrl);
    final response = activationOriginFromApiBase(responseApiBaseUrl);
    return contacted.scheme == response.scheme &&
        contacted.host == response.host &&
        contacted.port == response.port;
  }

  static String activationOriginMismatchMessage({
    required String contactedApiBaseUrl,
    required String responseApiBaseUrl,
  }) {
    final contacted = activationOriginFromApiBase(contactedApiBaseUrl);
    final response = activationOriginFromApiBase(responseApiBaseUrl);
    if (contacted.port != response.port) {
      final defaultPort = contacted.scheme == 'https' ? 443 : 80;
      if (contacted.port != defaultPort && response.port == defaultPort) {
        return 'Le port :${contacted.port} est requis dans l\'URL du poste '
            '(ex. ${contacted.host}:${contacted.port}). '
            'Le serveur a répondu sans ce port — la connexion échouerait au login.';
      }
      if (response.port != defaultPort && contacted.port == defaultPort) {
        return 'Port manquant : le poste écoute sur :${response.port}. '
            'Saisissez ${response.host}:${response.port} dans l\'URL / IP.';
      }
      return 'Port incompatible (saisi :${contacted.port}, '
          'serveur :${response.port}). Corrigez l\'URL / IP du poste.';
    }
    return 'L\'URL du poste ne correspond pas à celle renvoyée par le serveur.';
  }

  /// Prefer the LAN IP the phone used to reach the POS (from QR / typed IP).
  ///
  /// Activate responses often echo `http://127.0.0.1/api` because the Windows
  /// service binds locally — that must not overwrite the real POS LAN address.
  ///
  /// Throws [FormatException] when response origin (host/port) differs from
  /// [contactedApiBaseUrl] so login uses the same URL as activation.
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

    if (!activationOriginsMatch(contacted, response)) {
      throw FormatException(
        activationOriginMismatchMessage(
          contactedApiBaseUrl: contacted,
          responseApiBaseUrl: response,
        ),
      );
    }

    // Always persist the URL the phone actually used (same host/port for login).
    return contacted;
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

  /// JSON or `jtrpos://` QR — always POST activate on [api_base_url].
  static bool isStructuredActivationQr(String raw) {
    final text = raw.trim();
    if (text.startsWith('\uFEFF')) {
      return isStructuredActivationQr(text.substring(1));
    }
    if (text.startsWith('{')) return true;
    return isActivationDeepLink(text);
  }

  /// True when [raw] looks like a POS deep-link QR (`jtrpos://activate?...`).
  static bool isActivationDeepLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.isEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'jtrpos' || scheme == 'jtr';
  }

  /// Parses `jtrpos://activate?code=...&tenant_schema=...&api_base_url=...`.
  static ActivationQrPayload? tryParseActivationDeepLink(String raw) {
    final text = raw.trim();
    if (!isActivationDeepLink(text)) return null;

    final uri = Uri.tryParse(text);
    if (uri == null) return null;

    final q = uri.queryParameters;
    if (q.isEmpty) {
      throw const FormatException(
        'QR jtrpos incomplet (paramètres manquants).',
      );
    }

    return payloadFromActivationFields(
      <String, dynamic>{
        for (final e in q.entries) e.key: e.value,
      },
    );
  }

  /// Shared field extraction for JSON QR and `jtrpos://` deep-link QR.
  static ActivationQrPayload payloadFromActivationFields(
    Map<String, dynamic> map,
  ) {
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
  /// is not available. Full JSON / `jtrpos://` payloads always use POST instead.
  static String? activationUrlFromQrText(String raw) {
    final text = raw.trim();
    if (text.startsWith('\uFEFF')) {
      return activationUrlFromQrText(text.substring(1));
    }
    if (isStructuredActivationQr(text)) return null;
    if (isAbsoluteHttpUrl(text) && !isPosBaseOnlyUrl(text)) {
      return text;
    }
    if (!text.startsWith('{')) return null;

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      // Full activation JSON → POST on api_base_url, not GET.
      try {
        payloadFromActivationFields(map);
        return null;
      } catch (_) {
        // Partial JSON may still carry a mock activation_url.
      }
      const keys = <String>[
        'activation_url',
        'activate_url',
        'url',
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

  /// QR is only a POS base URL / IP — combine with typed or bypass fields.
  static ActivationQrPayload? tryParsePosBaseQrWithFallbacks(
    String raw, {
    required String fallbackCode,
    required String fallbackTenantSchema,
  }) {
    final text = raw.trim();
    if (!isPosBaseOnlyUrl(text)) return null;

    final code = normalizeCode(fallbackCode);
    final tenant = normalizeTenantSchema(fallbackTenantSchema);
    if (code.length < 8 || tenant.isEmpty) return null;

    return ActivationQrPayload(
      version: 1,
      apiBaseUrl: normalizePosApiBaseUrl(text),
      code: code,
      type: 'mobile',
      tenantSchema: tenant,
    );
  }

  /// GET mock URL may return a QR payload (step 1) instead of device_token.
  static ActivationQrPayload? tryActivationQrPayloadFromResponse(
    Map<String, dynamic> raw,
  ) {
    if (_responseHasDeviceToken(raw)) return null;

    final data = raw['data'];
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      if (_responseHasDeviceToken(dataMap)) return null;
      try {
        return payloadFromActivationFields(dataMap);
      } catch (_) {}
    }

    try {
      return payloadFromActivationFields(raw);
    } catch (_) {
      return null;
    }
  }

  static bool _responseHasDeviceToken(Map<String, dynamic> map) {
    return map['device_token']?.toString().trim().isNotEmpty == true;
  }

  /// Parses QR text. Accepts:
  /// - JSON payload `{ "code", "tenant_schema", "api_base_url", "type": "mobile" }`
  /// - Deep link `jtrpos://activate?code=...&tenant_schema=...&api_base_url=...`
  /// - Plain activation code (with fallback POS URL + tenant)
  static ActivationQrPayload parseQrText(
    String raw, {
    String? fallbackApiBaseUrl,
    String? fallbackTenantSchema,
  }) {
    var text = raw.trim();
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1).trim();
    }

    // POS machine deep-link QR (same fields as JSON, query-encoded).
    final deepLink = tryParseActivationDeepLink(text);
    if (deepLink != null) return deepLink;

    if (text.startsWith('{')) {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const FormatException('QR JSON invalide.');
      }
      return payloadFromActivationFields(
        Map<String, dynamic>.from(decoded),
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

  static String _fieldOrFallback(String? fromResponse, String? fallback) {
    final response = fromResponse?.trim() ?? '';
    if (response.isNotEmpty) return response;
    return fallback?.trim() ?? '';
  }

  static DeviceActivationResult activationFromJson(
    Map<String, dynamic> data, {
    String? message,
    String? fallbackTenantSchema,
    String? fallbackApiBaseUrl,
  }) {
    final deviceId = data['device_id'];
    final token = data['device_token']?.toString() ?? '';
    final tenant = _fieldOrFallback(
      data['tenant_schema']?.toString(),
      fallbackTenantSchema,
    );
    final apiRaw = _fieldOrFallback(
      data['api_base_url']?.toString(),
      fallbackApiBaseUrl,
    );
    if (token.isEmpty || tenant.isEmpty || apiRaw.isEmpty) {
      throw const FormatException(
        'Réponse d\'activation incomplète '
        '(device_token, tenant_schema et api_base_url requis).',
      );
    }

    return DeviceActivationResult(
      deviceId: deviceId is num
          ? '${deviceId.toInt()}'
          : deviceId?.toString() ?? '',
      deviceToken: token,
      tenantSchema: normalizeTenantSchema(tenant),
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
