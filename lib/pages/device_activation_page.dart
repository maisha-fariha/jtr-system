import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/device_activation_controller.dart';
import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/themed_asset_image.dart';

/// Manual + QR-PNG activation screen using the app design system.
class DeviceActivationPage extends GetView<DeviceActivationController> {
  const DeviceActivationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      return Scaffold(
        backgroundColor: AppTheme.connectBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: JtrResponsive.getResponsivePadding(
                context,
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: JtrResponsive.getResponsiveWidth(context, 420),
                ),
                child: Column(
                  children: [
                    const ThemedAssetImage.logo(),
                    JtrResponsive.getResponsiveSpacing(context, 28),
                    Container(
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
                        border: Border.all(color: AppTheme.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: Get.isDarkMode ? 0.35 : 0.06,
                            ),
                            blurRadius: JtrResponsive.getResponsiveSize(
                              context,
                              24,
                            ),
                            offset: Offset(
                              0,
                              JtrResponsive.getResponsiveHeight(context, 8),
                            ),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Activer ce poste',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: JtrResponsive.getResponsiveFontSize(
                                context,
                                24,
                              ),
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                          ),
                          JtrResponsive.getResponsiveSpacing(context, 10),
                          Text(
                            controller.isQrDisabled
                                ? 'Mode test (bypass) — serveur Goatech.\n'
                                    'Code prérempli : JTR-BYPASS.\n'
                                    'Saisissez le schéma restaurant fourni, '
                                    'puis activez.'
                                : 'Liez cet appareil au poste Windows (caisse).\n'
                                    'Scannez le QR, importez une image, ou saisissez '
                                    'code + schéma + URL du poste.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: JtrResponsive.getResponsiveFontSize(
                                context,
                                13,
                              ),
                              height: 1.45,
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                          JtrResponsive.getResponsiveSpacing(context, 28),
                          _FieldLabel(text: 'Code d\'activation'),
                          JtrResponsive.getResponsiveSpacing(context, 8),
                          TextField(
                            controller: controller.codeController,
                            textCapitalization: TextCapitalization.characters,
                            cursorColor: AppTheme.primary,
                            style: TextStyle(color: AppTheme.darkText),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9\-]'),
                              ),
                            ],
                            decoration: _fieldDecoration(
                              context,
                              hint: controller.isQrDisabled
                                  ? 'JTR-BYPASS'
                                  : 'JTR-ABCD-EFGH',
                            ),
                          ),
                          JtrResponsive.getResponsiveSpacing(context, 18),
                          _FieldLabel(text: 'Schéma restaurant'),
                          JtrResponsive.getResponsiveSpacing(context, 8),
                          TextField(
                            controller: controller.tenantController,
                            cursorColor: AppTheme.primary,
                            style: TextStyle(color: AppTheme.darkText),
                            decoration: _fieldDecoration(
                              context,
                              hint: controller.isQrDisabled
                                  ? 'mocca'
                                  : 'ex. mocca',
                            ),
                          ),
                          JtrResponsive.getResponsiveSpacing(context, 18),
                          _FieldLabel(
                            text: controller.isQrDisabled
                                ? 'URL API'
                                : 'URL / IP du poste',
                          ),
                          JtrResponsive.getResponsiveSpacing(context, 8),
                          TextField(
                            controller: controller.apiBaseUrlController,
                            enabled: !controller.isQrDisabled,
                            readOnly: controller.isQrDisabled,
                            keyboardType: TextInputType.url,
                            cursorColor: AppTheme.primary,
                            style: TextStyle(
                              color: controller.isQrDisabled
                                  ? AppTheme.textSecondary
                                  : AppTheme.darkText,
                            ),
                            decoration: _fieldDecoration(
                              context,
                              hint: controller.isQrDisabled
                                  ? 'https://api.goatech.ma/'
                                  : 'ex. 192.168.1.10 ou http://192.168.1.10/api',
                            ),
                          ),
                          if (!controller.isQrDisabled) ...[
                            JtrResponsive.getResponsiveSpacing(context, 16),
                            Obx(
                              () => ElevatedButton.icon(
                                onPressed: controller.isImportingQr.value ||
                                        controller.isScanningQr.value ||
                                        controller.isSubmitting.value
                                    ? null
                                    : controller.scanQrWithCamera,
                                icon: controller.isScanningQr.value
                                    ? SizedBox(
                                        height:
                                            JtrResponsive.getResponsiveSize(
                                          context,
                                          18,
                                        ),
                                        width: JtrResponsive.getResponsiveSize(
                                          context,
                                          18,
                                        ),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.qr_code_scanner,
                                        size: JtrResponsive.getResponsiveSize(
                                          context,
                                          22,
                                        ),
                                      ),
                                label: Text(
                                  'Scanner le QR (caméra)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize:
                                        JtrResponsive.getResponsiveFontSize(
                                      context,
                                      14,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  disabledBackgroundColor:
                                      AppTheme.primary.withValues(alpha: 0.45),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: JtrResponsive.getResponsivePadding(
                                    context,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      JtrResponsive.getResponsiveRadius(
                                        context,
                                        16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            JtrResponsive.getResponsiveSpacing(context, 10),
                            Obx(
                              () => OutlinedButton(
                                onPressed: controller.isImportingQr.value ||
                                        controller.isScanningQr.value ||
                                        controller.isSubmitting.value
                                    ? null
                                    : controller.importQrPng,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  disabledForegroundColor:
                                      AppTheme.primary.withValues(alpha: 0.4),
                                  side: BorderSide(
                                    color: AppTheme.primary,
                                    width: 1.4,
                                  ),
                                  backgroundColor: AppTheme.lightButton,
                                  padding: JtrResponsive.getResponsivePadding(
                                    context,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      JtrResponsive.getResponsiveRadius(
                                        context,
                                        16,
                                      ),
                                    ),
                                  ),
                                ),
                                child: controller.isImportingQr.value
                                    ? SizedBox(
                                        height:
                                            JtrResponsive.getResponsiveSize(
                                          context,
                                          18,
                                        ),
                                        width: JtrResponsive.getResponsiveSize(
                                          context,
                                          18,
                                        ),
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primary,
                                        ),
                                      )
                                    : Text(
                                        'Importer le QR (PNG)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: JtrResponsive
                                              .getResponsiveFontSize(
                                            context,
                                            14,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                          Obx(() {
                            final message = controller.feedbackMessage.value;
                            if (message == null || message.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final isError = controller.feedbackIsError.value;
                            return Padding(
                              padding: EdgeInsets.only(
                                top: JtrResponsive.getResponsiveHeight(
                                  context,
                                  14,
                                ),
                              ),
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isError
                                      ? AppTheme.toolbarKitchen
                                      : AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize:
                                      JtrResponsive.getResponsiveFontSize(
                                    context,
                                    13,
                                  ),
                                ),
                              ),
                            );
                          }),
                          JtrResponsive.getResponsiveSpacing(context, 22),
                          Obx(
                            () => ElevatedButton(
                              onPressed: controller.isSubmitting.value
                                  ? null
                                  : controller.activate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                disabledBackgroundColor:
                                    AppTheme.primary.withValues(alpha: 0.45),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor:
                                    AppTheme.primary.withValues(alpha: 0.35),
                                padding: JtrResponsive.getResponsivePadding(
                                  context,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    JtrResponsive.getResponsiveRadius(
                                      context,
                                      16,
                                    ),
                                  ),
                                ),
                              ),
                              child: controller.isSubmitting.value
                                  ? SizedBox(
                                      height: JtrResponsive.getResponsiveSize(
                                        context,
                                        20,
                                      ),
                                      width: JtrResponsive.getResponsiveSize(
                                        context,
                                        20,
                                      ),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Activer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize:
                                            JtrResponsive.getResponsiveFontSize(
                                          context,
                                          16,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String hint,
  }) {
    final radius = JtrResponsive.getResponsiveRadius(context, 16);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppTheme.textSecondary.withValues(alpha: 0.55),
      ),
      filled: true,
      fillColor: AppTheme.inactiveSurface,
      contentPadding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: AppTheme.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.6),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
        fontWeight: FontWeight.w700,
        color: AppTheme.darkText,
      ),
    );
  }
}
