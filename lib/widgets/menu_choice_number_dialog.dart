import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Callback with the menu quantity (how many menus to add), not CHOIX picks.
typedef MenuChoiceNumberCallback = void Function(int quantity);

/// Asks for menu quantity before opening CHOIX selection.
class MenuChoiceNumberDialog extends StatefulWidget {
  const MenuChoiceNumberDialog({
    super.key,
    required this.menuLabel,
    this.onConfirm,
    this.initialQuantity = 1,
  });

  final String menuLabel;
  final MenuChoiceNumberCallback? onConfirm;
  final int initialQuantity;

  static Future<void> show({
    required String menuLabel,
    MenuChoiceNumberCallback? onConfirm,
    int initialQuantity = 1,
  }) {
    return Get.dialog(
      MenuChoiceNumberDialog(
        menuLabel: menuLabel,
        onConfirm: onConfirm,
        initialQuantity: initialQuantity,
      ),
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
    );
  }

  /// Returns a positive quantity, or `null` if dismissed.
  static Future<int?> askQuantity({
    required String menuLabel,
    int initialQuantity = 1,
  }) async {
    int? result;
    await show(
      menuLabel: menuLabel,
      initialQuantity: initialQuantity,
      onConfirm: (quantity) => result = quantity,
    );
    return result;
  }

  @override
  State<MenuChoiceNumberDialog> createState() => _MenuChoiceNumberDialogState();
}

class _MenuChoiceNumberDialogState extends State<MenuChoiceNumberDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialQuantity > 0 ? widget.initialQuantity : 1;
    _controller = TextEditingController(text: '$initial');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _parsedQuantity {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  bool get _canConfirm {
    final qty = _parsedQuantity;
    return qty != null && qty > 0;
  }

  void _confirm() {
    final qty = _parsedQuantity;
    if (qty == null || qty < 1) {
      setState(() {
        _errorText = 'Entrez une quantité positive.';
      });
      return;
    }
    Get.back();
    widget.onConfirm?.call(qty);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      final isLarge = JtrResponsive.isLargeDevice(context);
      final dialogRadius = JtrResponsive.getResponsiveRadius(
        context,
        isLarge ? 24 : 16,
      );
      final maxDialogWidth = JtrResponsive.getResponsiveWidth(
        context,
        isLarge ? 480 : 400,
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
                          fontSize: _qtyDialogFontSize(context, 16),
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
                      onTap: _canConfirm ? _confirm : null,
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quantité',
                    style: TextStyle(
                      fontSize: _qtyDialogFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                JtrResponsive.getResponsiveSpacing(context, 10),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    } else {
                      setState(() {});
                    }
                  },
                  onSubmitted: (_) {
                    if (_canConfirm) _confirm();
                  },
                  style: TextStyle(
                    fontSize: _qtyDialogFontSize(context, 22),
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                  ),
                  decoration: InputDecoration(
                    hintText: '1',
                    errorText: _errorText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        JtrResponsive.getResponsiveRadius(context, 12),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        JtrResponsive.getResponsiveRadius(context, 12),
                      ),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        JtrResponsive.getResponsiveRadius(context, 12),
                      ),
                      borderSide: BorderSide(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: JtrResponsive.getResponsivePadding(
                      context,
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

double _qtyDialogFontSize(BuildContext context, double base) {
  final fontSize = JtrResponsive.getResponsiveFontSize(context, base);
  if (JtrResponsive.isLargeDevice(context)) {
    return fontSize + 2;
  }
  return fontSize;
}

double _qtyDialogIconSize(BuildContext context, double base) {
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
            size: _qtyDialogIconSize(context, 22),
          ),
        ),
      ),
    );
  }
}
