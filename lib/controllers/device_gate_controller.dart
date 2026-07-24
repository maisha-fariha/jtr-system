import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../data/models/device_activation_models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/device_repository.dart';
import '../routes/app_pages.dart';

/// Cold-start router: Activation / Blocked / Login / Session.
///
/// Returning authenticated waiters skip the spinner + Connect preload and open
/// the session home immediately (cache paints first, network refreshes in
/// background). Device status is still verified after navigation.
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
      // Already logged in: open home now, verify device afterwards.
      if (_authRepository.isAuthenticated &&
          await _deviceRepository.hasStoredCredentials) {
        _go(AppRoutes.session);
        unawaited(_validateDeviceInBackground());
        return;
      }

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
          // Connect preload is only for fresh login (see LoginController).
          _go(
            _authRepository.isAuthenticated
                ? AppRoutes.session
                : AppRoutes.login,
          );
          return;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      isLoading.value = false;
    }
  }

  Future<void> _validateDeviceInBackground() async {
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
          return;
      }
    } catch (_) {
      // Keep session open on transient network errors (same as gate fallback).
    }
  }

  Future<void> retry() => _runGate();
}
