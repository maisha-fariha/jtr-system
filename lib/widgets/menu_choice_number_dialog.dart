import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';

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
      barrierColor: Colors.black.withValues(alpha: 0.45),
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
    return Dialog(
      backgroundColor: AppTheme.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
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
                    style: TextStyle(
                      fontSize: 16,
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
            const SizedBox(height: 14),
            Divider(height: 1, color: AppTheme.cardBorder),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.maxChoices,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
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
    );
  }
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
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: iconColor, size: 22),
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
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
            ),
          ),
        ),
      ),
    );
  }
}
