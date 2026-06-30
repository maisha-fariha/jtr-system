import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_pages.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_footer.dart';
import '../widgets/themed_asset_image.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = ThemeController.to.isDark.value;

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: AppTheme.background,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          key: ValueKey<bool>(isDark),
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppTheme.primary),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Get.back();
                } else {
                  SystemNavigator.pop();
                }
              },
            ),
            centerTitle: false,
            title: Text(
              'JTR System',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 20),
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                tooltip: isDark ? 'Mode clair' : 'Mode sombre',
                onPressed: ThemeController.to.toggle,
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: AppTheme.primary,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppTheme.primary),
                color: AppTheme.background,
                onSelected: (_) {},
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'about',
                    child: Text(
                      'About',
                      style: TextStyle(color: AppTheme.darkText),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ColoredBox(
            color: AppTheme.background,
            child: SafeArea(
              child: Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 32,
                ),
                child: Column(
                  children: [
                    JtrResponsive.getResponsiveSpacing(context, 48),
                    const ThemedAssetImage.logo(),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: JtrResponsive.getResponsiveHeight(context, 56),
                      child: ElevatedButton(
                        onPressed: () {
                          final auth = Get.find<AuthRepository>();
                          if (auth.isAuthenticated) {
                            Get.offNamed(AppRoutes.session);
                            return;
                          }
                          Get.toNamed(AppRoutes.connect);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              JtrResponsive.getResponsiveRadius(context, 16),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Connect',
                              style: TextStyle(
                                fontSize: JtrResponsive.getResponsiveFontSize(
                                  context,
                                  18,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            JtrResponsive.getResponsiveHorizontalSpacing(
                              context,
                              8,
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: JtrResponsive.getResponsiveSize(context, 24),
                            ),
                          ],
                        ),
                      ),
                    ),
                    JtrResponsive.getResponsiveSpacing(context, 20),
                    SizedBox(
                      width: double.infinity,
                      height: JtrResponsive.getResponsiveHeight(context, 56),
                      child: ElevatedButton(
                        onPressed: () => SystemNavigator.pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightButton,
                          foregroundColor: AppTheme.darkText,
                          elevation: 4,
                          shadowColor:
                              AppTheme.primary.withValues(alpha: 0.15),
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              JtrResponsive.getResponsiveRadius(context, 16),
                            ),
                          ),
                        ),
                        child: Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: JtrResponsive.getResponsiveFontSize(
                              context,
                              18,
                            ),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    const AppFooter(),
                    JtrResponsive.getResponsiveSpacing(context, 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
