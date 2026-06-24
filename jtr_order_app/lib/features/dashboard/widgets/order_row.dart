import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../models/table_order.dart';

/// Single data row in the orders table.
/// Figma: "Row T5" / "Row T6" inside "Data Rows"
class OrderRow extends StatelessWidget {
  const OrderRow({
    super.key,
    required this.order,
    this.onTap,
  });

  final TableOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.sp16 + 1),
        decoration: BoxDecoration(
          color: AppColors.cardOverlay,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            // N° — table number (colored)
            Expanded(
              child: Text(
                order.tableNumber,
                style: AppTextStyles.titleLarge.copyWith(
                  color: order.tableColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // G. — guests
            Expanded(
              child: Text(
                '${order.guests}',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),
            ),
            // POSTE
            Expanded(
              child: Text(
                order.post,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            // CTR. PROFIT — service type (two lines)
            Expanded(
              child: Text(
                order.serviceType.replaceAll(' ', '\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'HankenGrotesk',
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.25,
                ),
              ),
            ),
            // CVT. — covers
            Expanded(
              child: Text(
                '${order.covers}',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),
            ),
            // IMP. — imprimes badge
            Expanded(
              child: Center(child: _ImprimeBadge(order: order)),
            ),
            // TOTAL
            Expanded(
              child: Text(
                order.formattedTotal,
                textAlign: TextAlign.right,
                style: AppTextStyles.titleLarge.copyWith(
                  color: const Color(0xFFF3F4F6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small colored badge showing the imprimes count.
/// Red border when 0, yellow when > 0.
class _ImprimeBadge extends StatelessWidget {
  const _ImprimeBadge({required this.order});

  final TableOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.sp8 + 1,
        vertical: AppConstants.sp4 - 1,
      ),
      decoration: BoxDecoration(
        color: order.imprimeBadgeColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXs),
        border: Border.all(color: order.imprimeBadgeBorderColor),
      ),
      child: Text(
        '${order.imprimes}',
        style: TextStyle(
          fontFamily: 'HankenGrotesk',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: order.imprimeBadgeTextColor,
          height: 20 / 10,
        ),
      ),
    );
  }
}
