import 'package:get/get.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/device_repository.dart';
import '../routes/app_pages.dart';

class DeviceBlockedController extends GetxController {
  DeviceBlockedController({
    required DeviceRepository deviceRepository,
    required AuthRepository authRepository,
  })  : _deviceRepository = deviceRepository,
        _authRepository = authRepository;

  final DeviceRepository _deviceRepository;
  final AuthRepository _authRepository;

  late final String reason;

  String get title {
    if (reason == 'license') return 'Licence invalide';
    return 'Poste désactivé';
  }

  String get message {
    if (reason == 'license') {
      return 'La licence de cet établissement est expirée ou invalide. '
          'Contactez votre administrateur JTR.';
    }
    return 'Ce poste a été désactivé depuis le dashboard. '
        'Après réactivation par le vendor, rouvrez l\'application '
        '(aucun nouveau code n\'est nécessaire).';
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['reason'] is String) {
      reason = args['reason'] as String;
    } else {
      reason = 'deactivated';
    }
  }

  Future<void> retrySession() async {
    Get.offAllNamed(AppRoutes.deviceGate);
  }

  /// Used only when vendor revoked the poste (or user wants a new activation).
  Future<void> resetAndActivate() async {
    await _authRepository.logout();
    await _deviceRepository.clearDeviceCredentials();
    Get.offAllNamed(AppRoutes.activation);
  }
}
