import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../models/session_order.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Statistics summary for the current session.
/// Accessed via the STATISTICS action button on the session page.
class StatisticsPage extends GetView<SessionController> {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.connectBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppTheme.darkText,
            size: JtrResponsive.getResponsiveSize(context, 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'STATISTIQUES',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoadingStatistics.value &&
            controller.dayStatistics.value == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final stats = controller.dayStatistics.value;
        final orders = controller.orders;
        final totalRevenue = stats?.totalRevenue ??
            orders.fold<double>(0, (sum, o) => sum + _parseTotal(o.total));
        final openTables =
            stats != null && stats.openTables > 0 ? stats.openTables : orders.length;
        final printedTickets = stats?.printedTickets ??
            orders.where((o) => o.impressionCount > 0).length;
        final avgPerTable = stats?.averagePerTable ??
            (openTables > 0 ? totalRevenue / openTables : 0.0);

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () => controller.loadDayStatistics(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 20,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'REVENU TOTAL',
                        value: _formatDisplayTotal(
                          stats?.formattedTotalRevenue,
                          totalRevenue,
                        ),
                        icon: Icons.euro_symbol_rounded,
                        iconColor: AppTheme.primary,
                      ),
                    ),
                    JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
                    Expanded(
                      child: _KpiCard(
                        label: 'TABLES OUVERTES',
                        value: '$openTables',
                        icon: Icons.table_restaurant_outlined,
                        iconColor: const Color(0xFF4A90D9),
                      ),
                    ),
                  ],
                ),
                JtrResponsive.getResponsiveSpacing(context, 12),
                Row(
                  children: [
                    Expanded(
                      child: _KpiCard(
                        label: 'TICKETS IMPRIMÉS',
                        value: '$printedTickets',
                        icon: Icons.receipt_long_outlined,
                        iconColor: const Color(0xFF5BAD6F),
                      ),
                    ),
                    JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
                    Expanded(
                      child: _KpiCard(
                        label: 'MOY. PAR TABLE',
                        value: _formatDisplayTotal(
                          stats?.formattedAveragePerTable,
                          avgPerTable,
                        ),
                        icon: Icons.bar_chart_rounded,
                        iconColor: const Color(0xFFE8A838),
                      ),
                    ),
                  ],
                ),
                JtrResponsive.getResponsiveSpacing(context, 28),
                const _SectionTitle(text: 'DÉTAIL PAR TABLE'),
                JtrResponsive.getResponsiveSpacing(context, 12),
                if (orders.isEmpty)
                  const _EmptyState()
                else
                  for (final order in orders) ...[
                    _OrderStatRow(order: order),
                    JtrResponsive.getResponsiveSpacing(context, 10),
                  ],
              ],
            ),
          ),
        );
      }),
    );
  }

  String _formatDisplayTotal(String? fromApi, double fallback) {
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
    return _formatTotal(fallback);
  }

  double _parseTotal(String total) {
    return double.tryParse(
          total.replaceAll(' €', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  String _formatTotal(double value) {
    final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
    return '$formatted €';
  }
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = JtrResponsive.getResponsiveSize(context, 36);

    return Container(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 16),
        ),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: JtrResponsive.getResponsiveSize(context, 8),
            offset: Offset(
              0,
              JtrResponsive.getResponsiveHeight(context, 2),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(
                JtrResponsive.getResponsiveRadius(context, 10),
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: JtrResponsive.getResponsiveSize(context, 20),
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 12),
          Text(
            value,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
              height: 1.1,
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 4),
          Text(
            label,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 9),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppTheme.textSecondary.withValues(alpha: 0.8),
      ),
    );
  }
}

// ─── Order Stat Row ────────────────────────────────────────────────────────────

class _OrderStatRow extends StatelessWidget {
  const _OrderStatRow({required this.order});

  final SessionOrder order;

  @override
  Widget build(BuildContext context) {
    final badgeSize = JtrResponsive.getResponsiveSize(context, 40);

    return Container(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 12),
        ),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: JtrResponsive.getResponsiveSize(context, 4),
            offset: Offset(
              0,
              JtrResponsive.getResponsiveHeight(context, 1),
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: order.numberColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(
                JtrResponsive.getResponsiveRadius(context, 10),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              order.number,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                fontWeight: FontWeight.bold,
                color: order.numberColor,
              ),
            ),
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.products.length} article${order.products.length != 1 ? 's' : ''}  •  Gr. ${order.group}  •  ${order.poste}',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                JtrResponsive.getResponsiveSpacing(context, 2),
                Text(
                  order.profitCenter,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkText,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order.total,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 4),
              Container(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: order.impressionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    JtrResponsive.getResponsiveRadius(context, 8),
                  ),
                ),
                child: Text(
                  '${order.impressionCount} IMP.',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 9),
                    fontWeight: FontWeight.bold,
                    color: order.impressionColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: JtrResponsive.getResponsivePadding(context, vertical: 48),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 16),
        ),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: JtrResponsive.getResponsiveSize(context, 48),
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
          JtrResponsive.getResponsiveSpacing(context, 12),
          Text(
            'Aucune commande en cours.',
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
