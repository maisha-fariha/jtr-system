import 'dart:async';

import 'package:get/get.dart';

import '../data/repositories/auth_repository.dart';

class ConnectController extends GetxController {
  ConnectController({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  final progress = 0.0.obs;
  final statusDetail = 'ptxListMenus'.obs;
  final isConnected = false.obs;
  final syncError = RxnString();

  Timer? _timer;
  bool _syncStarted = false;

  @override
  void onInit() {
    super.onInit();
    _startLoading();
    _syncAuthMetadata();
  }

  Future<void> _syncAuthMetadata() async {
    if (_syncStarted) return;
    _syncStarted = true;

    try {
      statusDetail.value = 'syncAuthUsers';
      await _authRepository.syncAuthMetadata();
      statusDetail.value = 'ptxListMenus';
    } catch (error) {
      syncError.value = error.toString();
      // Offline or API error — cached data (if any) will be used on login.
    }
  }

  void _startLoading() {
    _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (progress.value >= 1.0) {
        progress.value = 1.0;
        timer.cancel();
        isConnected.value = true;
        return;
      }
      progress.value += 0.01;
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
