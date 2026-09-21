import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../controllers/login_controller.dart';
import '../core/network/api_exception.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/session_repository.dart';
import '../jtr_mobile/assistant/jtr_mobile_assistant_controller.dart';
import '../jtr_mobile/controllers/jtr_mobile_dashboard_controller.dart';
import '../jtr_mobile/data/jtr_mobile_dashboard_remote_datasource.dart';
import '../jtr_mobile/data/repositories/jtr_mobile_dashboard_repository.dart';
import '../routes/app_pages.dart';
import '../services/reverb_realtime_service.dart';
import '../controllers/session_controller.dart';

class AppNavigation {
  AppNavigation._();

  static bool _forceLogoutInFlight = false;

  static Future<void> logout() async {
    // Never block login navigation on a broken WebSocket disconnect.
    if (Get.isRegistered<ReverbRealtimeService>()) {
      try {
        await Get.find<ReverbRealtimeService>()
            .stop()
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    if (Get.isRegistered<SessionRepository>()) {
      await Get.find<SessionRepository>().clearOpenOrdersCache();
    }
    if (Get.isRegistered<AuthRepository>()) {
      await Get.find<AuthRepository>().logout();
    }
    _disposeSessionScopedControllers();
    // Put LoginController BEFORE the route builds (binding must not delete).
    ensureLoginControllerForNavigation(recreate: true);
    await Get.offAllNamed(AppRoutes.login);
  }

  /// Ensures [LoginController] exists before opening login.
  ///
  /// Uses [permanent] so `Get.offAllNamed` does not dispose it mid-rebuild
  /// (that was causing "LoginController not found" on LoginPage Obx).
  static void ensureLoginControllerForNavigation({bool recreate = false}) {
    if (recreate && Get.isRegistered<LoginController>()) {
      Get.delete<LoginController>(force: true);
    }
    if (!Get.isRegistered<LoginController>()) {
      Get.put(
        LoginController(authRepository: Get.find<AuthRepository>()),
        permanent: true,
      );
    }
  }

  static void _disposeSessionScopedControllers() {
    if (Get.isRegistered<JtrMobileAssistantController>()) {
      Get.delete<JtrMobileAssistantController>(force: true);
    }
    if (Get.isRegistered<JtrMobileDashboardController>()) {
      Get.delete<JtrMobileDashboardController>(force: true);
    }
    if (Get.isRegistered<JtrMobileDashboardRepository>()) {
      Get.delete<JtrMobileDashboardRepository>(force: true);
    }
    if (Get.isRegistered<JtrMobileDashboardRemoteDataSource>()) {
      Get.delete<JtrMobileDashboardRemoteDataSource>(force: true);
    }
    if (Get.isRegistered<SessionController>()) {
      Get.delete<SessionController>(force: true);
    }
  }

  /// Clears session and returns to login when the API reports unauthenticated.
  ///
  /// Safe to call repeatedly — concurrent / duplicate triggers are ignored.
  static void forceLogoutForUnauthenticated({
    Duration delay = const Duration(milliseconds: 600),
  }) {
    if (_forceLogoutInFlight) return;
    if (Get.currentRoute == AppRoutes.login) return;

    final hasSession = Get.isRegistered<AuthRepository>() &&
        Get.find<AuthRepository>().isAuthenticated;
    if (!hasSession) return;

    _forceLogoutInFlight = true;
    Future<void>.delayed(delay, () async {
      try {
        if (Get.currentRoute == AppRoutes.login) return;
        _closeOverlays();
        await logout();
      } finally {
        _forceLogoutInFlight = false;
      }
    });
  }

  /// Triggers force logout when [title]/[message] indicate an auth failure.
  static void forceLogoutIfUnauthenticatedMessage({
    String? title,
    String? message,
  }) {
    if (ApiException.isUnauthenticatedMessage(title) ||
        ApiException.isUnauthenticatedMessage(message)) {
      forceLogoutForUnauthenticated();
    }
  }

  /// Schedule logout after the current frame (used from Dio error mapping).
  static void scheduleForceLogoutForUnauthenticated() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      forceLogoutForUnauthenticated();
    });
  }

  static void _closeOverlays() {
    while (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
      Get.back();
    }
  }

  /// Pops routes until [routeName] is the current route.
  static void popUntilRoute(String routeName) {
    _closeOverlays();
    if (Get.currentRoute == routeName) return;
    Get.until((route) => route.settings.name == routeName);
  }

  /// From the product (CHOIX) screen back to menu selection.
  static void backToMenuSelection() => popUntilRoute(AppRoutes.menuSelection);

  /// From menu selection back to the table details screen.
  static void backToTableDetails({
    String? orderNumber,
    int? orderId,
  }) {
    _closeOverlays();

    if (Get.currentRoute == AppRoutes.tableDetails) return;

    if (Get.currentRoute == AppRoutes.menuSelection) {
      Get.back();
      return;
    }

    popUntilRoute(AppRoutes.tableDetails);

    if (Get.currentRoute != AppRoutes.tableDetails &&
        orderNumber != null &&
        orderNumber.isNotEmpty) {
      Get.offNamed(
        AppRoutes.tableDetails,
        arguments: {
          'orderNumber': orderNumber,
          if (orderId != null) 'orderId': orderId,
        },
      );
    }
  }
}
