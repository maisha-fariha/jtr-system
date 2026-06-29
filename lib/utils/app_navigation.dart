import 'package:get/get.dart';

import '../data/repositories/auth_repository.dart';
import '../routes/app_pages.dart';

class AppNavigation {
  AppNavigation._();

  static Future<void> logout() async {
    if (Get.isRegistered<AuthRepository>()) {
      await Get.find<AuthRepository>().logout();
    }
    Get.offAllNamed(AppRoutes.home);
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
  static void backToTableDetails({String? orderNumber}) {
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
        arguments: {'orderNumber': orderNumber},
      );
    }
  }
}
