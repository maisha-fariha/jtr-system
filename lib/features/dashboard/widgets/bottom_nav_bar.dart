import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Bottom navigation bar with 3 items.
/// Figma: "Nav - TabBar" (161:1829) — Home, Back/Undo, Exit
class DashboardBottomNavBar extends StatelessWidget {
  const DashboardBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppConstants.tabBarHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.arrow_back,
            activeIcon: Icons.arrow_back,
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.logout,
            activeIcon: Icons.logout,
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
            activeColor: AppColors.info,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
    this.activeColor,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? (activeColor ?? AppColors.primary)
        : AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: double.infinity,
        child: Center(
          child: Icon(
            isActive ? activeIcon : icon,
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }
}
