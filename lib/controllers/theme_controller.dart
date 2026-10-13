import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/app_flavor.dart';

/// Manages dark / light theme toggling for the whole app.
/// Call [ThemeController.to.toggle()] from any widget.
class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  final isDark = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Rapport app starts in dark mode; POS follows GetX / system default.
    if (AppFlavorConfig.isRapport) {
      isDark.value = true;
      Get.changeThemeMode(ThemeMode.dark);
    } else {
      isDark.value = Get.isDarkMode;
    }
  }

  void toggle() {
    final dark = !isDark.value;
    // Keep GetX theme mode in sync before notifying Obx listeners.
    Get.changeThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
    isDark.value = dark;
  }
}
