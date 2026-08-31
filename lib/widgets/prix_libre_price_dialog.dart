import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Asks the cashier for a unit price on prix libre (open price) products.
class PrixLibrePriceDialog extends StatefulWidget {
  const PrixLibrePriceDialog({
    super.key,
    required this.productName,
    this.onConfirm,
  });

  final String productName;
  final void Function(double unitPrice)? onConfirm;

  static Future<double?> askUnitPrice({required String productName}) async {
    double? result;
    await Get.dialog(
      PrixLibrePriceDialog(
        productName: productName,
        onConfirm: (price) => result = price,
      ),
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
    );
    return result;
  }

  @override
  State<PrixLibrePriceDialog> createState() => _PrixLibrePriceDialogState();
}

class _PrixLibrePriceDialogState extends State<PrixLibrePriceDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _parsedPrice {
    final raw = _controller.text
        .replaceAll('€', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool get _canConfirm {
    final price = _parsedPrice;
    return price != null && price > 0;
  }

  void _confirm() {
    final price = _parsedPrice;
    if (price == null || price <= 0) {
      setState(() {
        _errorText = 'Entrez un prix valide (> 0).';
      });
      return;
    }
    Get.back();
    widget.onConfirm?.call(price);
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
                        widget.productName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _dialogFontSize(context, 16),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    _HeaderIconButton(
                      backgroundColor: _canConfirm
                          ? AppTheme.lightButton
                          : AppTheme.inactiveSurface,
                      icon: Icons.check,
                      iconColor: _canConfirm
                          ? AppTheme.primary
                          : AppTheme.textSecondary.withValues(alpha: 0.4),
                      onTap: _canConfirm ? _confirm : null,
                    ),
                  ],
                ),
                JtrResponsive.getResponsiveSpacing(context, isLarge ? 16 : 14),
                Divider(height: 1, color: AppTheme.cardBorder),
                JtrResponsive.getResponsiveSpacing(context, isLarge ? 24 : 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Prix unitaire (prix libre)',
                    style: TextStyle(
                      fontSize: _dialogFontSize(context, 13),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                JtrResponsive.getResponsiveSpacing(context, 10),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
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
                    fontSize: _dialogFontSize(context, 22),
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                  ),
                  decoration: InputDecoration(
                    errorText: _errorText,
                    suffixText: '€',
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

double _dialogFontSize(BuildContext context, double base) {
  final fontSize = JtrResponsive.getResponsiveFontSize(context, base);
  if (JtrResponsive.isLargeDevice(context)) {
    return fontSize + 2;
  }
  return fontSize;
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
            size: _dialogFontSize(context, 22),
          ),
        ),
      ),
    );
  }
}
