import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_theme.dart';
import '../utils/responsive.dart';

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
      barrierColor: AppTheme.dialogBarrier,
      builder: (_) => MenuMessageTypingDialog(
        itemLabel: itemLabel,
        initialMessage: initialMessage,
        onSave: onSave,
      ),
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
    Navigator.of(context, rootNavigator: true).pop();
    widget.onSave?.call(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final dialogRadius = JtrResponsive.getResponsiveRadius(context, 24);
    final fieldRadius = JtrResponsive.getResponsiveRadius(context, 16);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 28,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.dialogBackground,
          borderRadius: BorderRadius.circular(dialogRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: Get.isDarkMode ? 0.45 : 0.12),
              blurRadius: JtrResponsive.getResponsiveWidth(context, 28),
              offset: Offset(
                0,
                JtrResponsive.getResponsiveHeight(context, 10),
              ),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dialogRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  left: 16,
                  right: 16,
                  top: 18,
                  bottom: 14,
                ),
                child: Row(
                  children: [
                    _HeaderIconButton(
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      child: Icon(
                        Icons.chevron_left,
                        color: AppTheme.darkText,
                        size: JtrResponsive.getResponsiveSize(context, 22),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Message',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: JtrResponsive.getResponsiveFontSize(
                            context,
                            18,
                          ),
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
                        size: JtrResponsive.getResponsiveSize(context, 22),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  left: 16,
                  right: 16,
                  bottom: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.itemLabel.toUpperCase(),
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: JtrResponsive.getResponsiveFontSize(
                          context,
                          13,
                        ),
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                        letterSpacing: 0.2,
                      ),
                    ),
                    JtrResponsive.getResponsiveSpacing(context, 14),
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: JtrResponsive.getResponsiveFontSize(
                          context,
                          14,
                        ),
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
                          borderRadius: BorderRadius.circular(fieldRadius),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(fieldRadius),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(fieldRadius),
                          borderSide: BorderSide(
                            color: AppTheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: JtrResponsive.getResponsivePadding(
                          context,
                          all: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: JtrResponsive.getResponsiveHeight(context, 3),
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
    final size = JtrResponsive.getResponsiveSize(context, 40);

    return Material(
      color: backgroundColor ?? AppTheme.dialogItemBackground,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}
