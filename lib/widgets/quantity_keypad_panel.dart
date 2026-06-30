import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Compact numeric keypad for entering a product quantity before tapping items.
class QuantityKeypadPanel extends StatefulWidget {
  const QuantityKeypadPanel({
    super.key,
    required this.value,
    required this.onChanged,
    this.onClose,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClose;

  @override
  State<QuantityKeypadPanel> createState() => _QuantityKeypadPanelState();
}

class _QuantityKeypadPanelState extends State<QuantityKeypadPanel> {
  static const _columns = 4;
  static const _maxDigits = 3;

  String get _display => widget.value.isEmpty ? '1' : widget.value;

  void _appendDigit(String digit) {
    final next = widget.value + digit;
    if (next.length > _maxDigits) return;
    final parsed = int.tryParse(next);
    if (parsed == null || parsed <= 0) return;
    widget.onChanged(next);
  }

  void _backspace() {
    if (widget.value.isEmpty) return;
    final next = widget.value.substring(0, widget.value.length - 1);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      final keyGap = JtrResponsive.getResponsiveWidth(context, 6);
      var keyHeight = JtrResponsive.getResponsiveHeight(context, 42);
      if (JtrResponsive.isLargeDevice(context)) {
        keyHeight += 2;
      }
      final keyRadius = JtrResponsive.getResponsiveRadius(context, 10);

      return Container(
        color: AppTheme.keypadDialogBackground,
        padding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 12,
          vertical: 10,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gridWidth = constraints.maxWidth;
            final cellWidth = (gridWidth - keyGap * (_columns - 1)) / _columns;
            final doubleCellWidth = cellWidth * 2 + keyGap;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'QUANTITÉ',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.textSecondary,
                  ),
                ),
                JtrResponsive.getResponsiveSpacing(context, 8),
                _KeyRow(
                  keyGap: keyGap,
                  children: [
                    _ActionKey(
                      width: cellWidth,
                      height: keyHeight,
                      keyRadius: keyRadius,
                      backgroundColor: AppTheme.keypadCancelBackground,
                      onTap: widget.onClose ?? () {},
                      child: Icon(
                        Icons.close,
                        color: AppTheme.keypadCancelIcon,
                        size: JtrResponsive.getResponsiveSize(context, 20),
                      ),
                    ),
                    _DisplayField(
                      text: _display,
                      width: doubleCellWidth,
                      height: keyHeight,
                      keyRadius: keyRadius,
                      fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
                    ),
                    _ActionKey(
                      width: cellWidth,
                      height: keyHeight,
                      keyRadius: keyRadius,
                      backgroundColor: AppTheme.keypadKeyBackground,
                      onTap: _backspace,
                      child: Icon(
                        Icons.backspace_outlined,
                        color: AppTheme.keypadKeyForeground.withValues(
                          alpha: AppTheme.isDark ? 0.9 : 0.65,
                        ),
                        size: JtrResponsive.getResponsiveSize(context, 18),
                      ),
                    ),
                  ],
                ),
                _KeyRow(
                  keyGap: keyGap,
                  children: [
                    for (final digit in ['7', '8', '9'])
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: digit,
                        onTap: () => _appendDigit(digit),
                      ),
                    const SizedBox.shrink(),
                  ],
                ),
                _KeyRow(
                  keyGap: keyGap,
                  children: [
                    for (final digit in ['4', '5', '6'])
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: digit,
                        onTap: () => _appendDigit(digit),
                      ),
                    const SizedBox.shrink(),
                  ],
                ),
                _KeyRow(
                  keyGap: keyGap,
                  children: [
                    for (final digit in ['1', '2', '3'])
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: digit,
                        onTap: () => _appendDigit(digit),
                      ),
                    const SizedBox.shrink(),
                  ],
                ),
                _KeyRow(
                  keyGap: keyGap,
                  children: [
                    _CalcKey(
                      width: doubleCellWidth,
                      height: keyHeight,
                      keyRadius: keyRadius,
                      label: '0',
                      onTap: () => _appendDigit('0'),
                    ),
                    _CalcKey(
                      width: cellWidth,
                      height: keyHeight,
                      keyRadius: keyRadius,
                      label: 'C',
                      onTap: () => widget.onChanged(''),
                    ),
                  ],
                ),
              ],
            );
          },
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
    required this.keyRadius,
    this.width,
  });

  final String text;
  final double height;
  final double fontSize;
  final double keyRadius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.keypadDisplayBackground,
          borderRadius: BorderRadius.circular(keyRadius),
          border: AppTheme.isDark
              ? null
              : Border.all(color: AppTheme.keypadKeyBorder),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: AppTheme.keypadKeyForeground.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.keyGap,
    required this.children,
  });

  final double keyGap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: keyGap),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: keyGap),
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
    required this.height,
    required this.keyRadius,
    required this.label,
    required this.onTap,
  });

  final double width;
  final double height;
  final double keyRadius;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _KeySurface(
      width: width,
      height: height,
      keyRadius: keyRadius,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
          fontWeight: FontWeight.w600,
          color: AppTheme.keypadKeyForeground.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.width,
    required this.height,
    required this.keyRadius,
    required this.backgroundColor,
    required this.onTap,
    required this.child,
  });

  final double width;
  final double height;
  final double keyRadius;
  final Color backgroundColor;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _KeySurface(
      width: width,
      height: height,
      keyRadius: keyRadius,
      color: backgroundColor,
      onTap: onTap,
      child: child,
    );
  }
}

class _KeySurface extends StatelessWidget {
  const _KeySurface({
    required this.width,
    required this.height,
    required this.keyRadius,
    required this.onTap,
    required this.child,
    this.color,
  });

  final double width;
  final double height;
  final double keyRadius;
  final VoidCallback onTap;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppTheme.keypadKeyBackground,
      borderRadius: BorderRadius.circular(keyRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(keyRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: Center(child: child),
        ),
      ),
    );
  }
}
