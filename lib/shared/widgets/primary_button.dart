import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';

/// Full-width primary (salmon) button with optional trailing icon.
/// Matches the "Login Button → Button" component in Figma.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          // Subtle elevation shadow matching Figma
          elevation: WidgetStateProperty.all(0),
          overlayColor: WidgetStateProperty.all(
            AppColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.textPrimary,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppTextStyles.labelLarge),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Full-width ghost / outline button — "Exit" variant.
/// Matches the "Exit" button (rgba(255,255,255,0.05) bg) in Figma.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonOverlay,
          foregroundColor: AppColors.primary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(
            AppColors.primary.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
