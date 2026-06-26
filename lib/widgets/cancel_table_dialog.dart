import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/app_theme.dart';
import 'auth_input_container.dart';
import 'user_identifiant_field.dart';
import 'user_identifiant_field_controller.dart';

/// Reusable confirmation dialog used for:
///  • Annulation Table
///  • Annulation après édition / note
///  • Table Offerte
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
      CancelTableDialog(title: title, onConfirm: onConfirm),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
    );
  }

  @override
  State<CancelTableDialog> createState() => _CancelTableDialogState();
}

class _CancelTableDialogState extends State<CancelTableDialog> {
  late final UserIdentifiantFieldController _identifiantController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _identifiantController = UserIdentifiantFieldController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _identifiantController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth.clamp(0.0, 360.0);
          return SizedBox(
            width: contentWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Card body
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: AppTheme.title1.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Identifiant field + overlay
                      UserIdentifiantField(
                        controller: _identifiantController,
                        showFieldIcons: false,
                      ),
                      UserIdentifiantSuggestionsOverlay(
                        controller: _identifiantController,
                        fieldWidth: contentWidth - 48,
                        onUserSelected: _identifiantController.selectUser,
                      ),

                      const SizedBox(height: 12),

                      // Password field
                      AuthInputContainer(
                        showIcons: false,
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: AppTheme.body1,
                          decoration: InputDecoration(
                            hintText: 'Mot de passe',
                            hintStyle: AppTheme.body1
                                .copyWith(color: AppTheme.textLight),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: _DialogButton(
                              label: 'ANNULER',
                              onTap: Get.back,
                              isPrimary: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DialogButton(
                              label: 'SE CONNECTER',
                              onTap: () {
                                Get.back();
                                widget.onConfirm();
                              },
                              isPrimary: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isPrimary
              ? null
              : Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isPrimary ? AppTheme.textOnPrimary : AppTheme.textMedium,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
