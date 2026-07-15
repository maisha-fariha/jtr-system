/// Runtime API configuration. Defaults are used before device activation;
/// after activate / restore they are overridden from secure storage.
class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl = 'https://api.goatech.ma';
  static const String defaultTenantSchema = 'mocca';

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
