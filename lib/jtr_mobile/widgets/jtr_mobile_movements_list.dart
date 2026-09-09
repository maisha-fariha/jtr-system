import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../models/dashboard_models.dart';
import '../theme/jtr_mobile_theme.dart';

class JtrMobileMovementsList extends StatelessWidget {
  const JtrMobileMovementsList({super.key, required this.rows});

  final List<JtrMovementRow> rows;

  @override
  Widget build(BuildContext context) {
    final radius = JtrMobileTheme.cardRadius;
    return Container(
      margin: EdgeInsets.only(
        bottom: JtrResponsive.getResponsiveHeight(context, 12),
      ),
      decoration: BoxDecoration(
        color: JtrMobileTheme.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: JtrMobileTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _MovementRow(row: rows[i]),
            if (i < rows.length - 1)
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: JtrMobileTheme.border,
                indent: JtrResponsive.getResponsiveWidth(context, 16),
                endIndent: JtrResponsive.getResponsiveWidth(context, 16),
              ),
          ],
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.row});

  final JtrMovementRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 10,
      ),
      child: Row(
        children: [
          Container(
            width: JtrResponsive.getResponsiveSize(context, 8),
            height: JtrResponsive.getResponsiveSize(context, 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: row.color,
            ),
          ),
          SizedBox(width: JtrResponsive.getResponsiveWidth(context, 10)),
          Expanded(
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                color: JtrMobileTheme.textPrimary,
              ),
            ),
          ),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: row.highlightDanger
                    ? JtrMobileTheme.danger
                    : JtrMobileTheme.textPrimary,
              ),
              children: [
                TextSpan(text: row.value),
                if (row.subValue != null)
                  TextSpan(
                    text: ' · ${row.subValue}',
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
    );
  }
}
