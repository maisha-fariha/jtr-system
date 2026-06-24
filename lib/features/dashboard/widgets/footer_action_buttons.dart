import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';

/// Footer action button strip.
/// Figma: "Footer - ActionButtons" (170:34)
/// 4 square buttons: NOUVELLE COMMANDE (primary), DEMANDER LA SUITE,
/// TICKET, Statistics (secondary dark style).
class FooterActionButtons extends StatelessWidget {
  const FooterActionButtons({
    super.key,
    this.onNewOrder,
    this.onRequestNext,
    this.onTicket,
    this.onStatistics,
  });

  final VoidCallback? onNewOrder;
  final VoidCallback? onRequestNext;
  final VoidCallback? onTicket;
  final VoidCallback? onStatistics;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppConstants.footerHeight,
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppConstants.sp16),
      child: Row(
        children: [
          // PRIMARY — NOUVELLE COMMANDE
          _ActionButton(
            label: AppStrings.newOrder,
            icon: Icons.add,
            isPrimary: true,
            onTap: onNewOrder,
          ),
          const SizedBox(width: AppConstants.sp12),
          // DEMANDER LA SUITE
          _ActionButton(
            label: AppStrings.requestNext,
            icon: Icons.restaurant_menu,
            onTap: onRequestNext,
          ),
          const SizedBox(width: AppConstants.sp12),
          // TICKET
          _ActionButton(
            label: AppStrings.ticket,
            icon: Icons.receipt_long,
            onTap: onTicket,
          ),
          const SizedBox(width: AppConstants.sp12),
          // STATISTICS
          _ActionButton(
            label: AppStrings.statistics,
            icon: Icons.bar_chart,
            onTap: onStatistics,
          ),
        ],
      ),
    );
  }
}

/// Individual square action button.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    this.isPrimary = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? AppColors.primary : AppColors.surface;
    final border = isPrimary ? null : AppColors.borderLight;
    final iconBg = isPrimary ? AppColors.iconOverlay : Colors.transparent;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: AppConstants.actionButtonHeight,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: border != null ? Border.all(color: border) : null,
            boxShadow: isPrimary
                ? [
                    const BoxShadow(
                      color: AppColors.primaryShadow,
                      blurRadius: 15,
                      offset: Offset(0, 10),
                    ),
                    const BoxShadow(
                      color: AppColors.primaryShadow,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with optional overlay background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Icon(icon,
                    color: AppColors.textPrimary, size: 28),
              ),
              const SizedBox(height: 6),
              // Label (multiline, all caps)
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.actionButton,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
