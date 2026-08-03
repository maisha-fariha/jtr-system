import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../models/user_suggestion.dart';
import '../../services/connectivity_service.dart';
import '../../utils/api_log.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_session_model.dart';
import '../models/login_request.dart';
import '../models/login_role_model.dart';
import '../models/login_user_model.dart';

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required ConnectivityService connectivity,
    required ApiClient apiClient,
  })  : _remote = remote,
        _local = local,
        _connectivity = connectivity,
        _apiClient = apiClient;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final ConnectivityService _connectivity;
  final ApiClient _apiClient;

  List<LoginUserModel> get cachedUsers => _local.readLoginUsers();

  List<LoginRoleModel> get cachedRoles => _local.readLoginRoles();

  AuthSessionModel? get cachedSession => _local.readSession();

  bool get isAuthenticated {
    final token = cachedSession?.token ?? _local.readToken();
    return token != null && token.isNotEmpty;
  }

  List<UserSuggestion> get cachedUserSuggestions =>
      cachedUsers.map((user) => user.toSuggestion()).toList();

  /// Loads users from cache immediately; refreshes from network when online.
  Future<List<UserSuggestion>> getLoginUsers({bool forceRefresh = false}) async {
    if (!forceRefresh && cachedUsers.isNotEmpty) {
      _refreshUsersInBackground();
      return cachedUserSuggestions;
    }

    final online = await _connectivity.isOnline;
    if (online) {
      final users = await _remote.fetchLoginUsers();
      await _local.saveLoginUsers(users);
      return users.map((user) => user.toSuggestion()).toList();
    }

    if (cachedUsers.isNotEmpty) {
      return cachedUserSuggestions;
    }

    throw ApiException(message: 'No users available offline.');
  }

  Future<void> _refreshUsersInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final users = await _remote.fetchLoginUsers();
      await _local.saveLoginUsers(users);
    } catch (_) {
      // Keep cached data when background refresh fails.
    }
  }

  /// Loads roles from cache or network (offline-first).
  Future<List<LoginRoleModel>> getLoginRoles({bool forceRefresh = false}) async {
    if (!forceRefresh && cachedRoles.isNotEmpty) {
      _refreshRolesInBackground();
      return cachedRoles;
    }

    final online = await _connectivity.isOnline;
    if (online) {
      final roles = await _remote.fetchLoginRoles();
      await _local.saveLoginRoles(roles);
      return roles;
    }

    if (cachedRoles.isNotEmpty) return cachedRoles;

    throw ApiException(message: 'No roles available offline.');
  }

  Future<void> _refreshRolesInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final roles = await _remote.fetchLoginRoles();
      await _local.saveLoginRoles(roles);
    } catch (_) {}
  }

  /// Prefetches users + roles during the connect screen.
  Future<void> syncAuthMetadata() async {
    if (!await _connectivity.isOnline) return;

    final users = await _remote.fetchLoginUsers();
    final roles = await _remote.fetchLoginRoles();
    await _local.saveLoginUsers(users);
    await _local.saveLoginRoles(roles);
  }

  Future<AuthSessionModel> login({
    required String userOrId,
    required String passcode,
  }) async {
    final online = await _connectivity.isOnline;
    if (!online) {
      throw ApiException(
        message: 'Connexion impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final session = await _remote.login(
      LoginRequest(
        type: 'passcode',
        userOrId: userOrId,
        passcode: passcode,
      ),
    );

    await _local.saveSession(session);
    _apiClient.setAuthToken(session.token);
    logAuthToken(session.token, source: 'login');
    return session;
  }

  /// Validates credentials for delete/offer. Returns the token for one-shot use.
  /// Does not replace the logged-in waiter session.
  Future<AuthSessionModel> verifyCredentials({
    required String userOrId,
    required String passcode,
  }) async {
    final online = await _connectivity.isOnline;
    if (!online) {
      throw ApiException(
        message: 'Vérification impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    return _remote.login(
      LoginRequest(
        type: 'passcode',
        userOrId: userOrId,
        passcode: passcode,
        forceLogin: true,
      ),
      skipAuth: true,
    );
  }

  /// Restores the saved auth token into [ApiClient] after a cold start.
  Future<bool> restoreSessionOnAppStart() async {
    final session = _local.readSession();
    final token = session?.token ?? _local.readToken();
    if (token == null || token.isEmpty) {
      _apiClient.setAuthToken(null);
      logAuthTokenCleared(source: 'app_start_no_session');
      return false;
    }

    _apiClient.setAuthToken(token);
    logAuthToken(token, source: 'app_start_restore');
    return true;
  }

  Future<void> logout() async {
    await _local.clearSession();
    _apiClient.setAuthToken(null);
    logAuthTokenCleared(source: 'logout');
  }
}
