import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

class JtrMobileDashboardPage extends GetView<JtrMobileDashboardController> {
  const JtrMobileDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JtrMobileTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: JtrMobileTheme.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: JtrMobileTheme.textPrimary,
            size: JtrResponsive.getResponsiveSize(context, 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'JTR Mobile',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: JtrResponsive.getResponsiveFontSize(context, 17),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        final data = controller.data.value;
        final refreshing = controller.isRefreshing.value;

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
                      JtrResponsive.getResponsiveHeight(context, 32),
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
                            if (controller.chatOpen.value)
                              const JtrMobileChatPanel(),
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
                              expanded: controller.periodOpen.value,
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
                            _Footer(),
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
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: JtrMobileTheme.border, height: 0.5, thickness: 0.5),
        SizedBox(height: JtrResponsive.getResponsiveHeight(context, 16)),
        Text(
          'All rights and license granted by JTR Innovation.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
            color: JtrMobileTheme.textMuted,
            height: 1.5,
          ),
        ),
        Text(
          'Contact: +212 8 08 58 51 28 / +212 6 66 44 43 30',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
            color: JtrMobileTheme.textMuted,
            height: 1.5,
          ),
        ),
        Text(
          'contact.jtrinnovation@gmail.com',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
            color: JtrMobileTheme.warning,
            decoration: TextDecoration.underline,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
