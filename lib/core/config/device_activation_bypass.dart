/// Temporary test-server activation bypass (Goatech).
///
/// Set [enabled] to `false` before shipping production / LAN POS QR flow.
class DeviceActivationBypass {
  DeviceActivationBypass._();

  /// When true: prefill test API + bypass code, hide QR UI.
  static const bool enabled = true;

  static const String activationCode = 'JTR-BYPASS';
  static const String apiBaseUrl = 'https://api.goatech.ma/';
  static const String tenantSchema = 'mocca';

  /// Device type sent in activate body (must be mobile).
  static const String deviceType = 'mobile';
}
