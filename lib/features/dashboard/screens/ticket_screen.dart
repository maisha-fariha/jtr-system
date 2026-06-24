import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/dashboard_data.dart';

/// Ticket preview screen for a selected table order.
class TicketScreen extends StatelessWidget {
  const TicketScreen({
    super.key,
    this.tableNumber,
  });

  final String? tableNumber;

  @override
  Widget build(BuildContext context) {
    final order = tableNumber != null
        ? DashboardData.orderFor(tableNumber!)
        : DashboardData.orders.first;
    final items = order != null
        ? DashboardData.itemsFor(order.tableNumber)
        : const [];

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text(AppStrings.ticketTitle)),
        body: Center(
          child: Text(AppStrings.orderNotFound, style: AppTextStyles.bodyMedium),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${AppStrings.ticketTitle} · ${order.tableNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.sp24),
              children: [
                Text(AppStrings.jtrSystem, style: AppTextStyles.headlineLarge),
                const SizedBox(height: AppConstants.sp8),
                Text(
                  '${AppStrings.tableLabel}: ${order.tableNumber}',
                  style: AppTextStyles.bodyMedium,
                ),
                const Divider(height: AppConstants.sp32),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppConstants.sp12),
                    child: Row(
                      children: [
                        Text('${item.quantity}x', style: AppTextStyles.bodySmall),
                        const SizedBox(width: AppConstants.sp12),
                        Expanded(
                          child: Text(item.name, style: AppTextStyles.bodyLarge),
                        ),
                        Text(item.formattedPrice, style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                ),
                const Divider(height: AppConstants.sp32),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${AppStrings.totalLabel}: ${order.formattedTotal}',
                    style: AppTextStyles.headlineLarge,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.sp24),
            child: PrimaryButton(
              label: AppStrings.printTicket,
              trailingIcon: Icons.print_outlined,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${AppStrings.ticketPrinted} ${order.tableNumber}',
                    ),
                  ),
                );
                context.pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
