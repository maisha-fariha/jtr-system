import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
/// Top header for the dashboard screen.
/// Shows session number (orange circle), role label, current date, and service badge.
/// Figma: "MainHeader" inside frame 31:1466
class SessionHeader extends StatelessWidget {
  const SessionHeader({
    super.key,
    required this.sessionNumber,
    required this.role,
    required this.date,
    required this.serviceType,
  });

  final int sessionNumber;
  final String role;
  final String date;
  final String serviceType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppConstants.headerHeight,
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppConstants.sp16),
      child: Row(
        children: [
          // Session indicator circle
          _SessionIndicator(number: sessionNumber),
          const SizedBox(width: AppConstants.sp16),
          // Role + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  role.toUpperCase(),
                  style: AppTextStyles.roleBadge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  date.toUpperCase(),
                  style: AppTextStyles.sessionDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Service type badge (e.g. "SUR PLACE")
          _ServiceBadge(label: serviceType),
        ],
      ),
    );
  }
}

class _SessionIndicator extends StatelessWidget {
  const _SessionIndicator({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.sessionIndicatorSize,
      height: AppConstants.sessionIndicatorSize,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryShadow,
            blurRadius: 15,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primaryShadow,
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          fontFamily: 'HankenGrotesk',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 28 / 18,
        ),
      ),
    );
  }
}

class _ServiceBadge extends StatelessWidget {
  const _ServiceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.sp16 + 1,
        vertical: AppConstants.sp8 + 1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.titleSmall,
      ),
    );
  }
}
