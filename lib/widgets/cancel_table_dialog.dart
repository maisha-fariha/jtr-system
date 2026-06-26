import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';
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
  }) {
    return Get.dialog(
      CancelTableDialog(
        title: title,
        onConfirm: onConfirm,
      ),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
    );
  }

  @override
  State<CancelTableDialog> createState() => _CancelTableDialogState();
}

class _CancelTableDialogState extends State<CancelTableDialog> {
  static const _horizontalPadding = 20.0;

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
    return Dialog(
      backgroundColor: AppTheme.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth - (_horizontalPadding * 2);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  16,
                  _horizontalPadding,
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: IconButton(
                          onPressed: () => Get.back(),
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: AppTheme.darkText,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    UserIdentifiantField(
                      controller: _identifiantFieldController,
                      hintText: 'Identifiant, Prénom, Numéro, ...',
                    ),
                    const SizedBox(height: 16),
                    AuthInputContainer(
                      showIcons: false,
                      child: TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: true,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.darkText,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Mot de passe',
                          hintStyle: TextStyle(
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.55),
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          widget.onConfirm();
                        },
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
                            fontSize: 17,
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
  }
}
