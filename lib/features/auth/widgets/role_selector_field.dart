import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';

/// Dropdown-style role selector matching the "User Type Select" in Figma.
/// Shows a person icon on the left, selected value in the center, arrow on right.
class RoleSelectorField extends StatelessWidget {
  const RoleSelectorField({
    super.key,
    required this.selectedRole,
    required this.roles,
    required this.onChanged,
  });

  final String selectedRole;
  final List<String> roles;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.buttonOverlay,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Row(
        children: [
          // Leading person icon
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.sp16),
            child: Icon(
              Icons.person_outline,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
          // Expanded dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRole,
                items: roles
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(
                          role,
                          style: AppTextStyles.bodyLarge,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
                dropdownColor: AppColors.surface,
                icon: const SizedBox.shrink(),
                style: AppTextStyles.bodyLarge,
                isExpanded: true,
              ),
            ),
          ),
          // Trailing chevron icon
          const Padding(
            padding: EdgeInsets.only(right: AppConstants.sp16),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
