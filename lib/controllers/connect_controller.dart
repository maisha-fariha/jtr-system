import 'package:get/get.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/session_repository.dart';
import '../routes/app_pages.dart';

/// Post-login preload screen — entered only for an authenticated user
/// (right after a successful login, or a returning user at cold start).
/// Never shown before login anymore: unauthenticated flows go straight to
/// [AppRoutes.login].
///
/// Loads every open order, the active day and the tables list, with the
/// progress bar reflecting real completion of that work (not a fixed
/// animation), then hands off to [AppRoutes.session] — which then paints
/// instantly with no empty-state flash.
class ConnectController extends GetxController {
  ConnectController({
    required AuthRepository authRepository,
    required SessionRepository sessionRepository,
  })  : _authRepository = authRepository,
        _sessionRepository = sessionRepository;

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;

  static const _syncTimeout = Duration(seconds: 20);

  final progress = 0.0.obs;
  final statusDetail = 'ptxListOrders'.obs;
  final isConnected = false.obs;
  final syncError = RxnString();

  bool _navigated = false;

  @override
  void onInit() {
    super.onInit();
    _runSync();
  }

  Future<void> _runSync() async {
    if (!_authRepository.isAuthenticated) {
      _goNext(AppRoutes.login);
      return;
    }

    final waiterId = _authRepository.cachedSession?.user.id ?? 0;

    // Fresh login: start from an empty cache, then fill it before session opens.
    try {
      await _sessionRepository.clearOpenOrdersCache();
    } catch (_) {}

    progress.value = 0;
    statusDetail.value = 'ptxListOrders';

    try {
      // Orders first — session must not open until this list is ready.
      await _sessionRepository
          .getSessionOrders(
            forceRefresh: true,
            waiterId: waiterId,
          )
          .timeout(_syncTimeout);
      progress.value = 1 / 3;
      statusDetail.value = 'ptxActiveDay';

      await Future.wait([
        _sessionRepository.getActiveDay(forceRefresh: true),
        _sessionRepository.getTablesList(forceRefresh: true),
      ]).timeout(_syncTimeout);

      progress.value = 1.0;
      statusDetail.value = 'ptxListTables';
    } catch (error) {
      syncError.value = error.toString();
      // Still try one last orders pull so session is not empty if possible.
      try {
        await _sessionRepository.getSessionOrders(
          forceRefresh: true,
          waiterId: waiterId,
        );
      } catch (_) {}
    }

    progress.value = 1.0;
    isConnected.value = true;
    _goNext(AppRoutes.session, arguments: const {'preloaded': true});
  }

  void _goNext(String route, {Map<String, dynamic>? arguments}) {
    if (_navigated) return;
    _navigated = true;
    Get.offNamed(route, arguments: arguments);
  }
}
