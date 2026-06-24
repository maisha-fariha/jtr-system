import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/jtr_logo.dart';
import '../../../shared/widgets/jtr_app_bar.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/footer_hint.dart';

/// Home / landing screen — first screen the user sees.
/// Figma: "Html → Body" (frame 2:40)
///
/// Layout:
///   ┌─────────────────────────────────┐
///   │  AppBar: ← JTR System    ⋮      │
///   ├─────────────────────────────────┤
///   │                                 │
///   │        [JTR SYSTEM logo]        │
///   │                                 │
///   │  [  Connect  →  ]  (salmon)     │
///   │  [    Exit       ]  (ghost)     │
///   │                                 │
///   │        footer hint              │
///   └─────────────────────────────────┘
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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

              // ── Logo ────────────────────────────────────────────────────
              const JtrLogo(),

              const SizedBox(height: AppConstants.sp64 - 10),

              // ── Connect button ──────────────────────────────────────────
              PrimaryButton(
                label: AppStrings.connect,
                trailingIcon: Icons.chevron_right,
                onPressed: () => context.push(AppRoutes.connexion),
              ),

              const SizedBox(height: AppConstants.sp24 - 8),

              // ── Exit button ─────────────────────────────────────────────
              GhostButton(
                label: AppStrings.exit,
                onPressed: () {
                  // Platform exit — close the app
                  // ignore: use_build_context_synchronously
                  // In production: SystemNavigator.pop() or exit(0)
                },
              ),

              const Spacer(),

              // ── Footer hint ─────────────────────────────────────────────
              const FooterHint(),
              const SizedBox(height: AppConstants.sp48),
            ],
          ),
        ),
      ),
    );
  }
}
