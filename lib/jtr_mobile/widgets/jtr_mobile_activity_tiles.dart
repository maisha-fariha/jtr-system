import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../models/dashboard_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';

class JtrMobileActivityTiles extends StatelessWidget {
  const JtrMobileActivityTiles({super.key, required this.activity});

  final JtrActivityStats activity;

  @override
  Widget build(BuildContext context) {
    final gap = JtrResponsive.getResponsiveWidth(context, 10);
    return Padding(
      padding: EdgeInsets.only(
        bottom: JtrResponsive.getResponsiveHeight(context, 12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActivityTile(
              icon: Icons.receipt_long_outlined,
              label: 'Tickets',
              value: JtrMobileFormatters.integer(activity.tickets),
              sub:
                  '· ${JtrMobileFormatters.decimal(activity.avgTicket)} moy.',
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: _ActivityTile(
              icon: Icons.people_outline_rounded,
              label: 'Couverts',
              value: JtrMobileFormatters.integer(activity.covers),
              sub: '· ${JtrMobileFormatters.decimal(activity.avgCover)} moy.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final radius = JtrResponsive.getResponsiveRadius(context, 8);
    return Container(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: JtrMobileTheme.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: JtrMobileTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: JtrResponsive.getResponsiveSize(context, 26),
                height: JtrResponsive.getResponsiveSize(context, 26),
                decoration: BoxDecoration(
                  color: JtrMobileTheme.accentBg,
                  borderRadius: BorderRadius.circular(
                    JtrResponsive.getResponsiveRadius(context, 8),
                  ),
                ),
                child: Icon(
                  icon,
                  size: JtrResponsive.getResponsiveSize(context, 14),
                  color: JtrMobileTheme.accent,
                ),
              ),
              SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
              Text(
                label,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                  color: JtrMobileTheme.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 6)),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 19),
                fontWeight: FontWeight.w600,
                color: JtrMobileTheme.textPrimary,
              ),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: ' $sub',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                    fontWeight: FontWeight.w400,
                    color: JtrMobileTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
