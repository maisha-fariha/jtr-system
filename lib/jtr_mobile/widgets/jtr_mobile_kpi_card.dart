import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../models/dashboard_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import 'jtr_mobile_shared_widgets.dart';

class JtrMobileKpiCard extends StatelessWidget {
  const JtrMobileKpiCard({super.key, required this.kpis});

  final JtrDashboardKpis kpis;

  @override
  Widget build(BuildContext context) {
    final trendColor =
        kpis.trendPositive ? JtrMobileTheme.success : JtrMobileTheme.danger;

    return JtrMobileCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Chiffre d'affaires",
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                    color: JtrMobileTheme.textSecondary,
                  ),
                ),
                SizedBox(height: JtrResponsive.getResponsiveHeight(context, 4)),
                Text(
                  JtrMobileFormatters.currency(kpis.revenue),
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 26),
                    fontWeight: FontWeight.w600,
                    color: JtrMobileTheme.textPrimary,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: JtrResponsive.getResponsiveHeight(context, 4)),
                Row(
                  children: [
                    Icon(
                      kpis.trendPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: JtrResponsive.getResponsiveSize(context, 14),
                      color: trendColor,
                    ),
                    SizedBox(width: JtrResponsive.getResponsiveWidth(context, 4)),
                    Text(
                      kpis.trendLabel,
                      style: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(context, 12),
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Encaissé',
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                  color: JtrMobileTheme.textSecondary,
                ),
              ),
              SizedBox(height: JtrResponsive.getResponsiveHeight(context, 4)),
              Text(
                JtrMobileFormatters.currency(kpis.collected),
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.w600,
                  color: JtrMobileTheme.textPrimary,
                ),
              ),
              SizedBox(height: JtrResponsive.getResponsiveHeight(context, 4)),
              Text(
                '${kpis.collectedPercentOfRevenue.round()}% du CA',
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                  color: JtrMobileTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
