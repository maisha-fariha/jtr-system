import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/login_controller.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_input_container.dart';
import '../widgets/user_identifiant_field.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 56,
              color: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: Get.back,
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('IDENTIFICATION',
                      style: AppTheme.title1.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = constraints.maxWidth - 64;
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            const Icon(Icons.person_outline,
                                size: 64, color: AppTheme.primary),
                            const SizedBox(height: 16),
                            Text(
                              'Identifiez-vous',
                              style: AppTheme.headline2,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Entrez vos identifiants pour accéder à la session',
                              style: AppTheme.body2,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // ── Identifiant field ──────────────────────────
                            UserIdentifiantField(
                              controller: controller.identifiantFieldController,
                              showFieldIcons: true,
                            ),
                            UserIdentifiantSuggestionsOverlay(
                              controller: controller.identifiantFieldController,
                              fieldWidth: fieldWidth,
                              onUserSelected: controller.selectUser,
                            ),

                            const SizedBox(height: 14),

                            // ── Password field ─────────────────────────────
                            Obx(() => AuthInputContainer(
                                  showIcons: true,
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: controller.obscurePassword.value
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  onSuffixTap:
                                      controller.togglePasswordVisibility,
                                  child: TextField(
                                    obscureText:
                                        controller.obscurePassword.value,
                                    style: AppTheme.body1,
                                    decoration: InputDecoration(
                                      hintText: 'Mot de passe',
                                      hintStyle: AppTheme.body1
                                          .copyWith(color: AppTheme.textLight),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                )),

                            const SizedBox(height: 32),

                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: controller.login,
                                child: const Text('SE CONNECTER'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
