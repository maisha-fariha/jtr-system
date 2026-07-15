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
    _runGate();
  }

  Future<void> _runGate() async {
    isLoading.value = true;
    errorMessage.value = null;
    statusText.value = 'Vérification du poste…';

    try {
      final outcome = await _deviceRepository.resolveStartupGate();
      switch (outcome) {
        case DeviceGateOutcome.needsActivation:
          Get.offAllNamed(AppRoutes.activation);
          return;
        case DeviceGateOutcome.deactivated:
          Get.offAllNamed(
            AppRoutes.deviceBlocked,
            arguments: {'reason': 'deactivated'},
          );
          return;
        case DeviceGateOutcome.licenseBlocked:
          Get.offAllNamed(
            AppRoutes.deviceBlocked,
            arguments: {'reason': 'license'},
          );
          return;
        case DeviceGateOutcome.active:
          Get.offAllNamed(AppRoutes.connect);
          return;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  Future<void> retry() => _runGate();
}
