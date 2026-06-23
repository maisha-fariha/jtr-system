import 'package:flutter/material.dart';
import 'package:gems_responsive/gems_responsive.dart';

import 'app_pages.dart';

class NavShell extends StatelessWidget {
  const NavShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBottomNavShell(
      initialRoute: AppRoutes.home,
      items: const [
        ResponsiveNavItem(
          route: AppRoutes.home,
          label: 'Home',
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
        ),
        ResponsiveNavItem(
          route: AppRoutes.products,
          label: 'Products',
          icon: Icons.shopping_bag_outlined,
          activeIcon: Icons.shopping_bag,
        ),
        ResponsiveNavItem(
          route: AppRoutes.cart,
          label: 'Cart',
          icon: Icons.shopping_cart_outlined,
          activeIcon: Icons.shopping_cart,
        ),
        ResponsiveNavItem(
          route: AppRoutes.favorites,
          label: 'Favorites',
          icon: Icons.favorite_border,
          activeIcon: Icons.favorite,
        ),
        // ResponsiveNavItem(
        //   route: AppRoutes.todos,
        //   label: 'Todos',
        //   icon: Icons.check_circle_outline,
        //   activeIcon: Icons.check_circle,
        // ),
        ResponsiveNavItem(
          route: AppRoutes.settings,
          label: 'Settings',
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
        ),
      ],
    );
  }
}

