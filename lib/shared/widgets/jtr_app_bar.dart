import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_strings.dart';

/// Reusable AppBar matching the Figma "Header - TopAppBar" component.
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

  Future<void> _showAboutDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(AppStrings.aboutTitle, style: AppTextStyles.headlineLarge),
        content: const Text(AppStrings.aboutMessage, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

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
              onPressed: onBack ?? () => context.pop(),
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
              color: AppColors.surface,
              onSelected: (value) {
                if (value == 'about') {
                  _showAboutDialog(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'about',
                  child: Text(AppStrings.aboutTitle),
                ),
              ],
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
