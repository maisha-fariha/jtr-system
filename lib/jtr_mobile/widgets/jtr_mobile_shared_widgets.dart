import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../theme/jtr_mobile_theme.dart';

class JtrMobileSectionLabel extends StatelessWidget {
  const JtrMobileSectionLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: JtrResponsive.getResponsiveWidth(context, 2),
        bottom: JtrResponsive.getResponsiveHeight(context, 6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
          color: JtrMobileTheme.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class JtrMobileCard extends StatelessWidget {
  const JtrMobileCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final radius = JtrMobileTheme.cardRadius;
    return Container(
      width: double.infinity,
      margin: margin ??
          EdgeInsets.only(bottom: JtrResponsive.getResponsiveHeight(context, 12)),
      padding: padding ??
          JtrResponsive.getResponsivePadding(
            context,
            horizontal: 16,
            vertical: 16,
          ),
      decoration: BoxDecoration(
        color: JtrMobileTheme.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: JtrMobileTheme.border, width: 0.5),
      ),
      child: child,
    );
  }
}

class JtrMobileDetailButton extends StatelessWidget {
  const JtrMobileDetailButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = JtrMobileTheme.tileRadius;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          width: double.infinity,
          padding: JtrResponsive.getResponsivePadding(context, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: JtrMobileTheme.borderStrong, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.view_list_rounded,
                size: JtrResponsive.getResponsiveSize(context, 16),
                color: JtrMobileTheme.accent,
              ),
              SizedBox(width: JtrResponsive.getResponsiveWidth(context, 6)),
              Text(
                label,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                  fontWeight: FontWeight.w600,
                  color: JtrMobileTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
