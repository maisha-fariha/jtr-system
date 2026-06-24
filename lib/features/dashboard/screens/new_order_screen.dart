import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/dashboard_data.dart';

/// Table selection screen for creating a new order.
/// Figma: frame 65:1587 — selection dialog list.
class NewOrderScreen extends StatelessWidget {
  const NewOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.newOrderTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppConstants.sp16),
        itemCount: DashboardData.availableTables.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppConstants.sp8),
        itemBuilder: (context, index) {
          final table = DashboardData.availableTables[index];
          final existingOrder = DashboardData.orderFor(table);
          final isOccupied = existingOrder != null;

          return ListTile(
            tileColor: AppColors.cardOverlay,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              side: const BorderSide(color: AppColors.borderSubtle),
            ),
            title: Text(
              table,
              style: AppTextStyles.titleLarge.copyWith(
                color: isOccupied ? AppColors.primary : AppColors.info,
              ),
            ),
            subtitle: Text(
              isOccupied
                  ? '${AppStrings.tableOccupied} · ${existingOrder.formattedTotal}'
                  : AppStrings.tableAvailable,
              style: AppTextStyles.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () {
              if (isOccupied) {
                context.push(AppRoutes.orderDetailPath(table));
              } else {
                context.push(AppRoutes.orderDetailPath(table));
              }
            },
          );
        },
      ),
    );
  }
}
