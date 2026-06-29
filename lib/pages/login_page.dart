import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/login_controller.dart';
import '../controllers/theme_controller.dart';
import '../routes/app_pages.dart';
import '../utils/app_theme.dart';
import '../widgets/app_footer.dart';
import '../widgets/themed_asset_image.dart';
import '../widgets/user_identifiant_field.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  static const _horizontalPadding = 32.0;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      final fieldWidth =
          MediaQuery.sizeOf(context).width - (_horizontalPadding * 2);

      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: AppTheme.darkText,
              size: 20,
            ),
            onPressed: () => Get.back(),
          ),
          title: const Text(
            'CONNEXION',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const ThemedAssetImage.logo(),
                    const SizedBox(height: 48),
                    UserIdentifiantField(
                      controller: controller.identifiantFieldController,
                      showFieldIcons: true,
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const Spacer(),
                    _buildLoginButton(),
                    const Spacer(flex: 2),
                    const AppFooter(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            UserIdentifiantSuggestionsOverlay(
              controller: controller.identifiantFieldController,
              fieldWidth: fieldWidth,
              onUserSelected: controller.selectUser,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPasswordField() {
    return Obx(
      () => AuthInputContainer(
        showIcons: true,
        prefixIcon: Icons.lock_outline,
        suffixIcon: controller.obscurePassword.value
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        onSuffixTap: controller.togglePasswordVisibility,
        child: TextField(
          controller: controller.passwordController,
          focusNode: controller.passwordFocusNode,
          obscureText: controller.obscurePassword.value,
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.darkText,
          ),
          decoration: InputDecoration(
            hintText: 'Mot de passe',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.55),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => Get.offNamed(AppRoutes.session),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Se connecter',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
