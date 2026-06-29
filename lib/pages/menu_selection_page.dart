import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/menu_selection_controller.dart';
import '../controllers/theme_controller.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/preset_menu.dart';
import '../routes/app_pages.dart';
import '../utils/app_navigation.dart';
import '../utils/app_theme.dart';

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
              Divider(height: 1, color: AppTheme.cardBorder),
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
                      width: 1,
                      thickness: 1,
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
              Divider(height: 1, color: AppTheme.cardBorder),
              const _SelectionBottomNav(),
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
    return Column(
      children: [
        const _SidebarToolbar(),
        Expanded(child: _MenuList()),
      ],
    );
  }
}

class _ActiveSelectionHeader extends GetView<MenuSelectionController> {
  const _ActiveSelectionHeader();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selection = controller.activeSelection.value;
      if (selection == null) return const SizedBox.shrink();

      return SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: controller.dismissActiveSelection,
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.menu, size: 24, color: AppTheme.primary),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE74C3C),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.inactiveSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE SELECTION',
                        style: TextStyle(
                          fontSize: 9,
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
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                              ),
                            ),
                            TextSpan(
                              text: selection.menu.label,
                              style: TextStyle(
                                fontSize: 14,
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
              const SizedBox(width: 8),
              Obx(() {
                final saving = controller.isSaving.value;
                return Material(
                  color: MenuSelectionController.successGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: saving ? null : controller.finalizeActiveSelection,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: saving
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
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

      final grouped = <MenuCategory, List<MenuItem>>{};
      for (final category in selection.menu.categories) {
        final item = selection.selectedItemsByCourse[category.number];
        if (item != null) {
          grouped[category] = [item];
        }
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.lightButton,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        selection.menu.badgeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A90D9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${selection.choiceNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
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
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                      Text(
                        selection.menu.formattedPrice,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.cardBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              children: [
                for (final entry in grouped.entries) ...[
                  Text(
                    entry.key.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final item in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1x ${item.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkText,
                              height: 1.25,
                            ),
                          ),
                          if (selection.messageForCourse(item.courseNumber) !=
                              null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    selection.messageForCourse(
                                      item.courseNumber,
                                    )!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.cardBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: _SidebarToolbar(
              onEditTap: controller.showMessagePicker,
            ),
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
        padding: const EdgeInsets.all(16),
        itemCount: selection.menu.categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
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
                  size: isComplete ? 20 : 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                size: 22,
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
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              onPressed: () => AppNavigation.backToTableDetails(
                orderNumber: controller.orderNumber,
                orderId: controller.orderId,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(Icons.menu, size: 24, color: AppTheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sélection Menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
            ),
            Material(
              color: AppTheme.lightButton,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: controller.confirmSelection,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.check,
                    color: AppTheme.primary,
                    size: 24,
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

class _SidebarToolbar extends StatelessWidget {
  const _SidebarToolbar({this.onEditTap});

  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          const Expanded(child: _SidebarToolButton(icon: Icons.restaurant)),
          const SizedBox(width: 6),
          Expanded(
            child: _SidebarToolButton(
              icon: Icons.edit_outlined,
              onTap: onEditTap,
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: _SidebarToolButton(icon: Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }
}

class _SidebarToolButton extends StatelessWidget {
  const _SidebarToolButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: AppTheme.textSecondary),
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
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: controller.menus.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.inactiveSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  menu.badgeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      menu.formattedPrice,
                      style: TextStyle(
                        fontSize: 13,
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
                  width: 8,
                  height: 8,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.inactiveSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                size: 36,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sélectionnez un menu pour voir les détails ou ajouter des articles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Get.offAllNamed(AppRoutes.session),
            icon: Icon(Icons.home, color: AppTheme.primary, size: 28),
          ),
            IconButton(
              onPressed: () => AppNavigation.backToTableDetails(
                orderNumber: controller.orderNumber,
                orderId: controller.orderId,
              ),
              icon: Icon(Icons.arrow_back, color: AppTheme.darkText, size: 28),
            ),
          IconButton(
            onPressed: AppNavigation.logout,
            icon: const Icon(
              Icons.logout,
              color: Color(0xFF2EC4B6),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
