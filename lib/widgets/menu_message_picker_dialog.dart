import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/menu_message_target.dart';
import '../utils/app_theme.dart';

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
  }) {
    return Get.dialog(
      MenuMessagePickerDialog(
        items: items,
        onItemSelected: onItemSelected,
      ),
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.dialogBackground,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: Get.isDarkMode ? 0.45 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Row(
                  children: [
                    _HeaderIconButton(
                      onTap: () => Get.back(),
                      child: Icon(
                        Icons.chevron_left,
                        color: AppTheme.darkText,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Message pour ?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _MessageTargetButton(
                        label: items[i].label,
                        onTap: () {
                          Get.back();
                          onItemSelected?.call(items[i]);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                height: 3,
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
    return Material(
      color: AppTheme.dialogItemBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          alignment: Alignment.centerLeft,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
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
    return Material(
      color: AppTheme.dialogItemBackground,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: child),
        ),
      ),
    );
  }
}
