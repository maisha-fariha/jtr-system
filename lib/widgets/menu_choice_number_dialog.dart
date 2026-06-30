import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

typedef MenuChoiceNumberCallback = void Function(int choiceNumber);

class MenuChoiceNumberDialog extends StatefulWidget {
  const MenuChoiceNumberDialog({
    super.key,
    required this.menuLabel,
    this.onConfirm,
    this.maxChoices = 6,
  });

  final String menuLabel;
  final MenuChoiceNumberCallback? onConfirm;
  final int maxChoices;

  static Future<void> show({
    required String menuLabel,
    MenuChoiceNumberCallback? onConfirm,
    int maxChoices = 6,
  }) {
    return Get.dialog(
      MenuChoiceNumberDialog(
        menuLabel: menuLabel,
        onConfirm: onConfirm,
        maxChoices: maxChoices,
      ),
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
    );
  }

  @override
  State<MenuChoiceNumberDialog> createState() => _MenuChoiceNumberDialogState();
}

class _MenuChoiceNumberDialogState extends State<MenuChoiceNumberDialog> {
  int? _selectedNumber;

  void _selectNumber(int value) {
    setState(() => _selectedNumber = value);
  }

  void _confirm() {
    final value = _selectedNumber;
    if (value == null) return;
    Get.back();
    widget.onConfirm?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      final isLarge = JtrResponsive.isLargeDevice(context);
      final gridSpacing = JtrResponsive.getResponsiveWidth(
        context,
        isLarge ? 20 : 16,
      );
      final crossAxisCount = JtrResponsive.getResponsiveValue(
        context,
        small: 3,
        medium: 3,
        large: 6,
      );
      final dialogRadius = JtrResponsive.getResponsiveRadius(
        context,
        isLarge ? 24 : 16,
      );
      final maxDialogWidth = JtrResponsive.getResponsiveWidth(
        context,
        isLarge ? 560 : 400,
      );

      return Dialog(
        backgroundColor: AppTheme.dialogBackground,
        insetPadding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: isLarge ? 48 : 36,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxDialogWidth),
          child: Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              left: isLarge ? 20 : 16,
              right: isLarge ? 20 : 16,
              top: isLarge ? 18 : 14,
              bottom: isLarge ? 24 : 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _HeaderIconButton(
                      backgroundColor: AppTheme.inactiveSurface,
                      icon: Icons.chevron_left,
                      iconColor: AppTheme.textSecondary,
                      onTap: () => Get.back(),
                    ),
                    Expanded(
                      child: Text(
                        widget.menuLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _choiceDialogFontSize(context, 16),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    _HeaderIconButton(
                      backgroundColor: AppTheme.lightButton,
                      icon: Icons.check,
                      iconColor: AppTheme.primary,
                      onTap: _selectedNumber == null ? null : _confirm,
                    ),
                  ],
                ),
                JtrResponsive.getResponsiveSpacing(
                  context,
                  isLarge ? 16 : 14,
                ),
                Divider(height: 1, color: AppTheme.cardBorder),
                JtrResponsive.getResponsiveSpacing(
                  context,
                  isLarge ? 24 : 20,
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.maxChoices,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: gridSpacing,
                    crossAxisSpacing: gridSpacing,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final number = index + 1;
                    final isSelected = _selectedNumber == number;
                    return _ChoiceNumberButton(
                      number: number,
                      isSelected: isSelected,
                      onTap: () => _selectNumber(number),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

double _choiceDialogFontSize(BuildContext context, double base) {
  final fontSize = JtrResponsive.getResponsiveFontSize(context, base);
  if (JtrResponsive.isLargeDevice(context)) {
    return fontSize + 2;
  }
  return fontSize;
}

double _choiceDialogIconSize(BuildContext context, double base) {
  final size = JtrResponsive.getResponsiveSize(context, base);
  if (JtrResponsive.isLargeDevice(context)) {
    return size + 2;
  }
  return size;
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLarge = JtrResponsive.isLargeDevice(context);
    final radius = JtrResponsive.getResponsiveRadius(
      context,
      isLarge ? 12 : 10,
    );
    final size = JtrResponsive.getResponsiveSize(
      context,
      isLarge ? 44 : 40,
    );

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: iconColor,
            size: _choiceDialogIconSize(context, 22),
          ),
        ),
      ),
    );
  }
}

class _ChoiceNumberButton extends StatelessWidget {
  const _ChoiceNumberButton({
    required this.number,
    required this.isSelected,
    required this.onTap,
  });

  final int number;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLarge = JtrResponsive.isLargeDevice(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? AppTheme.lightButton : AppTheme.inactiveSurface,
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
              width: isSelected ? (isLarge ? 2.5 : 2) : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: _choiceDialogFontSize(context, 22),
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
            ),
          ),
        ),
      ),
    );
  }
}
