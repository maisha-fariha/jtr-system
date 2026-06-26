import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Generic input field container used on the login page and inside dialogs.
/// Set [showIcons] to false in dialogs where prefix/suffix icons are not shown.
class AuthInputContainer extends StatelessWidget {
  const AuthInputContainer({
    super.key,
    required this.child,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixRotation = 0,
    this.onSuffixTap,
    this.showIcons = true,
  });

  final Widget child;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  /// Turn fraction (0–1) applied to the suffix icon via [AnimatedRotation].
  final double suffixRotation;
  final VoidCallback? onSuffixTap;
  final bool showIcons;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          if (showIcons && prefixIcon != null) ...[
            Icon(prefixIcon, size: 20, color: AppTheme.textMedium),
            const SizedBox(width: 10),
          ],
          Expanded(child: child),
          if (showIcons && suffixIcon != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSuffixTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedRotation(
                turns: suffixRotation,
                duration: const Duration(milliseconds: 200),
                child: Icon(suffixIcon, size: 20, color: AppTheme.textMedium),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
