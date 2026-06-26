import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_theme.dart';

class TableNumberDialog extends StatefulWidget {
  const TableNumberDialog({super.key, this.onConfirm});

  final ValueChanged<int>? onConfirm;

  static Future<void> show({ValueChanged<int>? onConfirm}) {
    return Get.dialog(
      TableNumberDialog(onConfirm: onConfirm),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
    );
  }

  @override
  State<TableNumberDialog> createState() => _TableNumberDialogState();
}

class _TableNumberDialogState extends State<TableNumberDialog> {
  String _tableInput = '';

  static const _fieldBlue = Color(0xFF1976D2);
  static const _cancelPink = Color(0xFFE57373);
  static const _keyGap = 8.0;
  static const _keyHeight = 52.0;
  static const _keyRadius = 8.0;

  void _appendDigit(String digit) {
    if (_tableInput.length >= 3) return;
    setState(() => _tableInput += digit);
  }

  void _backspace() {
    if (_tableInput.isEmpty) return;
    setState(() => _tableInput = _tableInput.substring(0, _tableInput.length - 1));
  }

  void _confirm() {
    final number = int.tryParse(_tableInput);
    if (number == null || number <= 0) return;
    Get.back();
    widget.onConfirm?.call(number);
  }

  String get _mainDisplay => _tableInput.isEmpty ? '---' : _tableInput;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            // 4 columns with 3 gaps
            final cellWidth = (totalWidth - _keyGap * 3) / 4;
            final doubleCellWidth = cellWidth * 2 + _keyGap;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                const Text(
                  'N° DE TABLE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Control row: [X]  [display]  [⌫]
                _KeyRow(gap: _keyGap, children: [
                  _ActionKey(
                    width: cellWidth,
                    height: _keyHeight,
                    radius: _keyRadius,
                    color: _cancelPink,
                    icon: Icons.close,
                    onTap: Get.back,
                  ),
                  _DisplayField(
                    width: doubleCellWidth,
                    height: _keyHeight,
                    text: _mainDisplay,
                    radius: _keyRadius,
                    color: _fieldBlue,
                    fontSize: 22,
                  ),
                  _ActionKey(
                    width: cellWidth,
                    height: _keyHeight,
                    radius: _keyRadius,
                    color: AppTheme.textMedium,
                    icon: Icons.backspace_outlined,
                    onTap: _backspace,
                  ),
                ]),
                const SizedBox(height: _keyGap),

                // 7 8 9
                _KeyRow(gap: _keyGap, children: [
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '7', onTap: () => _appendDigit('7')),
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '8', onTap: () => _appendDigit('8')),
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '9', onTap: () => _appendDigit('9')),
                  _ConfirmKey(width: cellWidth, height: _keyHeight * 2 + _keyGap, radius: _keyRadius, onTap: _tableInput.isNotEmpty ? _confirm : null),
                ]),
                const SizedBox(height: _keyGap),

                // 4 5 6
                _KeyRow(gap: _keyGap, children: [
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '4', onTap: () => _appendDigit('4')),
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '5', onTap: () => _appendDigit('5')),
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '6', onTap: () => _appendDigit('6')),
                  const SizedBox.shrink(), // confirm key spans rows
                ]),
                const SizedBox(height: _keyGap),

                // 1 2 3
                _KeyRow(gap: _keyGap, children: [
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '1', onTap: () => _appendDigit('1')),
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '2', onTap: () => _appendDigit('2')),
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '3', onTap: () => _appendDigit('3')),
                  SizedBox(width: cellWidth),
                ]),
                const SizedBox(height: _keyGap),

                // 0  .
                _KeyRow(gap: _keyGap, children: [
                  _CalcKey(width: doubleCellWidth, height: _keyHeight, radius: _keyRadius, label: '0', onTap: () => _appendDigit('0')),
                  _CalcKey(width: cellWidth, height: _keyHeight, radius: _keyRadius, label: '.', onTap: () {}),
                  SizedBox(width: cellWidth),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children, required this.gap});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i < children.length - 1) spaced.add(SizedBox(width: gap));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: spaced);
  }
}

class _DisplayField extends StatelessWidget {
  const _DisplayField({
    required this.width,
    required this.height,
    required this.text,
    required this.radius,
    required this.color,
    required this.fontSize,
  });

  final double width;
  final double height;
  final String text;
  final double radius;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _CalcKey extends StatelessWidget {
  const _CalcKey({
    required this.width,
    required this.height,
    required this.radius,
    required this.label,
    required this.onTap,
  });

  final double width;
  final double height;
  final double radius;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _KeySurface(
      width: width,
      height: height,
      radius: radius,
      color: AppTheme.background,
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _KeySurface(
      width: width,
      height: height,
      radius: radius,
      color: color,
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _ConfirmKey extends StatelessWidget {
  const _ConfirmKey({
    required this.width,
    required this.height,
    required this.radius,
    required this.onTap,
  });

  final double width;
  final double height;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return _KeySurface(
      width: width,
      height: height,
      radius: radius,
      color: enabled ? AppTheme.primary : AppTheme.border,
      onTap: onTap ?? () {},
      child: Icon(
        Icons.check,
        color: enabled ? Colors.white : AppTheme.textLight,
        size: 26,
      ),
    );
  }
}

class _KeySurface extends StatelessWidget {
  const _KeySurface({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.onTap,
    required this.child,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
