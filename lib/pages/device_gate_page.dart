import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/device_gate_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/themed_asset_image.dart';

class DeviceGatePage extends GetView<DeviceGateController> {
  const DeviceGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.connectBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 32,
            ),
            child: Obx(() {
              if (controller.errorMessage.value != null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ThemedAssetImage.logo(),
                    JtrResponsive.getResponsiveSpacing(context, 24),
                    Text(
                      controller.errorMessage.value!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.darkText),
                    ),
                    JtrResponsive.getResponsiveSpacing(context, 16),
                    ElevatedButton(
                      onPressed: controller.retry,
                      child: const Text('Réessayer'),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ThemedAssetImage.logo(),
                  JtrResponsive.getResponsiveSpacing(context, 28),
                  const CircularProgressIndicator(color: AppTheme.primary),
                  JtrResponsive.getResponsiveSpacing(context, 16),
                  Text(
                    controller.statusText.value,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 14),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
