import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/connect_controller.dart';
import '../routes/app_pages.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/themed_asset_image.dart';

class ConnectPage extends GetView<ConnectController> {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.connectBackground,
      body: SafeArea(
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
              _buildProgressCard(context),
              JtrResponsive.getResponsiveSpacing(context, 35),
              _buildConnectionStatus(context),
              const Spacer(),
              Obx(() => _buildNextButton(context)),
              JtrResponsive.getResponsiveSpacing(context, 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 28,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: JtrResponsive.getResponsiveSize(context, 24),
            offset: Offset(
              0,
              JtrResponsive.getResponsiveHeight(context, 8),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Chargement base de données',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 8),
          Text(
            'INITIALISATION',
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          JtrResponsive.getResponsiveSpacing(context, 28),
          Obx(() => _buildProgressBar(context, controller.progress.value)),
          JtrResponsive.getResponsiveSpacing(context, 16),
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: JtrResponsive.getResponsiveSize(context, 8),
                  height: JtrResponsive.getResponsiveSize(context, 8),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
                Text(
                  controller.statusDetail.value,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double value) {
    final percent = (value * 100).round();
    final barHeight = JtrResponsive.getResponsiveHeight(context, 44);
    final barRadius = JtrResponsive.getResponsiveRadius(context, 22);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * value.clamp(0.0, 1.0);

        return Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(barRadius),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: fillWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(barRadius),
                ),
              ),
              if (fillWidth > 0)
                Positioned(
                  left: 0,
                  width: fillWidth,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: JtrResponsive.getResponsiveFontSize(
                          context,
                          16,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(BuildContext context) {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: JtrResponsive.getResponsiveSize(context, 28),
            height: JtrResponsive.getResponsiveSize(context, 28),
            decoration: BoxDecoration(
              color: AppTheme.lightButton,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: JtrResponsive.getResponsiveSize(context, 16),
              color: controller.isConnected.value
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.4),
            ),
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 10),
          Text(
            'Connexion établie',
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w500,
              color: controller.isConnected.value
                  ? AppTheme.primary
                  : AppTheme.primary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton(BuildContext context) {
    final isEnabled = controller.isConnected.value;

    return SizedBox(
      width: double.infinity,
      height: JtrResponsive.getResponsiveHeight(context, 56),
      child: ElevatedButton(
        onPressed: isEnabled ? () => Get.offNamed(AppRoutes.login) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          elevation: isEnabled ? 4 : 0,
          shadowColor: AppTheme.primary.withValues(alpha: 0.4),
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
              'Next',
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
              ),
            ),
            JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
            Icon(
              Icons.chevron_right,
              size: JtrResponsive.getResponsiveSize(context, 24),
            ),
          ],
        ),
      ),
    );
  }
}
