import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/jtr_mobile_dashboard_controller.dart';
import '../data/dummy_detail_data.dart';
import '../models/detail_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import '../widgets/jtr_mobile_detail_scaffold.dart';
import '../../utils/responsive.dart';

class JtrMobileFamilySalesPage extends GetView<JtrMobileDashboardController> {
  const JtrMobileFamilySalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final periodLabel = controller.data.value.periodLabel;
    final families = JtrMobileDummyDetailData.families();

    return JtrMobileDetailScaffold(
      title: 'Ventes par famille',
      subtitle: periodLabel,
      child: Column(
        children: [
          for (var i = 0; i < families.length; i++)
            _FamilyCard(family: families[i], initiallyExpanded: i == 0),
        ],
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.initiallyExpanded,
  });

  final JtrProductFamily family;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return JtrMobileExpansionCard(
      initiallyExpanded: initiallyExpanded,
      title: Text(
        family.name,
        style: TextStyle(
          fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
          fontWeight: FontWeight.w600,
          color: JtrMobileTheme.textPrimary,
        ),
      ),
      trailing: _FamilyTrailing(
        quantity: family.totalQuantity,
        amount: family.totalAmount,
      ),
      children: [
        for (final article in family.articles) _ArticleRow(article: article),
      ],
    );
  }
}

class _FamilyTrailing extends StatelessWidget {
  const _FamilyTrailing({required this.quantity, required this.amount});

  final int quantity;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$quantity pcs',
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
            color: JtrMobileTheme.textSecondary,
          ),
        ),
        SizedBox(width: JtrResponsive.getResponsiveWidth(context, 8)),
        Text(
          JtrMobileFormatters.currency(amount),
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
            color: JtrMobileTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({required this.article});

  final JtrFamilyArticle article;

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
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                  color: JtrMobileTheme.textSecondary,
                ),
                children: [
                  TextSpan(text: article.name),
                  TextSpan(
                    text: ' ×${article.quantity}',
                    style: TextStyle(
                      fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                      color: JtrMobileTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            JtrMobileFormatters.currency(article.amount),
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
              fontWeight: FontWeight.w500,
              color: JtrMobileTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
