import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'responsive_helper.dart';
import 'widgets/animated_icon.dart';

/// Model for a bottom navigation destination.
class ResponsiveNavItem {
  final String route;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String? initialRoute;
  final Widget? badge;

  const ResponsiveNavItem({
    required this.route,
    required this.label,
    required this.icon,
    this.activeIcon,
    this.initialRoute,
    this.badge,
  });
}

/// A responsive bottom navigation bar that works with GetX's Router (Navigator 2.0).
///
/// Usage:
/// ```dart
/// return ResponsiveBottomNavShell(
///   initialRoute: '/home',
///   items: const [
///     ResponsiveNavItem(route: '/home', label: 'Home', icon: Icons.home),
///     ResponsiveNavItem(route: '/todos', label: 'Todos', icon: Icons.check_circle),
///     ResponsiveNavItem(route: '/settings', label: 'Settings', icon: Icons.settings),
///   ],
/// );
/// ```
class ResponsiveBottomNavShell extends StatefulWidget {
  final List<ResponsiveNavItem> items;
  final String initialRoute;
  final GetDelegate? delegate;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final double baseIconSize;
  final double baseFontSize;
  final EdgeInsets? padding;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool enableSafeArea;

  const ResponsiveBottomNavShell({
    super.key,
    required this.items,
    required this.initialRoute,
    this.delegate,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
    this.baseIconSize = 22,
    this.baseFontSize = 12,
    this.padding,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.enableSafeArea = true,
  }) : assert(items.length >= 2, 'Provide at least two nav items');

  @override
  State<ResponsiveBottomNavShell> createState() =>
      _ResponsiveBottomNavShellState();
}

class _ResponsiveBottomNavShellState extends State<ResponsiveBottomNavShell> {
  late final GetDelegate _delegate;

  @override
  void initState() {
    super.initState();
    _delegate = _resolveDelegate();
    // Listen to route changes so the nav bar stays in sync
    _delegate.addListener(_onRouteChange);
  }

  @override
  void dispose() {
    _delegate.removeListener(_onRouteChange);
    super.dispose();
  }

  void _onRouteChange() => setState(() {});

  GetDelegate _resolveDelegate() {
    try {
      return widget.delegate ?? Get.rootDelegate;
    } catch (_) {
      throw FlutterError(
        'ResponsiveBottomNavShell requires GetMaterialApp.router or an injected GetDelegate.',
      );
    }
  }

  int _locationToIndex(GetDelegate navDelegate) {
    final location =
        navDelegate.currentConfiguration?.location ?? widget.initialRoute;
    final matchIndex =
        widget.items.indexWhere((item) => location.startsWith(item.route));
    return matchIndex == -1 ? 0 : matchIndex;
  }

  void _handleTap(GetDelegate navDelegate, int index) {
    if (index < 0 || index >= widget.items.length) return;
    final item = widget.items[index];
    final target = item.initialRoute ?? item.route;
    // Prevent duplicate navigation stacks when already on the target
    final currentLocation =
        navDelegate.currentConfiguration?.location ?? widget.initialRoute;
    if (currentLocation.startsWith(target)) return;
    navDelegate.toNamed(target);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = widget.padding ??
        ResponsiveHelper.getResponsivePadding(context, all: 12);
    final iconSize =
        ResponsiveHelper.getResponsiveSize(context, widget.baseIconSize);
    final fontSize =
        ResponsiveHelper.getResponsiveFontSize(context, widget.baseFontSize);

    final currentIndex = _locationToIndex(_delegate);
    final navBar = ResponsiveBottomNavigationBar(
      items: widget.items,
      currentIndex: currentIndex,
      onTap: (index) => _handleTap(_delegate, index),
      backgroundColor: widget.backgroundColor,
      selectedColor: widget.selectedColor,
      unselectedColor: widget.unselectedColor,
      iconSize: iconSize,
      fontSize: fontSize,
    );

    final scaffold = Scaffold(
      appBar: widget.appBar,
      body: GetRouterOutlet(
        delegate: _delegate,
        anchorRoute: '/',
        initialRoute: widget.initialRoute,
      ),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: Padding(
        padding: resolvedPadding,
        child: navBar,
      ),
    );

    if (!widget.enableSafeArea) return scaffold;
    return SafeArea(child: scaffold);
  }
}

/// Low-level responsive bottom navigation bar widget.
class ResponsiveBottomNavigationBar extends StatelessWidget {
  final List<ResponsiveNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final double iconSize;
  final double fontSize;

  const ResponsiveBottomNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.getResponsiveRadius(context, 16),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex,
          onTap: onTap,
          backgroundColor: backgroundColor ?? Theme.of(context).cardColor,
          selectedItemColor:
              selectedColor ?? Theme.of(context).colorScheme.primary,
          unselectedItemColor:
              unselectedColor ?? Theme.of(context).textTheme.bodyMedium?.color,
          selectedFontSize: fontSize,
          unselectedFontSize: fontSize,
          iconSize: iconSize,
          items: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = index == currentIndex;

            Widget iconWidget = GemsAnimatedIcon(
              icon: isSelected ? (item.activeIcon ?? item.icon) : item.icon,
              animationType: isSelected
                  ? AnimationType.scale
                  : AnimationType.fade,
              size: iconSize,
              color: isSelected
                  ? (selectedColor ?? Theme.of(context).colorScheme.primary)
                  : (unselectedColor ??
                      Theme.of(context).textTheme.bodyMedium?.color),
              duration: const Duration(milliseconds: 200),
              minScale: isSelected ? 0.9 : 1.0,
              maxScale: isSelected ? 1.1 : 1.0,
              repeat: false,
            );

            Widget activeIconWidget = GemsAnimatedIcon(
              icon: item.activeIcon ?? item.icon,
              animationType: AnimationType.scale,
              size: iconSize,
              color: selectedColor ?? Theme.of(context).colorScheme.primary,
              duration: const Duration(milliseconds: 200),
              minScale: 0.9,
              maxScale: 1.1,
              repeat: false,
            );

            if (item.badge != null) {
              iconWidget = Stack(
                clipBehavior: Clip.none,
                children: [
                  iconWidget,
                  Positioned(
                    right: -6,
                    top: -6,
                    child: item.badge!,
                  ),
                ],
              );
              activeIconWidget = Stack(
                clipBehavior: Clip.none,
                children: [
                  activeIconWidget,
                  Positioned(
                    right: -6,
                    top: -6,
                    child: item.badge!,
                  ),
                ],
              );
            }

            return BottomNavigationBarItem(
              icon: iconWidget,
              activeIcon: activeIconWidget,
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

