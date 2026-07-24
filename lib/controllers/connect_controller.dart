import 'dart:async';

import 'package:get/get.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/session_repository.dart';
import '../routes/app_pages.dart';

/// Post-login preload screen — shown **only after a fresh login**.
///
/// Returning users skip this and open [AppRoutes.session] from the device
/// gate (cached orders paint first). Unauthenticated flows go to login.
///
/// Loads open orders, active day and tables, then hands off to session.
class ConnectController extends GetxController {
  ConnectController({
    required AuthRepository authRepository,
    required SessionRepository sessionRepository,
  })  : _authRepository = authRepository,
        _sessionRepository = sessionRepository;

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;

  static const _syncTimeout = Duration(seconds: 20);

  /// Weighted phases so the bar advances through the whole 0–100% range.
  static const _ordersEnd = 0.70;
  static const _activeDayEnd = 0.85;
  static const _tablesEnd = 1.0;

  final progress = 0.0.obs;
  final isConnected = false.obs;
  final syncError = RxnString();

  bool _navigated = false;
  Timer? _pulseTimer;
  double _phaseCeiling = _ordersEnd;

  @override
  void onInit() {
    super.onInit();
    _runSync();
  }

  @override
  void onClose() {
    _stopPulse();
    super.onClose();
  }

  Future<void> _runSync() async {
    if (!_authRepository.isAuthenticated) {
      _goNext(AppRoutes.login);
      return;
    }

    final waiterId = _authRepository.cachedSession?.user.id ?? 0;

    _setProgress(0);
    _beginPhase(floor: 0, ceiling: 0.08);

    // Fresh login: start from an empty cache, then fill it before session opens.
    try {
      await _sessionRepository.clearOpenOrdersCache();
    } catch (_) {}

    try {
      _beginPhase(floor: 0.05, ceiling: _ordersEnd);

      // Orders first — session must not open until this list is ready.
      await _sessionRepository
          .getSessionOrders(
            forceRefresh: true,
            waiterId: waiterId,
            onProgress: (fraction) {
              _setProgress(0.05 + fraction * (_ordersEnd - 0.05));
            },
          )
          .timeout(_syncTimeout);
      _setProgress(_ordersEnd);

      _beginPhase(floor: _ordersEnd, ceiling: _activeDayEnd);
      await _sessionRepository
          .getActiveDay(forceRefresh: true)
          .timeout(_syncTimeout);
      _setProgress(_activeDayEnd);

      _beginPhase(floor: _activeDayEnd, ceiling: _tablesEnd);
      await _sessionRepository
          .getTablesList(forceRefresh: true)
          .timeout(_syncTimeout);
      _setProgress(_tablesEnd);
    } catch (error) {
      syncError.value = error.toString();
      // Still try one last orders pull so session is not empty if possible.
      try {
        await _sessionRepository.getSessionOrders(
          forceRefresh: true,
          waiterId: waiterId,
          onProgress: (fraction) {
            _setProgress(0.4 + fraction * 0.5);
          },
        );
      } catch (_) {}
    }

    _stopPulse();
    _setProgress(1.0);
    isConnected.value = true;
    // Brief beat at 100% so the user sees completion before navigation.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    _goNext(AppRoutes.session, arguments: const {'preloaded': true});
  }

  void _beginPhase({required double floor, required double ceiling}) {
    _phaseCeiling = ceiling;
    if (progress.value < floor) {
      _setProgress(floor);
    }
    _startPulse();
  }

  void _setProgress(double value) {
    final next = value.clamp(0.0, 1.0);
    // Never move the bar backwards (stale page callbacks / pulse races).
    if (next + 0.0001 < progress.value) return;
    progress.value = next;
  }

  /// Soft advance inside the current phase so a long network wait never
  /// freezes the bar at a stuck percentage.
  void _startPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 160), (_) {
      final current = progress.value;
      final softCap = _phaseCeiling - 0.015;
      if (current >= softCap) return;
      final remaining = softCap - current;
      // Ease toward the phase ceiling; real callbacks still jump ahead.
      _setProgress(current + (remaining * 0.045).clamp(0.002, 0.02));
    });
  }

  void _stopPulse() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }

  void _goNext(String route, {Map<String, dynamic>? arguments}) {
    if (_navigated) return;
    _navigated = true;
    Get.offNamed(route, arguments: arguments);
  }
}
