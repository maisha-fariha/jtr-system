import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../models/session_order.dart';
import '../utils/app_theme.dart';

/// Statistics summary for the current session.
/// Accessed via the STATISTICS action button on the session page.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();

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
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'STATISTIQUES',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Obx(() {
        final orders = session.orders;
        final totalRevenue = orders.fold<double>(
          0,
          (sum, o) => sum + _parseTotal(o.total),
        );
        final openTables = orders.length;
        final printedTickets =
            orders.where((o) => o.impressionCount > 0).length;
        final avgPerTable =
            openTables > 0 ? totalRevenue / openTables : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── KPI Cards row ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      label: 'REVENU TOTAL',
                      value: _formatTotal(totalRevenue),
                      icon: Icons.euro_symbol_rounded,
                      iconColor: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
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
              const SizedBox(height: 12),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      label: 'MOY. PAR TABLE',
                      value: _formatTotal(avgPerTable),
                      icon: Icons.bar_chart_rounded,
                      iconColor: const Color(0xFFE8A838),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // ── Per-table breakdown ───────────────────────────────────────
              const _SectionTitle(text: 'DÉTAIL PAR TABLE'),
              const SizedBox(height: 12),
              if (orders.isEmpty)
                const _EmptyState()
              else
                for (final order in orders) ...[
                  _OrderStatRow(order: order),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      }),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
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
        fontSize: 11,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Table badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: order.numberColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              order.number,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: order.numberColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.products.length} article${order.products.length != 1 ? 's' : ''}  •  Gr. ${order.group}  •  ${order.poste}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.profitCenter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkText,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Total + impression badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order.total,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: order.impressionColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${order.impressionCount} IMP.',
                  style: TextStyle(
                    fontSize: 9,
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
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune commande en cours.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
