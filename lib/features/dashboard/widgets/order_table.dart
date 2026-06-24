import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../models/table_order.dart';
import 'order_row.dart';

/// Full orders table — sticky header + scrollable rows.
/// Figma: "Main - TableContent" (31:1481)
class OrderTable extends StatelessWidget {
  const OrderTable({
    super.key,
    required this.orders,
    this.onRowTap,
    this.controller,
  });

  final List<TableOrder> orders;
  final ValueChanged<TableOrder>? onRowTap;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Table header row ────────────────────────────────────────────────
        _TableHeaderRow(),
        // ── Data rows (scrollable) ──────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            controller: controller,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.sp8,
              vertical: AppConstants.sp8,
            ),
            itemCount: orders.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppConstants.sp8),
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderRow(
                order: order,
                onTap: () => onRowTap?.call(order),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Sticky header row with column labels.
/// Figma: "Table Header Row" (31:1482)
class _TableHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const headers = [
      (AppStrings.headerNum, TextAlign.left),
      (AppStrings.headerGuests, TextAlign.center),
      (AppStrings.headerPost, TextAlign.center),
      (AppStrings.headerCtrProfit, TextAlign.center),
      (AppStrings.headerCover, TextAlign.center),
      (AppStrings.headerImp, TextAlign.center),
      (AppStrings.headerTotal, TextAlign.right),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.sp16 + 8,
        vertical: AppConstants.sp12,
      ),
      child: Row(
        children: headers
            .map(
              (h) => Expanded(
                child: Text(
                  h.$1,
                  textAlign: h.$2,
                  style: AppTextStyles.labelSmall,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
