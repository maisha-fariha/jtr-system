import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Limit-reached modal (labels exact per Stock Visuel Flow).
enum StockExhaustedAction {
  forbid,
  force,
  freeAndSell,
}

class StockExhaustedDialog extends StatelessWidget {
  const StockExhaustedDialog({
    super.key,
    required this.productName,
  });

  final String productName;

  static Future<StockExhaustedAction?> show({
    required String productName,
    BuildContext? context,
  }) {
    final dialogContext = context ?? Get.overlayContext ?? Get.context;
    if (dialogContext == null || !dialogContext.mounted) {
      return Future.value();
    }

    return showDialog<StockExhaustedAction>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
      builder: (_) => StockExhaustedDialog(productName: productName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = JtrResponsive.getResponsiveRadius(context, 20);

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
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: JtrResponsive.getResponsivePadding(
            context,
            all: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cet article est épuisé',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 8),
              Text(
                productName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 20),
              _ActionButton(
                label: 'Interdire la vente',
                foreground: AppTheme.darkText,
                background: AppTheme.dialogItemBackground,
                onTap: () => Navigator.of(context, rootNavigator: true)
                    .pop(StockExhaustedAction.forbid),
              ),
              JtrResponsive.getResponsiveSpacing(context, 10),
              _ActionButton(
                label: 'Forcer la vente',
                foreground: Colors.white,
                background: const Color(0xFFE67E22),
                onTap: () => Navigator.of(context, rootNavigator: true)
                    .pop(StockExhaustedAction.force),
              ),
              JtrResponsive.getResponsiveSpacing(context, 10),
              _ActionButton(
                label: 'Le remettre en vente',
                foreground: Colors.white,
                background: AppTheme.primary,
                onTap: () => Navigator.of(context, rootNavigator: true)
                    .pop(StockExhaustedAction.freeAndSell),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(
        JtrResponsive.getResponsiveRadius(context, 12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 12),
        ),
        child: Padding(
          padding: JtrResponsive.getResponsivePadding(
            context,
            vertical: 14,
            horizontal: 12,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
