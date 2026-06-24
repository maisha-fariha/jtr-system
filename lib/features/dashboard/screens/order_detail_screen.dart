import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/dashboard_data.dart';
import '../models/order_item.dart';
import '../models/table_order.dart';
import '../widgets/session_header.dart';

/// Expanded order view with line items.
/// Figma: frame 31:1568 — expanded table row with item list.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.tableNumber,
  });

  final String tableNumber;

  @override
  Widget build(BuildContext context) {
    final order = DashboardData.orderFor(tableNumber);
    final items = DashboardData.itemsFor(tableNumber);

    if (order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text(AppStrings.orderDetail)),
        body: Center(
          child: Text(
            AppStrings.orderNotFound,
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SessionHeader(
              sessionNumber: 1,
              role: AppStrings.roleLabelManager,
              date: _todayLabel(),
              serviceType: order.serviceType,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.sp16),
                children: [
                  _OrderSummaryCard(order: order),
                  const SizedBox(height: AppConstants.sp16),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.sp8),
                      child: _OrderItemRow(item: item),
                    ),
                  ),
                  const SizedBox(height: AppConstants.sp16),
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
              padding: const EdgeInsets.all(AppConstants.sp16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push(
                        AppRoutes.requestNextPath(tableNumber),
                      ),
                      child: const Text(AppStrings.requestNextShort),
                    ),
                  ),
                  const SizedBox(width: AppConstants.sp12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context.push(
                        AppRoutes.ticketPath(tableNumber),
                      ),
                      child: const Text(AppStrings.ticket),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _todayLabel() {
    return DateTime.now().toString().split(' ').first.toUpperCase();
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final TableOrder order;

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
          Text(
            order.tableNumber,
            style: AppTextStyles.headlineLarge.copyWith(color: order.tableColor),
          ),
          const SizedBox(width: AppConstants.sp12),
          Expanded(
            child: Text(
              '${order.guests} ${AppStrings.guestsLabel} · ${order.post}',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          Text(order.formattedTotal, style: AppTextStyles.titleLarge),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.sp16,
        vertical: AppConstants.sp12,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Text('${item.quantity}x', style: AppTextStyles.bodySmall),
          const SizedBox(width: AppConstants.sp16),
          Expanded(
            child: Text(item.name, style: AppTextStyles.bodyLarge),
          ),
          Text(item.formattedPrice, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
