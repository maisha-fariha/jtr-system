import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../data/models/device_activation_models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/device_repository.dart';
import '../routes/app_pages.dart';

/// Cold-start loading screen that decides Activation / Blocked / Login / Connect.
class DeviceGateController extends GetxController {
  DeviceGateController({
    required DeviceRepository deviceRepository,
    required AuthRepository authRepository,
  })  : _deviceRepository = deviceRepository,
        _authRepository = authRepository;

  final DeviceRepository _deviceRepository;
  final AuthRepository _authRepository;

  final isLoading = true.obs;
  final statusText = 'Vérification du poste…'.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    // Wait for first frame — Get.offAllNamed in onInit blanks the navigator.
    SchedulerBinding.instance.addPostFrameCallback((_) => _runGate());
  }

  void _go(String route, {Object? arguments}) {
    Get.offAllNamed(route, arguments: arguments);
  }

  Future<void> _runGate() async {
    isLoading.value = true;
    errorMessage.value = null;
    statusText.value = 'Vérification du poste…';

    try {
      final outcome = await _deviceRepository.resolveStartupGate();
      switch (outcome) {
        case DeviceGateOutcome.needsActivation:
          _go(AppRoutes.activation);
          return;
        case DeviceGateOutcome.deactivated:
          _go(AppRoutes.deviceBlocked, arguments: {'reason': 'deactivated'});
          return;
        case DeviceGateOutcome.licenseBlocked:
          _go(AppRoutes.deviceBlocked, arguments: {'reason': 'license'});
          return;
        case DeviceGateOutcome.active:
          // Connect (session preload) only makes sense once authenticated;
          // otherwise go straight to Login — no sync screen before auth.
          _go(
            _authRepository.isAuthenticated
                ? AppRoutes.connect
                : AppRoutes.login,
          );
          return;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  Future<void> retry() => _runGate();
}
