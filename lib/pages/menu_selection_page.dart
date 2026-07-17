import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/menu_selection_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/preset_menu.dart';
import '../routes/app_pages.dart';
import '../utils/app_features.dart';
import '../utils/app_navigation.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class MenuSelectionPage extends GetView<MenuSelectionController> {
  const MenuSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ThemeController.to.isDark.value;
      final hasActive = controller.hasActiveSelection;

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (controller.hasActiveSelection) {
            controller.dismissActiveSelection();
            return;
          }
          AppNavigation.backToTableDetails(
            orderNumber: controller.orderNumber,
            orderId: controller.orderId,
          );
        },
        child: Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Column(
              children: [
                hasActive
                    ? const _ActiveSelectionHeader()
                    : const _SelectionHeader(),
                Divider(
                  height: JtrResponsive.getResponsiveHeight(context, 1),
                  color: AppTheme.cardBorder,
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 45,
                        child: ColoredBox(
                          color: AppTheme.background,
                          child: hasActive
                              ? const _OrderSummarySidebar()
                              : const _MenuListColumn(),
                        ),
                      ),
                      VerticalDivider(
                        width: JtrResponsive.getResponsiveWidth(context, 1),
                        thickness: JtrResponsive.getResponsiveWidth(context, 1),
                        color: AppTheme.cardBorder,
                      ),
                      Expanded(
                        flex: 55,
                        child: ColoredBox(
                          color: AppTheme.connectBackground,
                          child: hasActive
                              ? const _ChoixCardsPanel()
                              : _MenuDetailPanel(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (kShowBottomNavigationBar) ...[
                  Divider(
                    height: JtrResponsive.getResponsiveHeight(context, 1),
                    color: AppTheme.cardBorder,
                  ),
                  const _SelectionBottomNav(),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _MenuListColumn extends StatelessWidget {
  const _MenuListColumn();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MenuSelectionController>();

    return Obx(() {
      final expanded = controller.isSidebarExpanded.value;

      return Column(
        children: [
          const _SidebarToolbar(),
          if (expanded) Expanded(child: _MenuList()),
        ],
      );
    });
  }
}

class _ActiveSelectionHeader extends GetView<MenuSelectionController> {
  const _ActiveSelectionHeader();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selection = controller.activeSelection.value;
      if (selection == null) return const SizedBox.shrink();

      final buttonSize = JtrResponsive.getResponsiveSize(context, 40);
      final badgeSize = JtrResponsive.getResponsiveSize(context, 16);
      final confirmSize = JtrResponsive.getResponsiveSize(context, 44);

      return SizedBox(
        height: JtrResponsive.adaptiveHeight(context, 64, compact: 48),
        child: Padding(
          padding: JtrResponsive.getResponsivePadding(context, horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: buttonSize,
                height: buttonSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: controller.dismissActiveSelection,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.menu,
                        size: JtrResponsive.getResponsiveSize(context, 24),
                        color: AppTheme.primary,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: badgeSize,
                        height: badgeSize,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE74C3C),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${selection.choiceNumber}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: JtrResponsive.getResponsiveFontSize(
                              context,
                              9,
                            ),
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
              Expanded(
                child: Container(
                  padding: JtrResponsive.getResponsivePadding(
                    context,
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.inactiveSurface,
                    borderRadius: BorderRadius.circular(
                      JtrResponsive.getResponsiveRadius(context, 20),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE SELECTION',
                        style: TextStyle(
                          fontSize: JtrResponsive.getResponsiveFontSize(
                            context,
                            9,
                          ),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: AppTheme.textSecondary,
                          height: 1.1,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${selection.choiceNumber} x ',
                              style: TextStyle(
                                fontSize: JtrResponsive.getResponsiveFontSize(
                                  context,
                                  14,
                                ),
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                              ),
                            ),
                            TextSpan(
                              text: selection.menu.label,
                              style: TextStyle(
                                fontSize: JtrResponsive.getResponsiveFontSize(
                                  context,
                                  14,
                                ),
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
              Obx(() {
                final saving = controller.isSaving.value;
                return Material(
                  color: MenuSelectionController.successGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: saving ? null : controller.finalizeActiveSelection,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: confirmSize,
                      height: confirmSize,
                      child: saving
                          ? Padding(
                              padding: EdgeInsets.all(
                                JtrResponsive.getResponsiveSize(context, 10),
                              ),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.check,
                              color: Colors.white,
                              size: JtrResponsive.getResponsiveSize(
                                context,
                                24,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });
  }
}

class _OrderSummarySidebar extends GetView<MenuSelectionController> {
  const _OrderSummarySidebar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selection = controller.activeSelection.value;
      if (selection == null) return const SizedBox.shrink();

      final badgeSize = JtrResponsive.getResponsiveSize(context, 48);
      final choiceBadgeSize = JtrResponsive.getResponsiveSize(context, 18);

      final grouped = <MenuCategory, List<MenuItem>>{};
      for (final category in selection.menu.categories) {
        final items = selection.selectedItemsByCourse[category.number];
        if (items != null && items.isNotEmpty) {
          grouped[category] = List<MenuItem>.from(items);
        }
      }

      return Column(
        children: [
          Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              left: 12,
              top: 14,
              right: 12,
              bottom: 12,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        color: AppTheme.lightButton,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selection.menu.badgeLabel,
                        style: TextStyle(
                          fontSize: JtrResponsive.getResponsiveFontSize(
                            context,
                            14,
                          ),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      right: JtrResponsive.getResponsiveWidth(context, -2),
                      top: JtrResponsive.getResponsiveHeight(context, -2),
                      child: Container(
                        width: choiceBadgeSize,
                        height: choiceBadgeSize,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A90D9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${selection.choiceNumber}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: JtrResponsive.getResponsiveFontSize(
                              context,
                              10,
                            ),
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                JtrResponsive.getResponsiveHorizontalSpacing(context, 10),
                Expanded(
                  child: InkWell(
                    onTap: controller.toggleSidebarExpanded,
                    borderRadius: BorderRadius.circular(
                      JtrResponsive.getResponsiveRadius(context, 8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selection.menu.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: JtrResponsive.getResponsiveFontSize(
                                    context,
                                    15,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkText,
                                ),
                              ),
                            ),
                            Obx(
                              () => Icon(
                                controller.isSidebarExpanded.value
                                    ? Icons.keyboard_arrow_down
                                    : Icons.keyboard_arrow_right,
                                size: JtrResponsive.getResponsiveSize(
                                  context,
                                  18,
                                ),
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          selection.menu.formattedPrice,
                          style: TextStyle(
                            fontSize: JtrResponsive.getResponsiveFontSize(
                              context,
                              14,
                            ),
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: JtrResponsive.getResponsiveHeight(context, 1),
            color: AppTheme.cardBorder,
          ),
          Obx(
            () => controller.isSidebarExpanded.value
                ? Flexible(
                    fit: FlexFit.loose,
                    child: ListView(
                      padding: JtrResponsive.getResponsivePadding(
                        context,
                        left: 12,
                        top: 12,
                        right: 12,
                        bottom: 8,
                      ),
                      children: [
                        for (final entry in grouped.entries) ...[
                          Text(
                            'CHOIX ${entry.key.number}',
                            style: TextStyle(
                              fontSize: JtrResponsive.getResponsiveFontSize(
                                context,
                                10,
                              ),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (entry.key.label.trim().isNotEmpty &&
                              entry.key.label.toUpperCase() !=
                                  'CHOIX ${entry.key.number}') ...[
                            JtrResponsive.getResponsiveSpacing(context, 2),
                            Text(
                              entry.key.label,
                              style: TextStyle(
                                fontSize: JtrResponsive.getResponsiveFontSize(
                                  context,
                                  10,
                                ),
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                          JtrResponsive.getResponsiveSpacing(context, 6),
                          for (final item in entry.value)
                            Padding(
                              padding: JtrResponsive.getResponsivePadding(
                                context,
                                bottom: 10,
                              ),
                              child: Text(
                                '1x ${item.name}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize:
                                      JtrResponsive.getResponsiveFontSize(
                                    context,
                                    12,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.darkText,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          if (selection.messageForCourse(
                                entry.key.number,
                              ) !=
                              null) ...[
                            JtrResponsive.getResponsiveSpacing(context, 2),
                            Padding(
                              padding: JtrResponsive.getResponsivePadding(
                                context,
                                bottom: 10,
                              ),
                              child: InkWell(
                                onTap: () => controller.editMessageForCourse(
                                  context: context,
                                  courseNumber: entry.key.number,
                                ),
                                borderRadius: BorderRadius.circular(
                                  JtrResponsive.getResponsiveRadius(
                                    context,
                                    6,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selection.messageForCourse(
                                          entry.key.number,
                                        )!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize:
                                              JtrResponsive.getResponsiveFontSize(
                                            context,
                                            11,
                                          ),
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textSecondary,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: JtrResponsive.getResponsiveSize(
                                        context,
                                        14,
                                      ),
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Divider(
            height: JtrResponsive.getResponsiveHeight(context, 1),
            color: AppTheme.cardBorder,
          ),
          Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              left: 12,
              top: 8,
              right: 12,
              bottom: 12,
            ),
            child: const _SidebarToolbar(compact: true),
          ),
        ],
      );
    });
  }
}

class _ChoixCardsPanel extends GetView<MenuSelectionController> {
  const _ChoixCardsPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selection = controller.activeSelection.value;
      if (selection == null) return const SizedBox.shrink();

      return ListView.separated(
        padding: JtrResponsive.getResponsivePadding(context, all: 16),
        itemCount: selection.menu.categories.length,
        separatorBuilder: (_, _) =>
            JtrResponsive.getResponsiveSpacing(context, 12),
        itemBuilder: (context, index) {
          final category = selection.menu.categories[index];
          final isComplete = selection.isCourseComplete(category.number);

          return _ChoixCard(
            label: 'CHOIX ${category.number}',
            isComplete: isComplete,
            onTap: () => controller.openCourseChoice(category.number),
          );
        },
      );
    });
  }
}

class _ChoixCard extends StatelessWidget {
  const _ChoixCard({
    required this.label,
    required this.isComplete,
    required this.onTap,
  });

  final String label;
  final bool isComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardRadius = JtrResponsive.getResponsiveRadius(context, 14);
    final iconCircleSize = JtrResponsive.getResponsiveSize(context, 36);

    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          padding: JtrResponsive.getResponsivePadding(
            context,
            horizontal: 16,
            vertical: 18,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: AppTheme.primary,
              width: JtrResponsive.getResponsiveWidth(context, 1.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: iconCircleSize,
                height: iconCircleSize,
                decoration: BoxDecoration(
                  color: isComplete
                      ? MenuSelectionController.successGreen
                      : AppTheme.inactiveSurface,
                  shape: BoxShape.circle,
                  border: isComplete
                      ? null
                      : Border.all(color: AppTheme.cardBorder),
                ),
                child: Icon(
                  isComplete ? Icons.check : Icons.circle_outlined,
                  color: isComplete ? Colors.white : AppTheme.textSecondary,
                  size: JtrResponsive.getResponsiveSize(
                    context,
                    isComplete ? 20 : 18,
                  ),
                ),
              ),
              JtrResponsive.getResponsiveHorizontalSpacing(context, 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                size: JtrResponsive.getResponsiveSize(context, 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionHeader extends GetView<MenuSelectionController> {
  const _SelectionHeader();

  @override
  Widget build(BuildContext context) {
    final confirmSize = JtrResponsive.getResponsiveSize(context, 44);
    final buttonSize = JtrResponsive.getResponsiveSize(context, 40);
    final confirmRadius = JtrResponsive.getResponsiveRadius(context, 12);

    return SizedBox(
      height: JtrResponsive.adaptiveHeight(context, 64, compact: 48),
      child: Padding(
        padding: JtrResponsive.getResponsivePadding(context, horizontal: 16),
        child: Row(
          children: [
            IconButton(
              onPressed: () => AppNavigation.backToTableDetails(
                orderNumber: controller.orderNumber,
                orderId: controller.orderId,
              ),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: buttonSize,
                minHeight: buttonSize,
              ),
              icon: Icon(
                Icons.menu,
                size: JtrResponsive.getResponsiveSize(context, 24),
                color: AppTheme.primary,
              ),
            ),
            JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
            Expanded(
              child: Text(
                'Sélection Menu',
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
            ),
            Material(
              color: AppTheme.lightButton,
              borderRadius: BorderRadius.circular(confirmRadius),
              child: InkWell(
                onTap: controller.confirmSelection,
                borderRadius: BorderRadius.circular(confirmRadius),
                child: SizedBox(
                  width: confirmSize,
                  height: confirmSize,
                  child: Icon(
                    Icons.check,
                    color: AppTheme.primary,
                    size: JtrResponsive.getResponsiveSize(context, 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarToolbar extends GetView<MenuSelectionController> {
  const _SidebarToolbar({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        left: compact ? 0 : 12,
        top: compact ? 0 : 12,
        right: compact ? 0 : 12,
        bottom: compact ? 0 : 8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gap = JtrResponsive.getResponsiveWidth(context, 6);
          final availableWidth = constraints.maxWidth - gap * 2;
          final buttonSize = (availableWidth / 3).clamp(28.0, 40.0);

          return Row(
            children: [
              Expanded(
                child: _SidebarToolButton(
                  icon: Icons.restaurant,
                  size: buttonSize,
                  onTap: () {
                    if (controller.hasActiveSelection) {
                      controller.openActiveMenuChoices();
                      return;
                    }
                    controller.promptSelectMenuFirst(context);
                  },
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _SidebarToolButton(
                  icon: Icons.edit_outlined,
                  onTap: () => controller.showMessagePicker(context: context),
                  size: buttonSize,
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Obx(
                  () => _SidebarToolButton(
                    icon: controller.isSidebarExpanded.value
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    onTap: controller.toggleSidebarExpanded,
                    size: buttonSize,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SidebarToolButton extends StatelessWidget {
  const _SidebarToolButton({required this.icon, this.onTap, this.size});

  final IconData icon;
  final VoidCallback? onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? JtrResponsive.getResponsiveSize(context, 40);
    final buttonRadius = JtrResponsive.getResponsiveRadius(context, 10);
    final iconSize = buttonSize * 0.5;

    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(buttonRadius),
        child: SizedBox(
          height: buttonSize,
          width: double.infinity,
          child: Center(
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(buttonRadius),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: JtrResponsive.getResponsiveSize(context, 4),
                    offset: Offset(
                      0,
                      JtrResponsive.getResponsiveHeight(context, 1),
                    ),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: iconSize,
                color:
                    icon == Icons.keyboard_arrow_down ||
                        icon == Icons.keyboard_arrow_right
                    ? AppTheme.toolbarPanel
                    : AppTheme.toolbarIconColor(icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuList extends GetView<MenuSelectionController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingMenus.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final error = controller.menusError.value;
      if (error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        );
      }

      if (controller.menus.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Aucun menu composé disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        );
      }

      if (controller.isLoadingMenuDetail.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final selectedIndex = controller.selectedMenuIndex.value;

      return ListView.separated(
        padding: JtrResponsive.getResponsivePadding(
          context,
          left: 12,
          top: 4,
          right: 12,
          bottom: 12,
        ),
        itemCount: controller.menus.length,
        separatorBuilder: (_, _) =>
            JtrResponsive.getResponsiveSpacing(context, 10),
        itemBuilder: (context, index) {
          final menu = controller.menus[index];
          return _MenuCard(
            menu: menu,
            isSelected: selectedIndex == index,
            onTap: () => controller.selectMenu(index),
          );
        },
      );
    });
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.menu,
    required this.isSelected,
    required this.onTap,
  });

  final PresetMenu menu;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardRadius = JtrResponsive.getResponsiveRadius(context, 14);
    final badgeRadius = JtrResponsive.getResponsiveRadius(context, 10);
    final badgeSize = JtrResponsive.getResponsiveSize(context, 44);
    final dotSize = JtrResponsive.getResponsiveSize(context, 8);

    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          padding: JtrResponsive.getResponsivePadding(
            context,
            horizontal: 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
              width: isSelected
                  ? JtrResponsive.getResponsiveWidth(context, 1.5)
                  : JtrResponsive.getResponsiveWidth(context, 1),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      blurRadius: JtrResponsive.getResponsiveSize(context, 8),
                      offset: Offset(
                        0,
                        JtrResponsive.getResponsiveHeight(context, 2),
                      ),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: JtrResponsive.getResponsiveSize(context, 4),
                      offset: Offset(
                        0,
                        JtrResponsive.getResponsiveHeight(context, 1),
                      ),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.inactiveSurface,
                  borderRadius: BorderRadius.circular(badgeRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  menu.badgeLabel,
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
              JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: JtrResponsive.getResponsiveFontSize(
                          context,
                          14,
                        ),
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                      ),
                    ),
                    JtrResponsive.getResponsiveSpacing(context, 2),
                    Text(
                      menu.formattedPrice,
                      style: TextStyle(
                        fontSize: JtrResponsive.getResponsiveFontSize(
                          context,
                          13,
                        ),
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuDetailPanel extends GetView<MenuSelectionController> {
  @override
  Widget build(BuildContext context) {
    final iconCircleSize = JtrResponsive.getResponsiveSize(context, 72);

    return Center(
      child: Padding(
        padding: JtrResponsive.getResponsivePadding(context, horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: iconCircleSize,
              height: iconCircleSize,
              decoration: BoxDecoration(
                color: AppTheme.inactiveSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                size: JtrResponsive.getResponsiveSize(context, 36),
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 20),
            Text(
              'Sélectionnez un menu pour voir les détails ou ajouter des articles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBottomNav extends GetView<MenuSelectionController> {
  const _SelectionBottomNav();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 32,
        vertical: 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Get.offAllNamed(AppRoutes.session),
            icon: Icon(
              Icons.home,
              color: AppTheme.toolbarIconColor(Icons.home),
              size: JtrResponsive.getResponsiveSize(context, 28),
            ),
          ),
          IconButton(
            onPressed: () => AppNavigation.backToTableDetails(
              orderNumber: controller.orderNumber,
              orderId: controller.orderId,
            ),
            icon: Icon(
              Icons.arrow_back,
              color: AppTheme.toolbarIconColor(Icons.arrow_back),
              size: JtrResponsive.getResponsiveSize(context, 28),
            ),
          ),
          IconButton(
            onPressed: AppNavigation.logout,
            icon: Icon(
              Icons.logout,
              color: AppTheme.toolbarIconColor(Icons.logout),
              size: JtrResponsive.getResponsiveSize(context, 28),
            ),
          ),
        ],
      ),
    );
  }
}
