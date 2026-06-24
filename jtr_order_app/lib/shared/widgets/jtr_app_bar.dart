import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_strings.dart';

/// Reusable AppBar matching the Figma "Header - TopAppBar" component.
/// Used on the Home screen (with blur overlay) and Login screens.
class JtrAppBar extends StatelessWidget implements PreferredSizeWidget {
  const JtrAppBar({
    super.key,
    this.showBackButton = false,
    this.title = AppStrings.appName,
    this.actions,
    this.onBack,
  });

  final bool showBackButton;
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.8),
      elevation: 0,
      titleSpacing: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: AppColors.textPrimary,
              onPressed: onBack ?? () => Navigator.of(context).pop(),
            )
          : null,
      title: Text(
        title,
        style: title == AppStrings.appName
            ? AppTextStyles.headlineMedium
            : AppTextStyles.headlineLarge,
      ),
      actions: actions ??
          [
            IconButton(
              icon: const Icon(Icons.more_vert),
              color: AppColors.textPrimary,
              onPressed: () {},
            ),
          ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
    );
  }
}
