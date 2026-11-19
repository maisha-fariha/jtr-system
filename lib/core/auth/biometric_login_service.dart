import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Credentials saved after the waiter opts in to fingerprint / Face ID login.
class BiometricCredentials {
  const BiometricCredentials({required this.userId, required this.passcode});

  final String userId;
  final String passcode;
}

/// Fingerprint (or Face ID) login: unlocks credentials kept in secure storage.
class BiometricLoginService {
  BiometricLoginService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? LocalAuthentication(),
        _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _keyUserId = 'jtr_bio_user_id';
  static const _keyPasscode = 'jtr_bio_passcode';

  /// Device has biometrics enrolled and usable.
  Future<bool> get isAvailable async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> get isEnabled async {
    final id = await _storage.read(key: _keyUserId);
    final pass = await _storage.read(key: _keyPasscode);
    return id != null && id.isNotEmpty && pass != null && pass.isNotEmpty;
  }

  Future<String?> enabledUserId() => _storage.read(key: _keyUserId);

  Future<void> enable({required String userId, required String passcode}) async {
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyPasscode, value: passcode);
  }

  Future<void> disable() async {
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyPasscode);
  }

  /// Prompts the OS biometric sheet; returns saved credentials on success.
  Future<BiometricCredentials?> authenticate() async {
    final userId = await _storage.read(key: _keyUserId);
    final passcode = await _storage.read(key: _keyPasscode);
    if (userId == null || userId.isEmpty || passcode == null || passcode.isEmpty) {
      return null;
    }
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Authentifiez-vous pour vous connecter',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!ok) return null;
    } on PlatformException {
      return null;
    }
    return BiometricCredentials(userId: userId, passcode: passcode);
  }
}
