/// Runtime API configuration.
///
/// Before device activation, placeholders are used. After activation against
/// the Windows POS, [applyRuntime] stores that machine's origin + device
/// headers; all subsequent API calls go to the local POS IP (not a cloud host).
class ApiConfig {
  ApiConfig._();

  /// Placeholder only — never used as production host. Activation always
  /// requires the Windows POS `api_base_url` from QR / manual IP entry.
  static const String defaultBaseUrl = 'http://127.0.0.1';
  static const String defaultTenantSchema = '';

  static String _baseUrl = defaultBaseUrl;
  static String _tenantSchema = defaultTenantSchema;
  static String? _deviceId;
  static String? _deviceToken;

  static String get baseUrl => _baseUrl;
  static String get tenantSchema => _tenantSchema;
  static String? get deviceId => _deviceId;
  static String? get deviceToken => _deviceToken;

  static const connectTimeout = Duration(seconds: 30);
  static const receiveTimeout = Duration(seconds: 30);

  /// True when [baseUrl] looks like a LAN / local POS host.
  static bool get isLocalPosBaseUrl {
    final host = Uri.tryParse(_baseUrl)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    if (host == 'localhost' || host == '127.0.0.1') return true;
    if (host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.')) {
      return true;
    }
    // Bare IPv4
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  }

  /// Applies origin base URL (without trailing `/api`) + tenant + optional device headers.
  static void applyRuntime({
    required String baseUrl,
    required String tenantSchema,
    String? deviceId,
    String? deviceToken,
  }) {
    _baseUrl = normalizeOriginBaseUrl(baseUrl);
    _tenantSchema = tenantSchema.trim();
    _deviceId = deviceId;
    _deviceToken = deviceToken;
  }

  static void clearDeviceCredentials() {
    _deviceId = null;
    _deviceToken = null;
  }

  static void resetToDefaults() {
    _baseUrl = defaultBaseUrl;
    _tenantSchema = defaultTenantSchema;
    _deviceId = null;
    _deviceToken = null;
  }

  /// QR / activate return `api_base_url` ending with `/api`. Dio uses origin
  /// while app paths already include `/api/...`.
  static String normalizeOriginBaseUrl(String raw) {
    var value = raw.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final lower = value.toLowerCase();
    if (lower.endsWith('/api')) {
      value = value.substring(0, value.length - 4);
    }
    return value;
  }
}
