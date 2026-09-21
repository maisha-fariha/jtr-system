import '../../core/storage/device_secure_storage.dart';

/// One POS / restaurant binding saved for JTR Rapport multi-tenant access.
class RapportSavedRestaurant {
  const RapportSavedRestaurant({
    required this.id,
    required this.displayName,
    required this.tenantSchema,
    required this.apiBaseUrl,
    required this.deviceId,
    required this.deviceToken,
    this.deviceUuid,
    this.label,
  });

  /// Stable key: `normalizedOrigin|tenant`.
  final String id;
  final String displayName;
  final String tenantSchema;
  final String apiBaseUrl;
  final String deviceId;
  final String deviceToken;
  final String? deviceUuid;
  final String? label;

  DeviceCredentials toCredentials() => DeviceCredentials(
        deviceId: deviceId,
        deviceToken: deviceToken,
        tenantSchema: tenantSchema,
        apiBaseUrl: apiBaseUrl,
        deviceUuid: deviceUuid,
        label: label ?? displayName,
      );

  factory RapportSavedRestaurant.fromCredentials(DeviceCredentials creds) {
    final origin = _normalizeOrigin(creds.apiBaseUrl);
    final tenant = creds.tenantSchema.trim();
    final label = creds.label?.trim();
    final display = (label != null && label.isNotEmpty)
        ? label
        : (tenant.isNotEmpty ? tenant : origin);
    return RapportSavedRestaurant(
      id: '$origin|$tenant',
      displayName: display,
      tenantSchema: tenant,
      apiBaseUrl: origin,
      deviceId: creds.deviceId,
      deviceToken: creds.deviceToken,
      deviceUuid: creds.deviceUuid,
      label: label,
    );
  }

  factory RapportSavedRestaurant.fromJson(Map<String, dynamic> json) {
    return RapportSavedRestaurant(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ??
          json['label']?.toString() ??
          json['tenant_schema']?.toString() ??
          'Restaurant',
      tenantSchema: json['tenant_schema']?.toString() ?? '',
      apiBaseUrl: json['api_base_url']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      deviceToken: json['device_token']?.toString() ?? '',
      deviceUuid: json['device_uuid']?.toString(),
      label: json['label']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'tenant_schema': tenantSchema,
        'api_base_url': apiBaseUrl,
        'device_id': deviceId,
        'device_token': deviceToken,
        if (deviceUuid != null) 'device_uuid': deviceUuid,
        if (label != null) 'label': label,
      };

  static String _normalizeOrigin(String raw) {
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
