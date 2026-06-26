import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/demo_table_menu.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import 'session_controller.dart';

class TableDetailsController extends GetxController {
  final selectedCategoryIndex = 0.obs;
  final selectedMenuItems = <String>{}.obs;
  final isBottomPanelExpanded = true.obs;
  final showPaymentOptions = false.obs;
  final activeToolbarIcon = Rx<IconData?>(Icons.grid_view);

  late final String orderNumber;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    orderNumber = (args is Map ? args['orderNumber'] as String? : null) ?? '';
  }

  SessionOrder? get order {
    if (!Get.isRegistered<SessionController>()) return null;
    final session = Get.find<SessionController>();
    for (final item in session.orders) {
      if (item.number == orderNumber) return item;
    }
    return null;
  }

  TableMenuCategory get currentCategory =>
      demoTableMenuCategories[selectedCategoryIndex.value];

  void selectCategory(int index) => selectedCategoryIndex.value = index;

  void toggleBottomPanel() {
    isBottomPanelExpanded.value = !isBottomPanelExpanded.value;
    if (isBottomPanelExpanded.value) {
      showPaymentOptions.value = false;
      activeToolbarIcon.value = Icons.grid_view;
    } else if (!showPaymentOptions.value) {
      activeToolbarIcon.value = null;
    }
  }

  void togglePaymentOptions() {
    final show = !showPaymentOptions.value;
    showPaymentOptions.value = show;
    if (show) {
      isBottomPanelExpanded.value = false;
      activeToolbarIcon.value = Icons.payments_outlined;
    } else {
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = Icons.grid_view;
    }
  }

  void onToolbarIconTap(IconData icon) {
    if (icon == Icons.home_outlined) {
      Get.offAllNamed(AppRoutes.session);
      return;
    }

    if (icon == Icons.keyboard_return_outlined) {
      Get.back();
      return;
    }

    if (icon == Icons.payments_outlined) {
      togglePaymentOptions();
      return;
    }

    if (icon == Icons.grid_view || icon == Icons.restaurant) {
      showPaymentOptions.value = false;
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = icon;
      return;
    }

    if (icon == Icons.restaurant_menu) {
      Get.toNamed(
        AppRoutes.menuSelection,
        arguments: {'orderNumber': orderNumber},
      );
      return;
    }

    activeToolbarIcon.value = icon;
  }

  bool isToolbarIconActive(IconData icon) => activeToolbarIcon.value == icon;

  void toggleMenuItem(TableMenuItem item) {
    if (!Get.isRegistered<SessionController>()) return;
    final session = Get.find<SessionController>();

    if (selectedMenuItems.contains(item.name)) {
      selectedMenuItems.remove(item.name);
      session.removeTableMenuItemFromOrder(orderNumber, item.name);
    } else {
      selectedMenuItems.add(item.name);
      session.addTableMenuItemToOrder(orderNumber, item.name, item.price);
    }
    selectedMenuItems.refresh();
  }

  bool isMenuItemSelected(String name) => selectedMenuItems.contains(name);

  void incrementProduct(int productIndex) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>()
        .adjustOrderProductQuantity(orderNumber, productIndex, 1);
  }

  void decrementProduct(int productIndex) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>()
        .adjustOrderProductQuantity(orderNumber, productIndex, -1);
  }

  void offerProduct(int productIndex) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>()
        .applyOfferToOrderProduct(orderNumber, productIndex);
  }

  void setProductMessage({
    required int productIndex,
    required String message,
  }) {
    if (!Get.isRegistered<SessionController>()) return;
    Get.find<SessionController>().setOrderProductMessage(
      orderNumber,
      productIndex,
      message,
    );
  }
}
