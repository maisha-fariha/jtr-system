import 'dart:convert';

import '../../core/constants/storage_constants.dart';
import '../../core/storage/hive_storage.dart';
import '../models/auth_session_model.dart';
import '../models/login_role_model.dart';
import '../models/login_user_model.dart';

class AuthLocalDataSource {
  AuthLocalDataSource(this._storage);

  final HiveStorage _storage;

  Future<void> saveLoginUsers(List<LoginUserModel> users) async {
    final jsonList = users.map((user) => user.toJson()).toList();
    await _storage.writeString(
      StorageConstants.loginUsersKey,
      jsonEncode(jsonList),
    );
  }

  List<LoginUserModel> readLoginUsers() {
    final raw = _storage.readString(StorageConstants.loginUsersKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LoginUserModel.fromJson)
        .toList();
  }

  Future<void> saveLoginRoles(List<LoginRoleModel> roles) async {
    final jsonList = roles.map((role) => role.toJson()).toList();
    await _storage.writeString(
      StorageConstants.loginRolesKey,
      jsonEncode(jsonList),
    );
  }

  List<LoginRoleModel> readLoginRoles() {
    final raw = _storage.readString(StorageConstants.loginRolesKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LoginRoleModel.fromJson)
        .toList();
  }

  Future<void> saveSession(AuthSessionModel session) async {
    await _storage.writeString(
      StorageConstants.authSessionKey,
      jsonEncode(session.toJson()),
    );
    await _storage.writeString(StorageConstants.authTokenKey, session.token);
  }

  AuthSessionModel? readSession() {
    final raw = _storage.readString(StorageConstants.authSessionKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    return AuthSessionModel.fromJson(decoded);
  }

  String? readToken() => _storage.readString(StorageConstants.authTokenKey);

  Future<void> clearSession() => _storage.clearAuth();
}
