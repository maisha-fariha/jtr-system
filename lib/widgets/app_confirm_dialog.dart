import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.onConfirm,
  });

  final String title;
  final String message;
  final VoidCallback? onConfirm;

  static Future<void> show({
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    return Get.dialog(
      AppConfirmDialog(
        title: title,
        message: message,
        onConfirm: onConfirm,
      ),
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
    );
  }

  void _confirm() {
    Get.back();
    onConfirm?.call();
  }

  @override
  Widget build(BuildContext context) {
    final dialogRadius = JtrResponsive.getResponsiveRadius(context, 24);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 28,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.dialogBackground,
          borderRadius: BorderRadius.circular(dialogRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: Get.isDarkMode ? 0.45 : 0.12),
              blurRadius: JtrResponsive.getResponsiveWidth(context, 28),
              offset: Offset(
                0,
                JtrResponsive.getResponsiveHeight(context, 10),
              ),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dialogRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  left: 16,
                  right: 16,
                  top: 18,
                  bottom: 14,
                ),
                child: Row(
                  children: [
                    _HeaderIconButton(
                      onTap: () => Get.back(),
                      child: Icon(
                        Icons.chevron_left,
                        color: AppTheme.darkText,
                        size: JtrResponsive.getResponsiveSize(context, 22),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: JtrResponsive.getResponsiveFontSize(
                            context,
                            18,
                          ),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                    _HeaderIconButton(
                      onTap: _confirm,
                      backgroundColor: AppTheme.lightButton,
                      child: Icon(
                        Icons.check,
                        color: AppTheme.primary,
                        size: JtrResponsive.getResponsiveSize(context, 22),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  left: 20,
                  right: 20,
                  bottom: 22,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(
                      context,
                      15,
                    ),
                    height: 1.45,
                    color: AppTheme.darkText.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Container(
                height: JtrResponsive.getResponsiveHeight(context, 3),
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.onTap,
    required this.child,
    this.backgroundColor,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final size = JtrResponsive.getResponsiveSize(context, 40);

    return Material(
      color: backgroundColor ?? AppTheme.dialogItemBackground,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}
