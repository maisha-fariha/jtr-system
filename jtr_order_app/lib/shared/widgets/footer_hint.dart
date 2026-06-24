import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_strings.dart';

/// Legal / copyright footer shown at the bottom of login-flow screens.
/// Figma: "Connection Hint" / "Connection Hint:margin"
class FooterHint extends StatelessWidget {
  const FooterHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            AppStrings.rightsLine1,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const Text(
            AppStrings.rightsLine2,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.caption,
              children: [
                const TextSpan(text: 'Email: '),
                TextSpan(
                  text: AppStrings.rightsEmail,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
                const TextSpan(
                  text: ' ${AppStrings.rightsEmailNote}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
