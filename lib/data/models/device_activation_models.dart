class ActivationQrPayload {
  const ActivationQrPayload({
    required this.version,
    required this.apiBaseUrl,
    required this.code,
    required this.type,
    required this.tenantSchema,
  });

  final int version;
  final String apiBaseUrl;
  final String code;
  final String type;
  final String tenantSchema;

  bool get isMobile => type.toLowerCase() == 'mobile';
}

class DeviceSessionInfo {
  const DeviceSessionInfo({
    required this.deviceId,
    required this.status,
    this.deviceUuid,
    this.label,
  });

  final int deviceId;
  final String status;
  final String? deviceUuid;
  final String? label;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isDeactivated => status.toLowerCase() == 'deactivated';
}

class DeviceActivationResult {
  const DeviceActivationResult({
    required this.deviceId,
    required this.deviceToken,
    required this.tenantSchema,
    required this.apiBaseUrl,
    this.deviceUuid,
    this.label,
    this.companyCode,
    this.bootstrap,
    this.message,
  });

  final String deviceId;
  final String deviceToken;
  final String tenantSchema;
  final String apiBaseUrl;
  final String? deviceUuid;
  final String? label;
  final String? companyCode;
  final Map<String, dynamic>? bootstrap;

  /// Server envelope `message` (e.g. "Device activated").
  final String? message;
}

enum DeviceGateOutcome {
  needsActivation,
  active,
  deactivated,
  licenseBlocked,
}
