import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/device_blocked_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class DeviceBlockedPage extends GetView<DeviceBlockedController> {
  const DeviceBlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.connectBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 28,
            ),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: JtrResponsive.getResponsiveWidth(context, 420),
              ),
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
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Get.isDarkMode ? 0.35 : 0.06,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block,
                    size: JtrResponsive.getResponsiveSize(context, 48),
                    color: AppTheme.primary,
                  ),
                  JtrResponsive.getResponsiveSpacing(context, 16),
                  Text(
                    controller.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 22),
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  JtrResponsive.getResponsiveSpacing(context, 12),
                  Text(
                    controller.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 14),
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  JtrResponsive.getResponsiveSpacing(context, 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.retrySession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                        padding: JtrResponsive.getResponsivePadding(
                          context,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            JtrResponsive.getResponsiveRadius(context, 16),
                          ),
                        ),
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ),
                  JtrResponsive.getResponsiveSpacing(context, 10),
                  TextButton(
                    onPressed: controller.resetAndActivate,
                    child: Text(
                      'Réactiver avec un nouveau code',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
