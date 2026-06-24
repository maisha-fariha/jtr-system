import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/jtr_logo.dart';
import '../../../shared/widgets/jtr_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/footer_hint.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// Home / landing screen — first screen the user sees.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleExit(BuildContext context) async {
    final shouldExit = await showConfirmDialog(
      context: context,
      title: AppStrings.exitTitle,
      message: AppStrings.exitMessage,
      confirmLabel: AppStrings.exit,
    );

    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const JtrAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.sp24),
          child: Column(
            children: [
              const SizedBox(height: AppConstants.sp64),
              const JtrLogo(),
              const SizedBox(height: AppConstants.sp64 - 10),
              PrimaryButton(
                label: AppStrings.connect,
                trailingIcon: Icons.chevron_right,
                onPressed: () => context.push(AppRoutes.connexion),
              ),
              const SizedBox(height: AppConstants.sp24 - 8),
              GhostButton(
                label: AppStrings.exit,
                onPressed: () => _handleExit(context),
              ),
              const Spacer(),
              const FooterHint(),
              const SizedBox(height: AppConstants.sp48),
            ],
          ),
        ),
      ),
    );
  }
}
