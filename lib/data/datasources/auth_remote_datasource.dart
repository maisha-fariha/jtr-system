import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/api_envelope.dart';
import '../models/auth_session_model.dart';
import '../models/login_request.dart';
import '../models/login_role_model.dart';
import '../models/login_user_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<LoginUserModel>> fetchLoginUsers() async {
    final response = await _client.get<Map<String, dynamic>>(ApiEndpoints.loginUsers);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response.data!,
      (json) => json as List<dynamic>,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load users.',
        statusCode: envelope.status,
      );
    }

    return (envelope.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LoginUserModel.fromJson)
        .toList();
  }

  Future<List<LoginRoleModel>> fetchLoginRoles() async {
    final response = await _client.get<Map<String, dynamic>>(ApiEndpoints.loginRoles);
    final envelope = ApiEnvelope<List<dynamic>>.fromJson(
      response.data!,
      (json) => json as List<dynamic>,
    );

    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? 'Failed to load roles.',
        statusCode: envelope.status,
      );
    }

    return (envelope.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LoginRoleModel.fromJson)
        .toList();
  }

  Future<AuthSessionModel> login(
    LoginRequest request, {
    bool skipAuth = false,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: request.toJson(),
      options: skipAuth
          ? Options(extra: const {'skipAuth': true})
          : null,
    );

    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      response.data!,
      (json) => json as Map<String, dynamic>,
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Login failed.',
        statusCode: envelope.status,
      );
    }

    return AuthSessionModel.fromJson(envelope.data!);
  }
}
