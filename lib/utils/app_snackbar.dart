import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_theme.dart';

/// App-themed snackbar for light and dark mode.
///
/// Prefer this over raw [Get.snackbar] / Material [SnackBar] so every message
/// matches brand surfaces and text tokens.
class AppSnackbar {
  AppSnackbar._();

  static const Duration defaultDuration = Duration(seconds: 2);

  /// Shows a floating snackbar styled with [AppTheme].
  ///
  /// [snackPosition] and [margin] are accepted for call-site compatibility
  /// but styling remains fixed to the design system.
  static void show(
    String title,
    String message, {
    Duration duration = defaultDuration,
    SnackPosition snackPosition = SnackPosition.BOTTOM,
    EdgeInsets? margin,
    BuildContext? context,
  }) {
    final titleTrimmed = title.trim();
    final messageTrimmed = message.trim();
    if (titleTrimmed.isEmpty && messageTrimmed.isEmpty) return;

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        _materialSnackBar(
          title: titleTrimmed,
          message: messageTrimmed,
          duration: duration,
        ),
      );
      return;
    }

    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Get.snackbar(
      titleTrimmed,
      messageTrimmed,
      snackPosition: snackPosition,
      margin: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
      borderRadius: 16,
      backgroundColor: AppTheme.dialogBackground,
      colorText: AppTheme.darkText,
      borderColor: AppTheme.cardBorder,
      borderWidth: 1,
      duration: duration,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      overlayBlur: 0,
      barBlur: 0,
      titleText: titleTrimmed.isEmpty
          ? const SizedBox.shrink()
          : Text(
              titleTrimmed,
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
      messageText: messageTrimmed.isEmpty
          ? const SizedBox.shrink()
          : Text(
              messageTrimmed,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: AppTheme.isDark ? 0.35 : 0.10),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    );
  }

  static SnackBar _materialSnackBar({
    required String title,
    required String message,
    required Duration duration,
  }) {
    final hasTitle = title.isNotEmpty;
    final hasMessage = message.isNotEmpty;
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      elevation: 0,
      backgroundColor: AppTheme.dialogBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      duration: duration,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle)
            Text(
              title,
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          if (hasTitle && hasMessage) const SizedBox(height: 4),
          if (hasMessage)
            Text(
              message,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}
