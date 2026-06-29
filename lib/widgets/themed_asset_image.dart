import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_assets.dart';
import '../utils/responsive.dart';

/// Displays an image asset that switches between light and dark variants.
class ThemedAssetImage extends StatelessWidget {
  const ThemedAssetImage({
    super.key,
    required this.lightAsset,
    required this.darkAsset,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  });

  const ThemedAssetImage.logo({
    super.key,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  })  : lightAsset = AppAssets.logoLight,
        darkAsset = AppAssets.logoDark;

  final String lightAsset;
  final String darkAsset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final asset =
          ThemeController.to.isDark.value ? darkAsset : lightAsset;

      return Image.asset(
        asset,
        fit: fit,
        width: width != null
            ? JtrResponsive.getResponsiveWidth(context, width!)
            : null,
        height: height != null
            ? JtrResponsive.getResponsiveHeight(context, height!)
            : null,
        alignment: alignment,
      );
    });
  }
}
