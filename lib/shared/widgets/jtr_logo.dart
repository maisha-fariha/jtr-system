import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_strings.dart';

/// JTR System logo — icon + brand text side-by-side.
/// Figma: "Frame 3" containing logo image + "JTR SYSTEM" text.
class JtrLogo extends StatelessWidget {
  const JtrLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo icon (replace with actual asset when available)
        Container(
          width: 53,
          height: 61,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: const Center(
            child: Text(
              'JR',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Brand name — "JTR" in primary, " SYSTEM" in white
        RichText(
          text: const TextSpan(
            style: AppTextStyles.displayLarge,
            children: [
              TextSpan(
                text: AppStrings.jtrBrand,
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(
                text: AppStrings.jtrRest,
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
