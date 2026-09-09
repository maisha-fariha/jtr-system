import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../models/dashboard_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';

class JtrMobilePaymentGrid extends StatelessWidget {
  const JtrMobilePaymentGrid({super.key, required this.items});

  final List<JtrPaymentBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: JtrResponsive.getResponsiveHeight(context, 12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = JtrResponsive.getResponsiveWidth(context, 8);
          final tileWidth = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items
                .map(
                  (item) => SizedBox(
                    width: tileWidth,
                    child: _PaymentTile(item: item),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.item});

  final JtrPaymentBreakdownItem item;

  @override
  Widget build(BuildContext context) {
    final radius = JtrMobileTheme.tileRadius;
    return Container(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 6,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: JtrMobileTheme.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: JtrMobileTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
              color: JtrMobileTheme.textSecondary,
            ),
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 4)),
          Text(
            JtrMobileFormatters.currency(item.amount),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
              fontWeight: FontWeight.w600,
              color: JtrMobileTheme.textPrimary,
            ),
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 2)),
          Text(
            JtrMobileFormatters.percent(item.percent),
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 10),
              color: JtrMobileTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
