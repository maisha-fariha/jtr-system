import 'dart:async';

import 'package:get/get.dart';

class ConnectController extends GetxController {
  final progress = 0.0.obs;
  final statusDetail = 'ptxListMenus'.obs;
  final isConnected = false.obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _startLoading();
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
