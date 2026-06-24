import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/dashboard_data.dart';

/// Statistics overview screen.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final revenue = DashboardData.totalRevenue;
    final openTables = DashboardData.openTables;
    final printedTickets = DashboardData.printedTickets;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.statisticsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.sp16),
        children: [
          _StatCard(
            label: AppStrings.statRevenue,
            value:
                '${revenue.toStringAsFixed(2).replaceAll('.', ',')} €',
            icon: Icons.payments_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppConstants.sp12),
          _StatCard(
            label: AppStrings.statOpenTables,
            value: '$openTables',
            icon: Icons.table_bar_outlined,
            color: AppColors.info,
          ),
          const SizedBox(height: AppConstants.sp12),
          _StatCard(
            label: AppStrings.statPrintedTickets,
            value: '$printedTickets',
            icon: Icons.receipt_long_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppConstants.sp24),
          Text(AppStrings.statTablesBreakdown, style: AppTextStyles.titleLarge),
          const SizedBox(height: AppConstants.sp12),
          ...DashboardData.orders.map(
            (order) => ListTile(
              tileColor: AppColors.cardOverlay,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                side: const BorderSide(color: AppColors.borderSubtle),
              ),
              title: Text(
                order.tableNumber,
                style: AppTextStyles.titleLarge.copyWith(color: order.tableColor),
              ),
              subtitle: Text(
                '${order.serviceType} · ${order.imprimes} ${AppStrings.imprimesLabel}',
                style: AppTextStyles.bodySmall,
              ),
              trailing: Text(order.formattedTotal, style: AppTextStyles.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.sp16),
      decoration: BoxDecoration(
        color: AppColors.cardOverlay,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppConstants.sp16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall),
                Text(value, style: AppTextStyles.headlineLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
