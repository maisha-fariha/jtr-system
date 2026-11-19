import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../config/api_config.dart';

/// Fingerprint (or Face ID) login. Each user (per restaurant) has their own
/// saved login in secure storage, unlocked by the phone's biometric prompt.
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

  static const _keyAccounts = 'jtr_bio_accounts';

  // Single-slot keys from the first version — cleaned up on next save.
  static const _legacyUserId = 'jtr_bio_user_id';
  static const _legacyPasscode = 'jtr_bio_passcode';

  String _accountKey(String userId) =>
      '${ApiConfig.tenantSchema.trim()}|$userId';

  Future<Map<String, String>> _readAccounts() async {
    final raw = await _storage.read(key: _keyAccounts);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final e in decoded.entries) e.key.toString(): e.value.toString(),
        };
      }
    } catch (_) {}
    return {};
  }

  Future<void> _writeAccounts(Map<String, String> accounts) =>
      _storage.write(key: _keyAccounts, value: jsonEncode(accounts));

  /// Device has biometrics enrolled and usable.
  Future<bool> get isAvailable async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final types = await _auth.getAvailableBiometrics();
      // Diagnostic: shows which biometric classes the phone exposes
      // (fingerprint / face / weak / strong).
      // ignore: avoid_print
      print('[Biometric] available types: $types');
      return types.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// This user (in the current restaurant) has a saved biometric login.
  Future<bool> isEnabledFor(String userId) async {
    final accounts = await _readAccounts();
    return (accounts[_accountKey(userId)] ?? '').isNotEmpty;
  }

  /// Saves (or refreshes) this user's login without touching other users.
  Future<void> enable({required String userId, required String passcode}) async {
    final accounts = await _readAccounts();
    accounts[_accountKey(userId)] = passcode;
    await _writeAccounts(accounts);
    await _storage.delete(key: _legacyUserId);
    await _storage.delete(key: _legacyPasscode);
  }

  Future<void> disable(String userId) async {
    final accounts = await _readAccounts();
    if (accounts.remove(_accountKey(userId)) != null) {
      await _writeAccounts(accounts);
    }
  }

  /// Asks the phone's own fingerprint sheet (existing system fingerprints —
  /// the app never enrolls any). Used to confirm before enabling.
  Future<bool> verify() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirmez avec votre empreinte pour activer',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }

  /// Prompts the OS biometric sheet; returns [userId]'s saved passcode on
  /// success, or null when cancelled / failed / nothing saved.
  Future<String?> authenticate(String userId) async {
    final accounts = await _readAccounts();
    final passcode = accounts[_accountKey(userId)];
    if (passcode == null || passcode.isEmpty) return null;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Authentifiez-vous pour vous connecter',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return ok ? passcode : null;
    } on PlatformException {
      return null;
    }
  }
}
