import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class TicketSuccessDialog extends StatefulWidget {
  const TicketSuccessDialog({super.key});

  @override
  State<TicketSuccessDialog> createState() => _TicketSuccessDialogState();
}

class _TicketSuccessDialogState extends State<TicketSuccessDialog> {
  static const _initialSeconds = 3;

  int _secondsRemaining = _initialSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining <= 1) {
        _timer?.cancel();
        if (mounted) Get.back();
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = JtrResponsive.getResponsiveSize(context, 56);

    return Dialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 20),
        ),
      ),
      child: Padding(
        padding: JtrResponsive.getResponsivePadding(
          context,
          left: 24,
          right: 24,
          top: 28,
          bottom: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: AppTheme.lightButton,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: AppTheme.primary,
                size: JtrResponsive.getResponsiveSize(context, 30),
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 20),
            Text(
              "L'impression a été effectuée sur l'imprimante principale TICKET.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
                height: 1.4,
                color: AppTheme.darkText,
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'OK (${_secondsRemaining}S)',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: JtrResponsive.getResponsiveFontSize(
                      context,
                      15,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
