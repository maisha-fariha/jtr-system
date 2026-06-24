import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/jtr_logo.dart';

/// Connection progress / loading screen.
/// Shown while verifying credentials and establishing a session.
/// Figma: "Html → Body" (frame 3:78)
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, this.role});

  final String? role;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go(
          '${AppRoutes.dashboard}?role=${Uri.encodeComponent(widget.role ?? AppStrings.manager)}',
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.sp24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const JtrLogo(),
                const SizedBox(height: AppConstants.sp48),

                // ── Progress card ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.sp32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 25,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Établissement de la\nconnexion...',
                        style: AppTextStyles.headlineLarge.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: AppConstants.sp24),
                      AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Connexion en cours...',
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: AppConstants.sp8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _progress.value,
                                backgroundColor: AppColors.borderDefault,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: AppConstants.sp8),
                            Text(
                              '${(_progress.value * 100).round()}%',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.sp16),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppConstants.sp16),
                          const Text(
                            'En attente du serveur...',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppConstants.sp32),

                // ── Success toast (fades in at 70%) ─────────────────────
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) => AnimatedOpacity(
                    opacity: _progress.value > 0.7 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.sp24,
                        vertical: AppConstants.sp12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppConstants.sp12),
                          Text(
                            AppStrings.connexionEtablie,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
