import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../data/models/device_activation_models.dart';
import '../data/repositories/device_repository.dart';
import '../routes/app_pages.dart';

/// Cold-start loading screen that decides Activation / Blocked / Connect.
class DeviceGateController extends GetxController {
  DeviceGateController({required DeviceRepository deviceRepository})
      : _deviceRepository = deviceRepository;

  final DeviceRepository _deviceRepository;

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
          _go(AppRoutes.connect);
          return;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  Future<void> retry() => _runGate();
}
