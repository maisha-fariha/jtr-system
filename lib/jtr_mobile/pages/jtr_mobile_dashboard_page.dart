import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/app_footer.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive.dart';
import '../controllers/jtr_mobile_dashboard_controller.dart';
import '../theme/jtr_mobile_theme.dart';
import '../widgets/jtr_mobile_activity_tiles.dart';
import '../widgets/jtr_mobile_chat_panel.dart';
import '../widgets/jtr_mobile_gap_donut_card.dart';
import '../widgets/jtr_mobile_header.dart';
import '../widgets/jtr_mobile_hourly_chart.dart';
import '../widgets/jtr_mobile_kpi_card.dart';
import '../widgets/jtr_mobile_movements_list.dart';
import '../widgets/jtr_mobile_payment_grid.dart';
import '../widgets/jtr_mobile_period_picker.dart';
import '../widgets/jtr_mobile_progress_bars_card.dart';
import '../widgets/jtr_mobile_shared_widgets.dart';
import '../widgets/jtr_mobile_theme_scope.dart';

class JtrMobileDashboardPage extends GetView<JtrMobileDashboardController> {
  const JtrMobileDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return JtrMobileThemeScope(
      builder: (context) => Scaffold(
      backgroundColor: JtrMobileTheme.pageBackground,
      body: SafeArea(
        child: Obx(() {
        final data = controller.data.value;
        final loading = controller.isLoading.value;
        final refreshing = controller.isRefreshing.value;
        final chatOpen = controller.chatOpen.value;
        final periodOpen = controller.periodOpen.value;

        if (loading && data == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (data == null) {
          return Center(
            child: Padding(
              padding: JtrResponsive.getResponsivePadding(
                context,
                horizontal: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Impossible de charger le tableau de bord.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 14),
                      color: JtrMobileTheme.textSecondary,
                    ),
                  ),
                  SizedBox(
                    height: JtrResponsive.getResponsiveHeight(context, 16),
                  ),
                  FilledButton(
                    onPressed: controller.refreshDashboard,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: controller.refreshDashboard,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = JtrMobileTheme.dashboardMaxWidth(context);
                  final hPad = JtrResponsive.getResponsivePadding(
                    context,
                    horizontal: 16,
                  ).horizontal;

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      hPad / 2,
                      JtrResponsive.getResponsiveHeight(context, 8),
                      hPad / 2,
                      JtrResponsive.getResponsiveHeight(context, 8),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            JtrMobileHeader(
                              storeName: data.storeName,
                              dateLabel: data.dateLabel,
                              onChatTap: controller.toggleChat,
                              onThemeTap: controller.toggleTheme,
                            ),
                            if (chatOpen) const JtrMobileChatPanel(),
                            JtrMobileKpiCard(kpis: data.kpis),
                            const JtrMobileSectionLabel(
                              text: 'Mode de paiement',
                            ),
                            JtrMobilePaymentGrid(items: data.payments),
                            JtrMobileGapDonutCard(
                              segments: data.gapSegments,
                              total: data.gapTotal,
                              onDetailTap: controller.onGapDetailTap,
                            ),
                            JtrMobileProgressBarsCard(
                              title: "Chiffre d'affaires par catégorie",
                              rows: data.categories
                                  .map(
                                    (c) => JtrMobileProgressBarRow(
                                      name: c.name,
                                      amount: c.amount,
                                      percent: c.percent,
                                      color: c.color,
                                    ),
                                  )
                                  .toList(),
                              detailLabel:
                                  'Voir détail par famille et article',
                              onDetailTap: controller.onFamilyDetailTap,
                            ),
                            JtrMobileProgressBarsCard(
                              title: "Chiffre d'affaires par zone",
                              rows: data.zones
                                  .map(
                                    (z) => JtrMobileProgressBarRow(
                                      name: z.name,
                                      amount: z.amount,
                                      percent: z.percent,
                                      color: z.color,
                                    ),
                                  )
                                  .toList(),
                            ),
                            const JtrMobileSectionLabel(text: 'Activité'),
                            JtrMobileActivityTiles(activity: data.activity),
                            const JtrMobileSectionLabel(
                              text: 'Notes et mouvements',
                            ),
                            JtrMobileMovementsList(rows: data.movements),
                            JtrMobileSectionLabel(
                              text:
                                  "Chiffre d'affaires par heure · aujourd'hui",
                            ),
                            JtrMobileHourlyChart(
                              bars: data.hourlyBars,
                              peakCaption: data.peakCaption,
                            ),
                            SizedBox(
                              height: JtrResponsive.getResponsiveHeight(
                                context,
                                12,
                              ),
                            ),
                            const JtrMobileSectionLabel(
                              text: 'Consulter une autre période',
                            ),
                            JtrMobilePeriodPicker(
                              expanded: periodOpen,
                              from: controller.periodFrom,
                              to: controller.periodTo,
                              onToggle: controller.togglePeriod,
                              onApply: controller.applyPeriod,
                            ),
                            SizedBox(
                              height: JtrResponsive.getResponsiveHeight(
                                context,
                                20,
                              ),
                            ),
                            const AppFooter(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (refreshing)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppTheme.primary,
                  backgroundColor: Colors.transparent,
                ),
              ),
          ],
        );
      }),
      ),
      ),
    );
  }
}
