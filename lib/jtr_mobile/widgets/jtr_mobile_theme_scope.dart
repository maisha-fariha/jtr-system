import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/theme_controller.dart';

/// Rebuilds [builder] when app light/dark mode changes.
///
/// JTR Mobile reads [AppTheme] static getters (not [Theme.of]), so pages must
/// subscribe to [ThemeController.isDark] — same pattern as [HomePage].
class JtrMobileThemeScope extends StatelessWidget {
  const JtrMobileThemeScope({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = ThemeController.to.isDark.value;
      return KeyedSubtree(
        key: ValueKey<bool>(isDark),
        child: builder(context),
      );
    });
  }
}
