import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import 'user_identifiant_field.dart';
import 'user_identifiant_field_controller.dart';

class CancelTableDialog extends StatefulWidget {
  const CancelTableDialog({
    super.key,
    required this.title,
    required this.onConfirm,
  });

  final String title;
  final VoidCallback onConfirm;

  static Future<void> show({
    required String title,
    required VoidCallback onConfirm,
    BuildContext? context,
  }) {
    final dialogContext = context ?? Get.overlayContext ?? Get.context;
    if (dialogContext == null || !dialogContext.mounted) {
      return Future.value();
    }

    return showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CancelTableDialog(
        title: title,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<CancelTableDialog> createState() => _CancelTableDialogState();
}

class _CancelTableDialogState extends State<CancelTableDialog> {
  final _identifiantController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  late final UserIdentifiantFieldController _identifiantFieldController;

  @override
  void initState() {
    super.initState();
    _identifiantFieldController = UserIdentifiantFieldController(
      textController: _identifiantController,
      hideSuggestionsFocusNode: _passwordFocusNode,
    );
  }

  @override
  void dispose() {
    _identifiantFieldController.dispose();
    _identifiantController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<ThemeController>()) {
        ThemeController.to.isDark.value;
      }

      final horizontalPadding =
          JtrResponsive.getResponsiveWidth(context, 20);

      return Dialog(
        backgroundColor: AppTheme.background,
        insetPadding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 28,
        ),
        clipBehavior: Clip.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            JtrResponsive.getResponsiveRadius(context, 24),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth =
                constraints.maxWidth - (horizontalPadding * 2);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: JtrResponsive.getResponsivePadding(
                    context,
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: 16,
                    bottom: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: JtrResponsive.getResponsivePadding(
                            context,
                            all: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              JtrResponsive.getResponsiveRadius(
                                context,
                                50,
                              ),
                            ),
                          ),
                          child: IconButton(
                            onPressed: () =>
                                Navigator.of(context, rootNavigator: true).pop(),
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              color: AppTheme.darkText,
                              size: JtrResponsive.getResponsiveSize(
                                context,
                                20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: JtrResponsive.getResponsiveFontSize(
                            context,
                            18,
                          ),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                          height: 1.3,
                        ),
                      ),
                      JtrResponsive.getResponsiveSpacing(context, 8),
                      UserIdentifiantField(
                        controller: _identifiantFieldController,
                        hintText: 'Identifiant, Prénom, Numéro, ...',
                      ),
                      JtrResponsive.getResponsiveSpacing(context, 16),
                      AuthInputContainer(
                        showIcons: false,
                        child: TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: true,
                          style: TextStyle(
                            fontSize: JtrResponsive.getResponsiveFontSize(
                              context,
                              15,
                            ),
                            color: AppTheme.darkText,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Mot de passe',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary
                                  .withValues(alpha: 0.55),
                              fontSize:
                                  JtrResponsive.getResponsiveFontSize(
                                context,
                                15,
                              ),
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
                      JtrResponsive.getResponsiveSpacing(context, 24),
                      SizedBox(
                        width: double.infinity,
                        height: JtrResponsive.getResponsiveHeight(
                          context,
                          52,
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).pop();
                            widget.onConfirm();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor:
                                AppTheme.primary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                JtrResponsive.getResponsiveRadius(
                                  context,
                                  16,
                                ),
                              ),
                            ),
                          ),
                          child: Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize:
                                  JtrResponsive.getResponsiveFontSize(
                                context,
                                17,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                UserIdentifiantSuggestionsOverlay(
                  controller: _identifiantFieldController,
                  fieldWidth: fieldWidth,
                ),
              ],
            );
          },
        ),
      );
    });
  }
}
