import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/jtr_mobile_dashboard_controller.dart';
import '../models/detail_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import '../widgets/jtr_mobile_detail_scaffold.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';

class JtrMobileGapDetailPage extends StatefulWidget {
  const JtrMobileGapDetailPage({super.key});

  @override
  State<JtrMobileGapDetailPage> createState() => _JtrMobileGapDetailPageState();
}

class _JtrMobileGapDetailPageState extends State<JtrMobileGapDetailPage> {
  JtrMobileDashboardController get controller =>
      Get.find<JtrMobileDashboardController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadGapCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final periodLabel = controller.data.value?.periodLabel ?? '';
      final loading = controller.isGapLoading.value;
      final categories = controller.gapCategories;

      return JtrMobileDetailScaffold(
        title: "Détail de l'écart",
        subtitle: periodLabel,
        child: loading && categories.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            : categories.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: JtrResponsive.getResponsiveHeight(context, 32),
                    ),
                    child: Text(
                      'Aucune opération pour cette période.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(context, 13),
                        color: JtrMobileTheme.textMuted,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < categories.length; i++)
                        _GapCategoryCard(
                          category: categories[i],
                          initiallyExpanded: i == 0,
                        ),
                    ],
                  ),
      );
    });
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
              color: JtrMobileTheme.gapColorForLabel(category.label),
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
          JtrMobileFormatters.currency(txn.amount),
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
