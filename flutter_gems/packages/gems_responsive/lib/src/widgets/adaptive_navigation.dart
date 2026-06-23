import 'package:flutter/material.dart';
import '../responsive_helper.dart';
import 'animated_icon.dart';

/// Adaptive Navigation Item
class AdaptiveNavItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final VoidCallback onTap;
  final Widget? badge;

  const AdaptiveNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    required this.onTap,
    this.badge,
  });
}

/// Adaptive Navigation - Automatically switches between drawer, tabs, and rail
class AdaptiveNavigation extends StatelessWidget {
  final List<AdaptiveNavItem> items;
  final int currentIndex;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? backgroundColor;
  final bool showLabels;
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const AdaptiveNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    this.selectedColor,
    this.unselectedColor,
    this.backgroundColor,
    this.showLabels = true,
    this.leading,
    this.title,
    this.actions,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = ResponsiveHelper.isSmallDevice(context);
    final isMedium = ResponsiveHelper.isMediumDevice(context);

    if (isSmall) {
      // Drawer on phone
      return _DrawerNavigation(
        items: items,
        currentIndex: currentIndex,
        selectedColor: selectedColor,
        unselectedColor: unselectedColor,
        backgroundColor: backgroundColor,
        leading: leading,
        title: title,
        actions: actions,
        appBar: appBar,
      );
    } else if (isMedium) {
      // Tabs on tablet
      return _TabNavigation(
        items: items,
        currentIndex: currentIndex,
        selectedColor: selectedColor,
        unselectedColor: unselectedColor,
        backgroundColor: backgroundColor,
        showLabels: showLabels,
        leading: leading,
        title: title,
        actions: actions,
        appBar: appBar,
      );
    } else {
      // Rail on desktop
      return _RailNavigation(
        items: items,
        currentIndex: currentIndex,
        selectedColor: selectedColor,
        unselectedColor: unselectedColor,
        backgroundColor: backgroundColor,
        showLabels: showLabels,
        leading: leading,
        title: title,
        actions: actions,
        appBar: appBar,
      );
    }
  }
}

class _DrawerNavigation extends StatelessWidget {
  final List<AdaptiveNavItem> items;
  final int currentIndex;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? backgroundColor;
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const _DrawerNavigation({
    required this.items,
    required this.currentIndex,
    this.selectedColor,
    this.unselectedColor,
    this.backgroundColor,
    this.leading,
    this.title,
    this.actions,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: Drawer(
        backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: ResponsiveHelper.getResponsivePadding(context, all: 8),
          children: [
            if (title != null)
              DrawerHeader(
                child: title!,
              ),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;
              
              return ListTile(
                leading: GemsAnimatedIcon(
                  icon: isSelected ? (item.activeIcon ?? item.icon) : item.icon,
                  animationType: isSelected ? AnimationType.scale : AnimationType.fade,
                  color: isSelected
                      ? (selectedColor ?? Theme.of(context).colorScheme.primary)
                      : (unselectedColor ?? Theme.of(context).iconTheme.color),
                  duration: const Duration(milliseconds: 200),
                ),
                title: Text(item.label),
                selected: isSelected,
                onTap: item.onTap,
                trailing: item.badge,
              );
            }),
          ],
        ),
      ),
      body: const SizedBox(), // Content should be provided by parent
    );
  }
}

class _TabNavigation extends StatelessWidget {
  final List<AdaptiveNavItem> items;
  final int currentIndex;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? backgroundColor;
  final bool showLabels;
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const _TabNavigation({
    required this.items,
    required this.currentIndex,
    this.selectedColor,
    this.unselectedColor,
    this.backgroundColor,
    required this.showLabels,
    this.leading,
    this.title,
    this.actions,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: items.length,
      initialIndex: currentIndex,
      child: Scaffold(
        appBar: appBar ??
            AppBar(
              leading: leading,
              title: title,
              actions: actions,
              bottom: TabBar(
                tabs: items.map((item) {
                  return Tab(
                    icon: GemsAnimatedIcon(
                      icon: item.icon,
                      animationType: AnimationType.fade,
                      color: selectedColor ?? Theme.of(context).colorScheme.primary,
                    ),
                    text: showLabels ? item.label : null,
                  );
                }).toList(),
                indicatorColor: selectedColor ?? Theme.of(context).colorScheme.primary,
                labelColor: selectedColor ?? Theme.of(context).colorScheme.primary,
                unselectedLabelColor: unselectedColor ?? Theme.of(context).iconTheme.color,
              ),
            ),
        body: TabBarView(
          children: items.map((item) => const SizedBox()).toList(),
        ),
      ),
    );
  }
}

class _RailNavigation extends StatelessWidget {
  final List<AdaptiveNavItem> items;
  final int currentIndex;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? backgroundColor;
  final bool showLabels;
  final Widget? leading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;

  const _RailNavigation({
    required this.items,
    required this.currentIndex,
    this.selectedColor,
    this.unselectedColor,
    this.backgroundColor,
    required this.showLabels,
    this.leading,
    this.title,
    this.actions,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => items[index].onTap(),
            backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
            selectedIconTheme: IconThemeData(
              color: selectedColor ?? Theme.of(context).colorScheme.primary,
            ),
            unselectedIconTheme: IconThemeData(
              color: unselectedColor ?? Theme.of(context).iconTheme.color,
            ),
            selectedLabelTextStyle: TextStyle(
              color: selectedColor ?? Theme.of(context).colorScheme.primary,
            ),
            destinations: items.map((item) {
              return NavigationRailDestination(
                icon: GemsAnimatedIcon(
                  icon: item.icon,
                  animationType: AnimationType.fade,
                ),
                selectedIcon: GemsAnimatedIcon(
                  icon: item.activeIcon ?? item.icon,
                  animationType: AnimationType.scale,
                  color: selectedColor ?? Theme.of(context).colorScheme.primary,
                ),
                label: showLabels ? Text(item.label) : const SizedBox.shrink(),
              );
            }).toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          const Expanded(child: SizedBox()), // Content should be provided by parent
        ],
      ),
    );
  }
}
