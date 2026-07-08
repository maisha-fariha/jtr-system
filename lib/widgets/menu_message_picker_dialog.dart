import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/menu_message_target.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

typedef MenuMessageTargetCallback = void Function(MenuMessageTarget target);

class MenuMessagePickerDialog extends StatelessWidget {
  const MenuMessagePickerDialog({
    super.key,
    required this.items,
    this.onItemSelected,
  });

  final List<MenuMessageTarget> items;
  final MenuMessageTargetCallback? onItemSelected;

  static Future<void> show({
    required List<MenuMessageTarget> items,
    MenuMessageTargetCallback? onItemSelected,
    BuildContext? context,
  }) {
    final dialogContext = context ?? Get.overlayContext ?? Get.context;
    if (dialogContext == null || !dialogContext.mounted) {
      return Future.value();
    }

    return showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
      builder: (_) => MenuMessagePickerDialog(
        items: items,
        onItemSelected: onItemSelected,
      ),
    );
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
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: Icon(
                        Icons.chevron_left,
                        color: AppTheme.darkText,
                        size: JtrResponsive.getResponsiveSize(context, 22),
                      ),
                    ),
                    JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
                    Expanded(
                      child: Text(
                        'Message pour ?',
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
                  ],
                ),
              ),
              Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  left: 16,
                  right: 16,
                  bottom: 18,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        JtrResponsive.getResponsiveSpacing(context, 12),
                      _MessageTargetButton(
                        label: items[i].label,
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          onItemSelected?.call(items[i]);
                        },
                      ),
                    ],
                  ],
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

class _MessageTargetButton extends StatelessWidget {
  const _MessageTargetButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = JtrResponsive.getResponsiveRadius(context, 16);

    return Material(
      color: AppTheme.dialogItemBackground,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: double.infinity,
          padding: JtrResponsive.getResponsivePadding(
            context,
            horizontal: 18,
            vertical: 18,
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppTheme.darkText,
              height: 1.2,
            ),
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
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = JtrResponsive.getResponsiveSize(context, 40);

    return Material(
      color: AppTheme.dialogItemBackground,
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
