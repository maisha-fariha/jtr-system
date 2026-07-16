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
/// instantly with no loader of its own.
class ConnectController extends GetxController {
  ConnectController({
    required AuthRepository authRepository,
    required SessionRepository sessionRepository,
  })  : _authRepository = authRepository,
        _sessionRepository = sessionRepository;

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;

  static const _syncTimeout = Duration(seconds: 15);

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
      // Defensive: this screen is only meant to be reached authenticated.
      _goNext(AppRoutes.login);
      return;
    }

    final waiterId = _authRepository.cachedSession?.user.id ?? 0;
    final steps = <String, Future<void> Function()>{
      'ptxListOrders': () async {
        await _sessionRepository.getSessionOrders(
          forceRefresh: true,
          waiterId: waiterId,
        );
      },
      'ptxActiveDay': () async {
        await _sessionRepository.getActiveDay(forceRefresh: true);
      },
      'ptxListTables': () async {
        await _sessionRepository.getTablesList(forceRefresh: true);
      },
    };

    var completed = 0;
    final total = steps.length;
    progress.value = 0;

    try {
      await Future.wait(
        steps.entries.map((entry) async {
          await entry.value();
          completed++;
          // Real, dynamic progress — one increment per finished step.
          progress.value = completed / total;
          statusDetail.value = entry.key;
        }),
      ).timeout(_syncTimeout);
    } catch (error) {
      syncError.value = error.toString();
      // Best effort — the session page already knows how to recover
      // (cache / error state), so a slow or failed preload must never
      // trap the user here.
    }

    progress.value = 1.0;
    isConnected.value = true;
    _goNext(AppRoutes.session);
  }

  void _goNext(String route) {
    if (_navigated) return;
    _navigated = true;
    Get.offNamed(route);
  }
}
