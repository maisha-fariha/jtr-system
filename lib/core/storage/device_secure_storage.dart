import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure persistence for device activation secrets (never log device_token).
class DeviceSecureStorage {
  DeviceSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _keyDeviceId = 'jtr_device_id';
  static const _keyDeviceToken = 'jtr_device_token';
  static const _keyTenantSchema = 'jtr_tenant_schema';
  static const _keyApiBaseUrl = 'jtr_api_base_url';
  static const _keyDeviceUuid = 'jtr_device_uuid';
  static const _keyDeviceLabel = 'jtr_device_label';
  static const _keyFingerprint = 'jtr_device_fingerprint';

  final FlutterSecureStorage _storage;

  Future<String?> readFingerprint() => _storage.read(key: _keyFingerprint);

  Future<void> saveFingerprint(String value) =>
      _storage.write(key: _keyFingerprint, value: value);

  Future<bool> get hasCredentials async {
    final id = await _storage.read(key: _keyDeviceId);
    final token = await _storage.read(key: _keyDeviceToken);
    return id != null &&
        id.isNotEmpty &&
        token != null &&
        token.isNotEmpty;
  }

  Future<DeviceCredentials?> readCredentials() async {
    final deviceId = await _storage.read(key: _keyDeviceId);
    final deviceToken = await _storage.read(key: _keyDeviceToken);
    final tenantSchema = await _storage.read(key: _keyTenantSchema);
    final apiBaseUrl = await _storage.read(key: _keyApiBaseUrl);
    if (deviceId == null ||
        deviceId.isEmpty ||
        deviceToken == null ||
        deviceToken.isEmpty ||
        tenantSchema == null ||
        tenantSchema.isEmpty ||
        apiBaseUrl == null ||
        apiBaseUrl.isEmpty) {
      return null;
    }

    return DeviceCredentials(
      deviceId: deviceId,
      deviceToken: deviceToken,
      tenantSchema: tenantSchema,
      apiBaseUrl: apiBaseUrl,
      deviceUuid: await _storage.read(key: _keyDeviceUuid),
      label: await _storage.read(key: _keyDeviceLabel),
    );
  }

  Future<void> saveCredentials(DeviceCredentials credentials) async {
    await _storage.write(key: _keyDeviceId, value: credentials.deviceId);
    await _storage.write(key: _keyDeviceToken, value: credentials.deviceToken);
    await _storage.write(key: _keyTenantSchema, value: credentials.tenantSchema);
    await _storage.write(key: _keyApiBaseUrl, value: credentials.apiBaseUrl);
    if (credentials.deviceUuid != null && credentials.deviceUuid!.isNotEmpty) {
      await _storage.write(key: _keyDeviceUuid, value: credentials.deviceUuid);
    }
    if (credentials.label != null && credentials.label!.isNotEmpty) {
      await _storage.write(key: _keyDeviceLabel, value: credentials.label);
    }
  }

  Future<void> clearCredentials() async {
    await Future.wait([
      _storage.delete(key: _keyDeviceId),
      _storage.delete(key: _keyDeviceToken),
      _storage.delete(key: _keyTenantSchema),
      _storage.delete(key: _keyApiBaseUrl),
      _storage.delete(key: _keyDeviceUuid),
      _storage.delete(key: _keyDeviceLabel),
      // Keep fingerprint so re-activation maps to the same physical device.
    ]);
  }
}

class DeviceCredentials {
  const DeviceCredentials({
    required this.deviceId,
    required this.deviceToken,
    required this.tenantSchema,
    required this.apiBaseUrl,
    this.deviceUuid,
    this.label,
  });

  final String deviceId;
  final String deviceToken;
  final String tenantSchema;
  final String apiBaseUrl;
  final String? deviceUuid;
  final String? label;
}
