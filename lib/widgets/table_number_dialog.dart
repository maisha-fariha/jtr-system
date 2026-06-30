import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class TableNumberDialog extends StatefulWidget {
  const TableNumberDialog({
    super.key,
    this.title = 'N° DE TABLE',
    this.initialValue,
    this.integerOnly = false,
    this.maxDigits,
    this.onConfirm,
  });

  final String title;
  final String? initialValue;
  final bool integerOnly;
  final int? maxDigits;
  final ValueChanged<String>? onConfirm;

  static Future<void> show({
    String title = 'N° DE TABLE',
    String? initialValue,
    bool integerOnly = false,
    int? maxDigits,
    ValueChanged<String>? onConfirm,
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
      builder: (_) => TableNumberDialog(
        title: title,
        initialValue: initialValue,
        integerOnly: integerOnly,
        maxDigits: maxDigits,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<TableNumberDialog> createState() => _TableNumberDialogState();
}

class _TableNumberDialogState extends State<TableNumberDialog> {
  static const _columns = 4;

  late String _tableInput;

  @override
  void initState() {
    super.initState();
    _tableInput = widget.initialValue ?? '';
  }

  String get _emptyPlaceholder => widget.integerOnly ? '0' : '---';

  String get _mainDisplay =>
      _tableInput.isEmpty ? _emptyPlaceholder : _tableInput;

  void _appendDigit(String value) {
    if (widget.integerOnly && value == '.') return;
    if (widget.maxDigits != null &&
        value != '.' &&
        _tableInput.length >= widget.maxDigits!) {
      return;
    }
    setState(() => _tableInput += value);
  }

  void _clear() {
    if (_tableInput.isEmpty) return;
    setState(() => _tableInput = '');
  }

  void _backspace() {
    if (_tableInput.isEmpty) return;
    setState(() => _tableInput = _tableInput.substring(0, _tableInput.length - 1));
  }

  void _confirm() {
    final value = _tableInput.isEmpty && widget.integerOnly
        ? '0'
        : _tableInput;
    if (value.isEmpty) return;
    if (widget.integerOnly && int.tryParse(value) == null) return;
    Get.back();
    Future.microtask(() => widget.onConfirm?.call(value));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      final keyGap = JtrResponsive.getResponsiveWidth(context, 6);
      var keyHeight = JtrResponsive.getResponsiveHeight(context, 54);
      if (JtrResponsive.isLargeDevice(context)) {
        keyHeight += 4;
      }
      final keyRadius = JtrResponsive.getResponsiveRadius(context, 12);
      final isDark = AppTheme.isDark;

      return Dialog(
        backgroundColor: AppTheme.keypadDialogBackground,
        insetPadding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 28,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            JtrResponsive.getResponsiveRadius(context, 32),
          ),
        ),
        child: Padding(
          padding: JtrResponsive.getResponsivePadding(
            context,
            horizontal: 18,
            vertical: 22,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gridWidth = constraints.maxWidth;
              final cellWidth = (gridWidth - keyGap * (_columns - 1)) / _columns;
              final doubleCellWidth = cellWidth * 2 + keyGap;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: JtrResponsive.getResponsiveFontSize(
                        context,
                        17,
                      ),
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.primary : AppTheme.darkText,
                      letterSpacing: 0.4,
                    ),
                  ),
                  JtrResponsive.getResponsiveSpacing(context, 18),
                  _KeyRow(
                    keyGap: keyGap,
                    children: [
                      _ActionKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        backgroundColor: AppTheme.keypadCancelBackground,
                        onTap: () => Get.back(),
                        child: Icon(
                          Icons.close,
                          color: AppTheme.keypadCancelIcon,
                          size: JtrResponsive.getResponsiveSize(context, 22),
                        ),
                      ),
                      _DisplayField(
                        text: _mainDisplay,
                        width: doubleCellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        fontSize: JtrResponsive.getResponsiveFontSize(
                          context,
                          20,
                        ),
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
                          size: JtrResponsive.getResponsiveSize(context, 20),
                        ),
                      ),
                    ],
                  ),
                  _KeyRow(
                    keyGap: keyGap,
                    children: [
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '7',
                        onTap: () => _appendDigit('7'),
                      ),
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '8',
                        onTap: () => _appendDigit('8'),
                      ),
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '9',
                        onTap: () => _appendDigit('9'),
                      ),
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: widget.integerOnly ? 'C' : '/',
                        onTap: widget.integerOnly ? _clear : () {},
                      ),
                    ],
                  ),
                  _KeyRow(
                    keyGap: keyGap,
                    children: [
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '4',
                        onTap: () => _appendDigit('4'),
                      ),
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '5',
                        onTap: () => _appendDigit('5'),
                      ),
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '6',
                        onTap: () => _appendDigit('6'),
                      ),
                      if (widget.integerOnly)
                        SizedBox(width: cellWidth, height: keyHeight)
                      else
                        _CalcKey(
                          width: cellWidth,
                          height: keyHeight,
                          keyRadius: keyRadius,
                          label: '*',
                          onTap: () {},
                        ),
                    ],
                  ),
                  _KeyRow(
                    keyGap: keyGap,
                    children: [
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '1',
                        onTap: () => _appendDigit('1'),
                      ),
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '2',
                        onTap: () => _appendDigit('2'),
                      ),
                      _CalcKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        label: '3',
                        onTap: () => _appendDigit('3'),
                      ),
                      if (widget.integerOnly)
                        SizedBox(width: cellWidth, height: keyHeight)
                      else
                        _CalcKey(
                          width: cellWidth,
                          height: keyHeight,
                          keyRadius: keyRadius,
                          label: '-',
                          onTap: () {},
                        ),
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
                      if (!widget.integerOnly)
                        _CalcKey(
                          width: cellWidth,
                          height: keyHeight,
                          keyRadius: keyRadius,
                          label: '.',
                          onTap: () => _appendDigit('.'),
                        )
                      else
                        SizedBox(width: cellWidth),
                      _ConfirmKey(
                        width: cellWidth,
                        height: keyHeight,
                        keyRadius: keyRadius,
                        onTap: _tableInput.isEmpty && !widget.integerOnly
                            ? null
                            : _confirm,
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
    final isDark = AppTheme.isDark;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.keypadDisplayBackground,
          borderRadius: BorderRadius.circular(keyRadius),
          border: isDark ? null : Border.all(color: AppTheme.keypadKeyBorder),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppTheme.keypadKeyForeground.withValues(
                alpha: text == '---' || text == '0' ? 0.35 : 0.9,
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
          fontSize: JtrResponsive.getResponsiveFontSize(context, 20),
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
      onTap: onTap,
      color: backgroundColor,
      child: child,
    );
  }
}

class _ConfirmKey extends StatelessWidget {
  const _ConfirmKey({
    required this.width,
    required this.height,
    required this.keyRadius,
    required this.onTap,
  });

  final double width;
  final double height;
  final double keyRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final isDark = AppTheme.isDark;
    final buttonColor = isDark || isEnabled
        ? AppTheme.primary
        : AppTheme.primary.withValues(alpha: 0.45);
    final iconContainerSize = JtrResponsive.getResponsiveSize(context, 28);
    final checkIconSize = JtrResponsive.getResponsiveSize(context, 16);

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: buttonColor,
        borderRadius: BorderRadius.circular(keyRadius),
        elevation: isEnabled && !isDark ? 5 : 0,
        shadowColor: AppTheme.primary.withValues(alpha: 0.45),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(keyRadius),
          child: Center(
            child: isDark
                ? Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    decoration: BoxDecoration(
                      color: AppTheme.keypadDialogBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppTheme.primary,
                      size: checkIconSize,
                    ),
                  )
                : Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.check,
                      color: AppTheme.primary,
                      size: checkIconSize,
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
    final keyColor = color ?? AppTheme.keypadKeyBackground;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: keyColor,
        borderRadius: BorderRadius.circular(keyRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(keyRadius),
          child: Center(child: child),
        ),
      ),
    );
  }
}
