import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/jtr_logo.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/footer_hint.dart';
import '../widgets/role_selector_field.dart';
import '../widgets/password_field.dart';

/// Login / connection screen.
/// Figma: "Html → Body → Main App Container" (frame 4:108)
///
/// Layout:
///   ┌─────────────────────────────────┐
///   │  ← CONNEXION                    │
///   ├─────────────────────────────────┤
///   │                                 │
///   │        [JTR SYSTEM logo]        │
///   │                                 │
///   │  [ 👤  MANAGER        ▾ ]       │
///   │  [ 🔒  Mot de passe   👁 ]      │
///   │                                 │
///   │  [   Se connecter   ]           │
///   │                                 │
///   │         footer hint             │
///   └─────────────────────────────────┘
class ConnexionScreen extends StatefulWidget {
  const ConnexionScreen({super.key});

  @override
  State<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends State<ConnexionScreen> {
  final _passwordController = TextEditingController();
  String _selectedRole = AppStrings.manager;
  bool _isLoading = false;

  static const List<String> _roles = [
    'MANAGER',
    'SERVEUR',
    'RESPONSABLE',
  ];

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir votre mot de passe')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Navigate to loading screen, then dashboard
    if (mounted) {
      context.push(AppRoutes.loading);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          AppStrings.connexion,
          style: TextStyle(
            fontFamily: 'HankenGrotesk',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.9,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderDefault.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.sp32),
          child: Column(
            children: [
              const SizedBox(height: AppConstants.sp64 + 16),

              // ── Logo ──────────────────────────────────────────────────
              const JtrLogo(),

              const SizedBox(height: AppConstants.sp64),

              // ── Role selector ──────────────────────────────────────────
              RoleSelectorField(
                selectedRole: _selectedRole,
                roles: _roles,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),

              const SizedBox(height: AppConstants.sp16),

              // ── Password field ─────────────────────────────────────────
              PasswordField(
                controller: _passwordController,
                onSubmitted: _handleLogin,
              ),

              const SizedBox(height: AppConstants.sp32 + 8),

              // ── Login button ───────────────────────────────────────────
              PrimaryButton(
                label: AppStrings.seConnecter,
                isLoading: _isLoading,
                onPressed: _handleLogin,
              ),

              const Spacer(),

              // ── Footer hint ────────────────────────────────────────────
              const FooterHint(),
              const SizedBox(height: AppConstants.sp48),
            ],
          ),
        ),
      ),
    );
  }
}
