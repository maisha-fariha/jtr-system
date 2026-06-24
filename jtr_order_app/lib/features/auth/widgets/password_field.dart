import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';

/// Password input field with lock icon prefix and visibility toggle.
/// Matches "Password Field → Input" in Figma.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 57,
      decoration: BoxDecoration(
        color: AppColors.buttonOverlay,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          // Leading lock icon
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.sp16),
            child: Icon(
              Icons.lock_outline,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
          // Text input
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _obscure,
              style: AppTextStyles.bodyLarge,
              onSubmitted: (_) => widget.onSubmitted?.call(),
              decoration: const InputDecoration(
                hintText: AppStrings.motDePasse,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          // Visibility toggle
          GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Padding(
              padding: const EdgeInsets.only(right: AppConstants.sp16),
              child: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
