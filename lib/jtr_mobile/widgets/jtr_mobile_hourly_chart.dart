import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../models/dashboard_models.dart';
import '../theme/jtr_mobile_theme.dart';
import 'jtr_mobile_shared_widgets.dart';

class JtrMobileHourlyChart extends StatelessWidget {
  const JtrMobileHourlyChart({
    super.key,
    required this.bars,
    required this.peakCaption,
  });

  final List<JtrHourlyBar> bars;
  final String peakCaption;

  @override
  Widget build(BuildContext context) {
    final maxAmount =
        bars.fold<double>(0, (m, b) => b.amount > m ? b.amount : m);
    final chartHeight = JtrResponsive.getResponsiveHeight(context, 80);

    return JtrMobileCard(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((bar) {
                final h = maxAmount > 0
                    ? (bar.amount / maxAmount) * chartHeight
                    : 0.0;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: JtrResponsive.getResponsiveWidth(context, 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: h < 1 ? 1 : h,
                          decoration: BoxDecoration(
                            color: bar.isPeak
                                ? JtrMobileTheme.accent
                                : JtrMobileTheme.barDefault,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(
                                JtrResponsive.getResponsiveRadius(context, 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 6)),
          Row(
            children: bars.map((bar) {
              return Expanded(
                child: Text(
                  bar.hourLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 9),
                    color: bar.isPeak
                        ? JtrMobileTheme.accent
                        : JtrMobileTheme.textMuted,
                    fontWeight:
                        bar.isPeak ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 10)),
          Text(
            peakCaption,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
              color: JtrMobileTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
