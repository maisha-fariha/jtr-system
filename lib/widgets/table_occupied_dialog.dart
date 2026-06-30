import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class TableOccupiedDialog extends StatelessWidget {
  const TableOccupiedDialog({
    super.key,
    required this.userName,
    required this.tableNumber,
  });

  final String userName;
  final String tableNumber;

  static Future<void> show({
    required String userName,
    required String tableNumber,
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
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => TableOccupiedDialog(
        userName: userName,
        tableNumber: tableNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 36,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: JtrResponsive.getResponsiveHeight(context, 36),
            ),
            padding: JtrResponsive.getResponsivePadding(
              context,
              left: 24,
              right: 24,
              top: 52,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(
                JtrResponsive.getResponsiveRadius(context, 28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: JtrResponsive.getResponsiveWidth(context, 24),
                  offset: Offset(
                    0,
                    JtrResponsive.getResponsiveHeight(context, 8),
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Table occupée',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(
                      context,
                      20,
                    ),
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                  ),
                ),
                JtrResponsive.getResponsiveSpacing(context, 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: JtrResponsive.getResponsiveFontSize(
                        context,
                        15,
                      ),
                      height: 1.45,
                      color: AppTheme.darkText.withValues(alpha: 0.85),
                    ),
                    children: [
                      TextSpan(
                        text: userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const TextSpan(
                        text:
                            ' n\'est pas autorisé à travailler sur la table ',
                      ),
                      TextSpan(
                        text: tableNumber,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                JtrResponsive.getResponsiveSpacing(context, 28),
                SizedBox(
                  width: double.infinity,
                  height: JtrResponsive.getResponsiveHeight(context, 50),
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          JtrResponsive.getResponsiveRadius(context, 14),
                        ),
                      ),
                      textStyle: TextStyle(
                        fontSize: JtrResponsive.getResponsiveFontSize(
                          context,
                          16,
                        ),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            child: _OccupiedIcon(),
          ),
        ],
      ),
    );
  }
}

class _OccupiedIcon extends StatelessWidget {
  const _OccupiedIcon();

  @override
  Widget build(BuildContext context) {
    final outerSize = JtrResponsive.getResponsiveSize(context, 72);
    final middleSize = JtrResponsive.getResponsiveSize(context, 56);
    final innerSize = JtrResponsive.getResponsiveSize(context, 44);

    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.background,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: JtrResponsive.getResponsiveWidth(context, 12),
            offset: Offset(
              0,
              JtrResponsive.getResponsiveHeight(context, 4),
            ),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: middleSize,
          height: middleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary, width: 2.5),
          ),
          child: Center(
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: JtrResponsive.getResponsiveSize(context, 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
