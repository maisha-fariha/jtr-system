import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import 'jtr_mobile_shared_widgets.dart';

class JtrMobileProgressBarRow {
  const JtrMobileProgressBarRow({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String name;
  final double amount;
  final double percent;
  final Color color;
}

class JtrMobileProgressBarsCard extends StatelessWidget {
  const JtrMobileProgressBarsCard({
    super.key,
    required this.title,
    required this.rows,
    this.detailLabel,
    this.onDetailTap,
  });

  final String title;
  final List<JtrMobileProgressBarRow> rows;
  final String? detailLabel;
  final VoidCallback? onDetailTap;

  @override
  Widget build(BuildContext context) {
    return JtrMobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
              fontWeight: FontWeight.w600,
              color: JtrMobileTheme.textPrimary,
            ),
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 14)),
          for (var i = 0; i < rows.length; i++) ...[
            _ProgressRow(row: rows[i], colorIndex: i),
            if (i < rows.length - 1)
              SizedBox(height: JtrResponsive.getResponsiveHeight(context, 12)),
          ],
          if (detailLabel != null && onDetailTap != null) ...[
            SizedBox(height: JtrResponsive.getResponsiveHeight(context, 4)),
            JtrMobileDetailButton(label: detailLabel!, onTap: onDetailTap!),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.row, required this.colorIndex});

  final JtrMobileProgressBarRow row;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              row.name,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                color: JtrMobileTheme.textPrimary,
              ),
            ),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                  color: JtrMobileTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: JtrMobileFormatters.currency(row.amount)),
                  TextSpan(
                    text: ' ${JtrMobileFormatters.percent(row.percent)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: JtrMobileTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: JtrResponsive.getResponsiveHeight(context, 6)),
        ClipRRect(
          borderRadius: BorderRadius.circular(
            JtrResponsive.getResponsiveRadius(context, 4),
          ),
          child: LinearProgressIndicator(
            value: (row.percent / 100).clamp(0.0, 1.0),
            minHeight: JtrResponsive.getResponsiveHeight(context, 6),
            backgroundColor: JtrMobileTheme.surfaceTile,
            color: JtrMobileTheme.paletteAt(colorIndex),
          ),
        ),
      ],
    );
  }
}
