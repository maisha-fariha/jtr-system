import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Manages dark / light theme toggling for the whole app.
/// Call [ThemeController.to.toggle()] from any widget.
class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  final isDark = false.obs;

  void toggle() {
    isDark.value = !isDark.value;
    Get.changeThemeMode(isDark.value ? ThemeMode.dark : ThemeMode.light);
  }
}
