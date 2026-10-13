import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// OS installation id + soft device signals for activate / anti-clone binding.
///
/// - Android: [Settings.Secure.ANDROID_ID]
/// - iOS: [identifierForVendor]
class DeviceInstanceIdentity {
  const DeviceInstanceIdentity({
    required this.platform,
    required this.deviceInstanceId,
    this.model,
    this.osVersion,
  });

  /// Top-level activate field: `ios` | `android` | `other`.
  final String platform;

  /// Top-level `device_instance_id`.
  final String deviceInstanceId;

  final String? model;
  final String? osVersion;

  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  static DeviceInstanceIdentity? _cached;

  /// Cached per process so the fallback id stays stable between activate,
  /// session and later API calls.
  static Future<DeviceInstanceIdentity> resolve() async {
    return _cached ??= await _resolveUncached();
  }

  static Future<DeviceInstanceIdentity> _resolveUncached() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        final id = info.id.trim();
        return DeviceInstanceIdentity(
          platform: 'android',
          deviceInstanceId: id.isNotEmpty ? id : _fallbackId(),
          model: _nonEmpty(info.model) ?? _nonEmpty(info.device),
          osVersion: _nonEmpty(info.version.release),
        );
      }
      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        final id = (info.identifierForVendor ?? '').trim();
        return DeviceInstanceIdentity(
          platform: 'ios',
          deviceInstanceId: id.isNotEmpty ? id : _fallbackId(),
          model: _nonEmpty(info.utsname.machine) ?? _nonEmpty(info.model),
          osVersion: _nonEmpty(info.systemVersion),
        );
      }
    } catch (_) {
      // Fall through to generic identity.
    }

    return DeviceInstanceIdentity(
      platform: _platformLabel(),
      deviceInstanceId: _fallbackId(),
    );
  }

  static String _platformLabel() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'other';
    }
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String _fallbackId() =>
      'unknown-${DateTime.now().millisecondsSinceEpoch}';
}
