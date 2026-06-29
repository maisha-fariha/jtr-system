import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';

class TableNumberDialog extends StatefulWidget {
  const TableNumberDialog({
    super.key,
    this.title = 'N° DE TABLE',
    this.onConfirm,
  });

  final String title;
  final ValueChanged<String>? onConfirm;

  static Future<void> show({
    String title = 'N° DE TABLE',
    ValueChanged<String>? onConfirm,
  }) {
    return Get.dialog(
      TableNumberDialog(title: title, onConfirm: onConfirm),
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
    );
  }

  @override
  State<TableNumberDialog> createState() => _TableNumberDialogState();
}

class _TableNumberDialogState extends State<TableNumberDialog> {
  static const _keyGap = 6.0;
  static const _keyHeight = 54.0;
  static const _keyRadius = 12.0;
  static const _columns = 4;

  String _tableInput = '';

  String get _mainDisplay => _tableInput.isEmpty ? '---' : _tableInput;

  void _appendDigit(String value) {
    setState(() => _tableInput += value);
  }

  void _backspace() {
    if (_tableInput.isEmpty) return;
    setState(() => _tableInput = _tableInput.substring(0, _tableInput.length - 1));
  }

  void _confirm() {
    if (_tableInput.isEmpty) return;
    Get.back();
    widget.onConfirm?.call(_tableInput);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      return Dialog(
        backgroundColor: AppTheme.keypadDialogBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridWidth = constraints.maxWidth;
              final cellWidth =
                  (gridWidth - _keyGap * (_columns - 1)) / _columns;
              final doubleCellWidth = cellWidth * 2 + _keyGap;
              final isDark = AppTheme.isDark;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.primary : AppTheme.darkText,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _KeyRow(
                    children: [
                      _ActionKey(
                        width: cellWidth,
                        backgroundColor: AppTheme.keypadCancelBackground,
                        onTap: () => Get.back(),
                        child: Icon(
                          Icons.close,
                          color: AppTheme.keypadCancelIcon,
                          size: 22,
                        ),
                      ),
                      _DisplayField(
                        text: _mainDisplay,
                        width: doubleCellWidth,
                        height: _keyHeight,
                        fontSize: 20,
                      ),
                      _ActionKey(
                        width: cellWidth,
                        backgroundColor: AppTheme.keypadKeyBackground,
                        onTap: _backspace,
                        child: Icon(
                          Icons.backspace_outlined,
                          color: AppTheme.keypadKeyForeground.withValues(
                            alpha: AppTheme.isDark ? 0.9 : 0.65,
                          ),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  _KeyRow(
                    children: [
                      _CalcKey(width: cellWidth, label: '7', onTap: () => _appendDigit('7')),
                      _CalcKey(width: cellWidth, label: '8', onTap: () => _appendDigit('8')),
                      _CalcKey(width: cellWidth, label: '9', onTap: () => _appendDigit('9')),
                      _CalcKey(width: cellWidth, label: '/', onTap: () {}),
                    ],
                  ),
                  _KeyRow(
                    children: [
                      _CalcKey(width: cellWidth, label: '4', onTap: () => _appendDigit('4')),
                      _CalcKey(width: cellWidth, label: '5', onTap: () => _appendDigit('5')),
                      _CalcKey(width: cellWidth, label: '6', onTap: () => _appendDigit('6')),
                      _CalcKey(width: cellWidth, label: '*', onTap: () {}),
                    ],
                  ),
                  _KeyRow(
                    children: [
                      _CalcKey(width: cellWidth, label: '1', onTap: () => _appendDigit('1')),
                      _CalcKey(width: cellWidth, label: '2', onTap: () => _appendDigit('2')),
                      _CalcKey(width: cellWidth, label: '3', onTap: () => _appendDigit('3')),
                      _CalcKey(width: cellWidth, label: '-', onTap: () {}),
                    ],
                  ),
                  _KeyRow(
                    children: [
                      _CalcKey(
                        width: doubleCellWidth,
                        label: '0',
                        onTap: () => _appendDigit('0'),
                      ),
                      _CalcKey(width: cellWidth, label: '.', onTap: () => _appendDigit('.')),
                      _ConfirmKey(
                        width: cellWidth,
                        onTap: _tableInput.isEmpty ? null : _confirm,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    });
  }
}

class _DisplayField extends StatelessWidget {
  const _DisplayField({
    required this.text,
    required this.height,
    required this.fontSize,
    this.width,
  });

  final String text;
  final double height;
  final double fontSize;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.keypadDisplayBackground,
          borderRadius: BorderRadius.circular(_TableNumberDialogState._keyRadius),
          border: isDark
              ? null
              : Border.all(color: AppTheme.keypadKeyBorder),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppTheme.keypadKeyForeground.withValues(
                alpha: text == '---' ? 0.35 : 0.9,
              ),
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _TableNumberDialogState._keyGap),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: _TableNumberDialogState._keyGap),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _CalcKey extends StatelessWidget {
  const _CalcKey({
    required this.width,
    required this.label,
    required this.onTap,
  });

  final double width;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _KeySurface(
      width: width,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppTheme.keypadKeyForeground.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.width,
    required this.backgroundColor,
    required this.onTap,
    required this.child,
  });

  final double width;
  final Color backgroundColor;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _KeySurface(
      width: width,
      onTap: onTap,
      color: backgroundColor,
      child: child,
    );
  }
}

class _ConfirmKey extends StatelessWidget {
  const _ConfirmKey({
    required this.width,
    required this.onTap,
  });

  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final isDark = AppTheme.isDark;
    final buttonColor = isDark || isEnabled
        ? AppTheme.primary
        : AppTheme.primary.withValues(alpha: 0.45);

    return SizedBox(
      width: width,
      height: _TableNumberDialogState._keyHeight,
      child: Material(
        color: buttonColor,
        borderRadius: BorderRadius.circular(_TableNumberDialogState._keyRadius),
        elevation: isEnabled && !isDark ? 5 : 0,
        shadowColor: AppTheme.primary.withValues(alpha: 0.45),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_TableNumberDialogState._keyRadius),
          child: Center(
            child: isDark
                ? Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.keypadDialogBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppTheme.primary,
                      size: 16,
                    ),
                  )
                : Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppTheme.primary,
                      size: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _KeySurface extends StatelessWidget {
  const _KeySurface({
    required this.width,
    required this.onTap,
    required this.child,
    this.color,
  });

  final double width;
  final VoidCallback onTap;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final keyColor = color ?? AppTheme.keypadKeyBackground;

    return SizedBox(
      width: width,
      height: _TableNumberDialogState._keyHeight,
      child: Material(
        color: keyColor,
        borderRadius: BorderRadius.circular(_TableNumberDialogState._keyRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_TableNumberDialogState._keyRadius),
          child: Center(child: child),
        ),
      ),
    );
  }
}
