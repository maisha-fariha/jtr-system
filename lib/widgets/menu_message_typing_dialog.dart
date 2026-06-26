import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';

typedef MenuMessageSaveCallback = void Function(String message);

class MenuMessageTypingDialog extends StatefulWidget {
  const MenuMessageTypingDialog({
    super.key,
    required this.itemLabel,
    this.initialMessage = '',
    this.onSave,
  });

  final String itemLabel;
  final String initialMessage;
  final MenuMessageSaveCallback? onSave;

  static Future<void> show({
    required String itemLabel,
    String initialMessage = '',
    MenuMessageSaveCallback? onSave,
  }) {
    return Get.dialog(
      MenuMessageTypingDialog(
        itemLabel: itemLabel,
        initialMessage: initialMessage,
        onSave: onSave,
      ),
      barrierDismissible: false,
      barrierColor: AppTheme.dialogBarrier,
    );
  }

  @override
  State<MenuMessageTypingDialog> createState() =>
      _MenuMessageTypingDialogState();
}

class _MenuMessageTypingDialogState extends State<MenuMessageTypingDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    Get.back();
    widget.onSave?.call(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.dialogBackground,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: Get.isDarkMode ? 0.45 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                child: Row(
                  children: [
                    _HeaderIconButton(
                      onTap: () => Get.back(),
                      child: Icon(
                        Icons.chevron_left,
                        color: AppTheme.darkText,
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Message',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                    _HeaderIconButton(
                      onTap: _save,
                      backgroundColor: AppTheme.lightButton,
                      child: Icon(
                        Icons.check,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.itemLabel.toUpperCase(),
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ex: À SUIVRE',
                        hintStyle: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        ),
                        filled: true,
                        fillColor: AppTheme.dialogItemBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppTheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 3,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.onTap,
    required this.child,
    this.backgroundColor,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppTheme.dialogItemBackground,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: child),
        ),
      ),
    );
  }
}
