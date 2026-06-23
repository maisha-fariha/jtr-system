import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../utils/api_response.dart';

/// Authentication data model
class AuthData {
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final Map<String, dynamic>? userData;

  AuthData({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.userData,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
      'userData': userData,
    };
  }

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      userData: json['userData'] as Map<String, dynamic>?,
    );
  }
}

/// Authentication Service
class AuthService {
  final ApiService apiService;
  final SharedPreferences prefs;
  static const String _authKey = 'gems_auth_data';

  AuthService(this.apiService, this.prefs);

  /// Login
  Future<ApiResponse<AuthData>> login({
    required String email,
    required String password,
    String endpoint = '/auth/login',
  }) async {
    final response = await apiService.post<Map<String, dynamic>>(
      endpoint,
      data: {
        'email': email,
        'password': password,
      },
    );

    if (response.success && response.data != null) {
      final authData = _parseAuthResponse(response.data!);
      await _saveAuthData(authData);
      apiService.setAuthToken(authData.accessToken);
      return ApiResponse.success(authData);
    }

    return ApiResponse.error(
      response.message ?? 'Login failed',
      statusCode: response.statusCode,
    );
  }

  /// Register
  Future<ApiResponse<AuthData>> register({
    required Map<String, dynamic> data,
    String endpoint = '/auth/register',
  }) async {
    final response = await apiService.post<Map<String, dynamic>>(
      endpoint,
      data: data,
    );

    if (response.success && response.data != null) {
      final authData = _parseAuthResponse(response.data!);
      await _saveAuthData(authData);
      apiService.setAuthToken(authData.accessToken);
      return ApiResponse.success(authData);
    }

    return ApiResponse.error(
      response.message ?? 'Registration failed',
      statusCode: response.statusCode,
    );
  }

  /// Refresh token
  Future<ApiResponse<AuthData>> refreshToken({
    String? refreshToken,
    String endpoint = '/auth/refresh',
  }) async {
    final storedAuth = await getStoredAuth();
    final token = refreshToken ?? storedAuth?.refreshToken;

    if (token == null) {
      return ApiResponse.error('No refresh token available');
    }

    final response = await apiService.post<Map<String, dynamic>>(
      endpoint,
      data: {'refreshToken': token},
    );

    if (response.success && response.data != null) {
      final authData = _parseAuthResponse(response.data!);
      await _saveAuthData(authData);
      apiService.setAuthToken(authData.accessToken);
      return ApiResponse.success(authData);
    }

    return ApiResponse.error(
      response.message ?? 'Token refresh failed',
      statusCode: response.statusCode,
    );
  }

  /// Logout
  Future<void> logout() async {
    await prefs.remove(_authKey);
    apiService.setAuthToken(null);
  }

  /// Get stored auth data
  Future<AuthData?> getStoredAuth() async {
    final authJson = prefs.getString(_authKey);
    if (authJson == null) return null;

    try {
      return AuthData.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(authJson) as Map,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final authData = await getStoredAuth();
    if (authData == null) return false;

    if (authData.isExpired && authData.refreshToken != null) {
      final refreshResponse = await refreshToken();
      return refreshResponse.success;
    }

    apiService.setAuthToken(authData.accessToken);
    return true;
  }

  /// Initialize auth (call on app start)
  Future<void> initialize() async {
    final authData = await getStoredAuth();
    if (authData != null && !authData.isExpired) {
      apiService.setAuthToken(authData.accessToken);
    } else if (authData != null && authData.refreshToken != null) {
      await refreshToken();
    }
  }

  /// Parse auth response
  AuthData _parseAuthResponse(Map<String, dynamic> data) {
    return AuthData(
      accessToken: data['accessToken'] ?? data['token'] ?? '',
      refreshToken: data['refreshToken'],
      expiresAt: data['expiresAt'] != null
          ? DateTime.parse(data['expiresAt'])
          : data['expiresIn'] != null
              ? DateTime.now().add(
                  Duration(seconds: data['expiresIn'] as int),
                )
              : null,
      userData: data['user'] ?? data['userData'],
    );
  }

  /// Save auth data to local storage
  Future<void> _saveAuthData(AuthData authData) async {
    await prefs.setString(_authKey, jsonEncode(authData.toJson()));
  }
}

