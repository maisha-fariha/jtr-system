import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/login_controller.dart';
import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_footer.dart';
import '../widgets/themed_asset_image.dart';
import '../widgets/user_identifiant_field.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      final horizontalPadding = JtrResponsive.getResponsiveWidth(context, 32);
      final fieldWidth =
          MediaQuery.sizeOf(context).width - (horizontalPadding * 2);

      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          automaticallyImplyLeading: false,
          title: Text(
            'CONNEXION',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          actions: [
            if (Get.isRegistered<ThemeController>())
              Obx(() {
                final isDark = ThemeController.to.isDark.value;
                return IconButton(
                  tooltip: isDark ? 'Mode clair' : 'Mode sombre',
                  onPressed: ThemeController.to.toggle,
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: AppTheme.darkText,
                    size: JtrResponsive.getResponsiveSize(context, 22),
                  ),
                );
              }),
          ],
        ),
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            SafeArea(
              child: Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 32,
                ),
                child: Column(
                  children: [
                    JtrResponsive.getResponsiveSpacing(context, 40),
                    const ThemedAssetImage.logo(),
                    JtrResponsive.getResponsiveSpacing(context, 48),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        UserIdentifiantField(
                          controller: controller.identifiantFieldController,
                          showFieldIcons: true,
                        ),
                        Obx(
                          () => controller.isLoadingUsers.value
                              ? ColoredBox(
                                  color:
                                      AppTheme.background.withValues(alpha: 0.7),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: UserIdentifiantSuggestionsOverlay
                                        .fieldHeight(context),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primary,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    JtrResponsive.getResponsiveSpacing(context, 16),
                    _buildPasswordField(context),
                    const Spacer(),
                    _buildLoginButton(context),
                    const Spacer(flex: 2),
                    const AppFooter(),
                    JtrResponsive.getResponsiveSpacing(context, 24),
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

  Widget _buildPasswordField(BuildContext context) {
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
            fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
            color: AppTheme.darkText,
          ),
          decoration: InputDecoration(
            hintText: 'Mot de passe',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.55),
              fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
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

  Widget _buildLoginButton(BuildContext context) {
    return Obx(
      () {
        final loading = controller.isLoading.value;
        return SizedBox(
          width: double.infinity,
          height: JtrResponsive.getResponsiveHeight(context, 56),
          child: ElevatedButton(
            onPressed: loading ? null : controller.login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppTheme.primary.withValues(alpha: 0.45),
              elevation: 4,
              shadowColor: AppTheme.primary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  JtrResponsive.getResponsiveRadius(context, 16),
                ),
              ),
            ),
            child: loading
                ? SizedBox(
                    width: JtrResponsive.getResponsiveSize(context, 24),
                    height: JtrResponsive.getResponsiveSize(context, 24),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Se connecter',
                    style: TextStyle(
                      fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
