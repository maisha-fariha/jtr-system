import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/jtr_mobile_dashboard_controller.dart';
import '../models/detail_models.dart';
import '../theme/jtr_mobile_theme.dart';
import '../utils/jtr_mobile_formatters.dart';
import '../widgets/jtr_mobile_detail_scaffold.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';

class JtrMobileFamilySalesPage extends StatefulWidget {
  const JtrMobileFamilySalesPage({super.key});

  @override
  State<JtrMobileFamilySalesPage> createState() =>
      _JtrMobileFamilySalesPageState();
}

class _JtrMobileFamilySalesPageState extends State<JtrMobileFamilySalesPage> {
  JtrMobileDashboardController get controller =>
      Get.find<JtrMobileDashboardController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadProductFamilies();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final periodLabel = controller.data.value?.periodLabel ?? '';
      final loading = controller.isFamiliesLoading.value;
      final families = controller.productFamilies;

      return JtrMobileDetailScaffold(
        title: 'Ventes par famille',
        subtitle: periodLabel,
        child: loading && families.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            : families.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: JtrResponsive.getResponsiveHeight(context, 32),
                    ),
                    child: Text(
                      'Aucune vente pour cette période.',
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
                      for (var i = 0; i < families.length; i++)
                        _FamilyCard(
                          family: families[i],
                          initiallyExpanded: i == 0,
                        ),
                    ],
                  ),
      );
    });
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
          '${JtrMobileFormatters.integer(quantity)} pcs',
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
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 11),
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
