import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class TicketLoadingDialog extends StatefulWidget {
  const TicketLoadingDialog({super.key});

  @override
  State<TicketLoadingDialog> createState() => _TicketLoadingDialogState();
}

class _TicketLoadingDialogState extends State<TicketLoadingDialog> {
  int _activeDot = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      setState(() => _activeDot = (_activeDot + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = JtrResponsive.getResponsiveSize(context, 8);
    final dotMargin = JtrResponsive.getResponsiveWidth(context, 5);

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
          horizontal: 36,
          vertical: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Veuillez patienter ...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 16),
                fontWeight: FontWeight.w500,
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.symmetric(horizontal: dotMargin),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(
                      alpha: index == _activeDot ? 1 : 0.35,
                    ),
                    shape: BoxShape.circle,
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
