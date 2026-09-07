import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/jtr_mobile_dashboard_controller.dart';
import '../data/dummy_detail_data.dart';
import '../models/detail_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import '../widgets/jtr_mobile_detail_scaffold.dart';
import '../../utils/responsive.dart';

class JtrMobileGapDetailPage extends GetView<JtrMobileDashboardController> {
  const JtrMobileGapDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final periodLabel = controller.data.value.periodLabel;
    final categories = JtrMobileDummyDetailData.gapCategories();

    return JtrMobileDetailScaffold(
      title: "Détail de l'écart",
      subtitle: periodLabel,
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++)
            _GapCategoryCard(
              category: categories[i],
              initiallyExpanded: i == 0,
            ),
        ],
      ),
    );
  }
}

class _GapCategoryCard extends StatelessWidget {
  const _GapCategoryCard({
    required this.category,
    required this.initiallyExpanded,
  });

  final JtrGapCategoryDetail category;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return JtrMobileExpansionCard(
      initiallyExpanded: initiallyExpanded,
      title: Row(
        children: [
          Container(
            width: JtrResponsive.getResponsiveSize(context, 8),
            height: JtrResponsive.getResponsiveSize(context, 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: category.color,
            ),
          ),
          SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
          Text(
            category.label,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
              fontWeight: FontWeight.w600,
              color: JtrMobileTheme.textPrimary,
            ),
          ),
        ],
      ),
      trailing: Text(
        JtrMobileFormatters.currency(category.totalAmount),
        style: TextStyle(
          fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
          color: JtrMobileTheme.textSecondary,
        ),
      ),
      children: [
        for (final txn in category.transactions) _TxnRow(txn: txn),
        const JtrMobileTxnFooterNote(),
      ],
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.txn});

  final JtrGapTransaction txn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: JtrMobileTheme.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            txn.meta,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 10),
              color: JtrMobileTheme.textMuted,
            ),
          ),
          SizedBox(height: JtrResponsive.getResponsiveHeight(context, 3)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TxnLeft(txn: txn)),
              _TxnAmount(txn: txn),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxnLeft extends StatelessWidget {
  const _TxnLeft({required this.txn});

  final JtrGapTransaction txn;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: JtrResponsive.getResponsiveWidth(context, 4),
      runSpacing: 4,
      children: [
        Text(
          txn.label,
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
            color: JtrMobileTheme.textPrimary,
          ),
        ),
        if (txn.quantity != null)
          Text(
            '×${txn.quantity}',
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
              color: JtrMobileTheme.textMuted,
            ),
          ),
        if (txn.tag != null)
          Container(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 7,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: JtrMobileTheme.surfaceTile,
              borderRadius: BorderRadius.circular(
                JtrResponsive.getResponsiveRadius(context, 10),
              ),
            ),
            child: Text(
              txn.tag!,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 10),
                color: JtrMobileTheme.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _TxnAmount extends StatelessWidget {
  const _TxnAmount({required this.txn});

  final JtrGapTransaction txn;

  @override
  Widget build(BuildContext context) {
    final amount = txn.amount.toStringAsFixed(2).replaceAll('.', ',');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (txn.discountPercent != null) ...[
          Text(
            '-${txn.discountPercent}%',
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
              fontWeight: FontWeight.w600,
              color: JtrMobileTheme.warning,
            ),
          ),
          SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
        ],
        Text(
          '$amount DH',
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
            fontWeight: FontWeight.w600,
            color: JtrMobileTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
