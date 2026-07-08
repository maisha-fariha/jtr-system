import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/order_menu_controller.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../routes/app_pages.dart';
import '../utils/app_navigation.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Slightly larger text on large screens for menu / CHOIX layout.
double _menuPageFontSize(BuildContext context, double base) {
  final fontSize = JtrResponsive.getResponsiveFontSize(context, base);
  if (JtrResponsive.isLargeDevice(context)) {
    return fontSize + 2;
  }
  return fontSize;
}

/// Figma frame 160:1522 — product-selection screen (CHOIX 1/2/3).
///
/// Layout (390 × 884):
///  • TopHeader  — h=64
///  • MainContent — h=756, scrollable
///    – CHOIX 1 Section  y=96  h=177  (3 items)
///    – CHOIX 2 Section  y=305 h=317  (5 items, 2 rows)
///    – CHOIX 3 Section  y=654 h=397  (5 items, 2 rows)
///  • Footer BottomNav — h=64
///  • FAB at x=302 y=724 (64×64)
///
/// Obx rule: every reactive read must happen *inside* the Obx closure, not
/// inside a child widget's build method. Each leaf that shows reactive state
/// owns its own Obx.
class MenuPage extends GetView<OrderMenuController> {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final presetMenu = controller.presetMenu;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (controller.returnToSelection) {
          AppNavigation.backToMenuSelection();
        } else {
          Get.back();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.connectBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _MenuHeader(),
              Divider(height: 1, color: AppTheme.cardBorder),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showSidePanel = presetMenu != null;
                    final sideWidth = (constraints.maxWidth * 0.28)
                        .clamp(110.0, 190.0);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showSidePanel)
                          SizedBox(
                            width: sideWidth,
                            child: const _SelectedMenuSidePanel(),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: JtrResponsive.getResponsivePadding(
                              context,
                              bottom: 16,
                            ),
                            child: Padding(
                              padding: JtrResponsive.getResponsivePadding(
                                context,
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  JtrResponsive.getResponsiveSpacing(context, 24),
                                  for (final category
                                      in controller.visibleCategories) ...[
                                    _CourseSectionHeader(
                                      category: category,
                                    ),
                                    _CourseSectionBody(
                                      category: category,
                                    ),
                                    JtrResponsive.getResponsiveSpacing(
                                      context,
                                      32,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const SafeArea(
          top: false,
          child: _MenuBottomNav(),
        ),
      ),
    );
  }
}

// ─── TopHeader (h=64) ─────────────────────────────────────────────────────────

class _MenuHeader extends GetView<OrderMenuController> {
  const _MenuHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: JtrResponsive.adaptiveHeight(context, 64, compact: 48),
      child: Padding(
        // Figma: left container at x=16; confirm button at x=334 → right pad=16
        padding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 16,
        ),
        child: Row(
          children: [
            const _MenuIconButton(),
            JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
            const Expanded(child: _OrderDisplay()),
            const _ConfirmIconButton(),
          ],
        ),
      ),
    );
  }
}

// Badge count and back-icon. Obx lives HERE — reads selectedCount directly.
class _MenuIconButton extends GetView<OrderMenuController> {
  const _MenuIconButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.selectedCount;
      final buttonSize = JtrResponsive.getResponsiveSize(context, 40);
      final badgeSize = JtrResponsive.getResponsiveSize(context, 20);

      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {
                if (controller.returnToSelection) {
                  AppNavigation.backToMenuSelection();
                } else {
                  Get.back();
                }
              },
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.menu,
                size: JtrResponsive.getResponsiveSize(context, 24),
                color: AppTheme.darkText,
              ),
            ),
            if (count > 0)
              Positioned(
                right: JtrResponsive.getResponsiveWidth(context, -4),
                top: JtrResponsive.getResponsiveHeight(context, -4),
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.background,
                      width: JtrResponsive.getResponsiveWidth(context, 1.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _menuPageFontSize(context, 10),
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

// Current order display — currentTable is set once in onInit so no Obx needed,
// but we keep it to surface the value correctly on first build.
class _OrderDisplay extends GetView<OrderMenuController> {
  const _OrderDisplay();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMANDE EN COURS',
          style: TextStyle(
            fontSize: _menuPageFontSize(context, 11),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            height: 1.2,
          ),
        ),
        JtrResponsive.getResponsiveSpacing(context, 2),
        // Access .value inside build — tracked by GetView's implicit Obx
        Obx(() => Text(
              'Table ${controller.currentTable.value}',
              style: TextStyle(
                fontSize: _menuPageFontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
                height: 1.2,
              ),
            )),
      ],
    );
  }
}

class _SelectedMenuSidePanel extends GetView<OrderMenuController> {
  const _SelectedMenuSidePanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final menu = controller.presetMenu;
      if (menu == null) return const SizedBox.shrink();

      // Group current selections by course.
      final selectedByCourse = <int, MenuItem>{};
      for (final item in controller.selectedItems) {
        selectedByCourse[item.courseNumber] = item;
      }

      return Container(
        padding: JtrResponsive.getResponsivePadding(
          context,
          left: 12,
          right: 10,
          top: 18,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: AppTheme.cardBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: JtrResponsive.getResponsiveSize(context, 46),
              height: JtrResponsive.getResponsiveSize(context, 46),
              decoration: BoxDecoration(
                color: AppTheme.lightButton,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                menu.badgeLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 10),
            Text(
              'CHOIX ${controller.choiceNumber}',
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 6),
            Text(
              menu.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _menuPageFontSize(context, 13),
                fontWeight: FontWeight.w800,
                color: AppTheme.darkText,
                height: 1.2,
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 6),
            Text(
              menu.formattedPrice,
              style: TextStyle(
                fontSize: _menuPageFontSize(context, 12),
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                height: 1.2,
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 12),
            Divider(height: 1, color: AppTheme.cardBorder.withValues(alpha: 0.8)),
            JtrResponsive.getResponsiveSpacing(context, 10),
            Text(
              'SÉLECTION',
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 10),
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final category in controller.visibleCategories)
                    Padding(
                      padding: JtrResponsive.getResponsivePadding(
                        context,
                        bottom: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHOIX ${category.number}',
                            style: TextStyle(
                              fontSize:
                                  JtrResponsive.getResponsiveFontSize(context, 10),
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          JtrResponsive.getResponsiveSpacing(context, 4),
                          if (selectedByCourse[category.number] != null)
                            Text(
                              '1x ${selectedByCourse[category.number]!.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:
                                    JtrResponsive.getResponsiveFontSize(context, 12),
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkText,
                              ),
                            )
                          else
                            Text(
                              '—',
                              style: TextStyle(
                                fontSize:
                                    JtrResponsive.getResponsiveFontSize(context, 12),
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// Confirm icon — enabled when items are selected; shows selection count.
class _ConfirmIconButton extends GetView<OrderMenuController> {
  const _ConfirmIconButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.selectedCount;
      final enabled = count > 0;
      final buttonSize = JtrResponsive.getResponsiveSize(context, 44);

      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: enabled ? controller.confirmOrder : null,
              icon: Icon(
                Icons.check_circle,
                size: JtrResponsive.getResponsiveSize(context, 28),
                color: enabled
                    ? AppTheme.primary
                    : AppTheme.textSecondary.withValues(alpha: 0.35),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: JtrResponsive.getResponsiveSize(context, 18),
                  height: JtrResponsive.getResponsiveSize(context, 18),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: _menuPageFontSize(context, 9),
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

// ─── Course Section Header ─────────────────────────────────────────────────────

class _CourseSectionHeader extends GetView<OrderMenuController> {
  const _CourseSectionHeader({required this.category});

  final MenuCategory category;

  @override
  Widget build(BuildContext context) {
    final circleSize = JtrResponsive.getResponsiveSize(context, 24);

    return Obx(() {
      final expanded = controller.isCategoryExpanded(category.number);

      return InkWell(
        onTap: () => controller.toggleCategoryExpanded(category.number),
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 8),
        ),
        child: SizedBox(
          height: JtrResponsive.getResponsiveHeight(context, 33),
          child: Row(
            children: [
              Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${category.number}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _menuPageFontSize(context, 12),
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
              JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
              Expanded(
                child: Text(
                  'CHOIX ${category.number} — ${category.label}',
                  style: TextStyle(
                    fontSize: _menuPageFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkText,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                size: JtrResponsive.getResponsiveSize(context, 20),
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _CourseSectionBody extends GetView<OrderMenuController> {
  const _CourseSectionBody({required this.category});

  final MenuCategory category;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isCategoryExpanded(category.number)) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JtrResponsive.getResponsiveSpacing(context, 16),
          _CourseItemsGrid(category: category),
        ],
      );
    });
  }
}

// ─── Course Items Grid ─────────────────────────────────────────────────────────
//
// Figma: items h=128, 3 per row, gap=12.
// Available width = 342px (after 24px horizontal padding).
// Cell width = (342 − 12 − 12) / 3 ≈ 106px.
//
// No Obx here — each _MenuItemButton owns its own Obx.

class _CourseItemsGrid extends StatelessWidget {
  const _CourseItemsGrid({required this.category});

  final MenuCategory category;

  @override
  Widget build(BuildContext context) {
    final columns = JtrResponsive.gridColumns<int>(
      context,
      small: 3,
      medium: 4,
      large: 4,
    );
    final spacing = JtrResponsive.getResponsiveWidth(context, 12);
    final runSpacing = JtrResponsive.getResponsiveHeight(context, 12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final item in category.items)
              _MenuItemButton(
                item: item,
                category: category,
                width: cellWidth,
              ),
          ],
        );
      },
    );
  }
}

// ─── Menu Item Button (h=128) ─────────────────────────────────────────────────
//
// Figma layout (per item):
//  • y=0–4:   coloured accent bar (Overlay rounded-rect, h=4)
//  • x=16 y=16 h=17: price/code text
//  • x=16 y=33+~43=76 h=~36: item name (pushed toward bottom via Spacer)
//
// Owns its own Obx so reactive selection state is read INSIDE the closure.

class _MenuItemButton extends GetView<OrderMenuController> {
  const _MenuItemButton({
    required this.item,
    required this.category,
    required this.width,
  });

  final MenuItem item;
  final MenuCategory category;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // ← observable read INSIDE Obx closure — GetX tracks this correctly
      final isSelected = controller.isSelected(item);
      final bg = isSelected ? AppTheme.lightButton : AppTheme.background;
      final borderColor = isSelected ? AppTheme.primary : AppTheme.cardBorder;
      final itemRadius = JtrResponsive.getResponsiveRadius(context, 10);

      return GestureDetector(
        onTap: () => controller.toggleItem(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: JtrResponsive.adaptiveHeight(context, 128, compact: 92),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(itemRadius),
            border: Border.all(
              color: borderColor,
              width: isSelected
                  ? JtrResponsive.getResponsiveWidth(context, 1.5)
                  : JtrResponsive.getResponsiveWidth(context, 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: JtrResponsive.getResponsiveSize(context, 4),
                offset: Offset(
                  0,
                  JtrResponsive.getResponsiveHeight(context, 2),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent bar — h=4, border-radius top only
              Container(
                height: JtrResponsive.getResponsiveHeight(context, 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? category.color
                      : category.color.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(itemRadius),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: JtrResponsive.getResponsivePadding(
                    context,
                    left: 16,
                    top: 12,
                    right: 8,
                    bottom: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price text — y=16 in Figma (12px below accent bar)
                      Text(
                        item.displayPriceLabel,
                        style: TextStyle(
                          fontSize: _menuPageFontSize(context, 11),
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          height: 1.2,
                        ),
                      ),
                      // Spacer pushes name toward bottom half (~y=76 in Figma)
                      const Spacer(),
                      Text(
                        item.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _menuPageFontSize(context, 10),
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppTheme.darkText
                              : AppTheme.darkText.withValues(alpha: 0.75),
                          height: 1.25,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// Confirm action lives in the header (_ConfirmIconButton) to avoid overlapping
// the bottom navigation bar.

class _MenuBottomNav extends GetView<OrderMenuController> {
  const _MenuBottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: JtrResponsive.adaptiveHeight(context, 64, compact: 48),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Padding(
        padding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 32,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Get.offAllNamed(AppRoutes.session),
              icon: Icon(
                Icons.home,
                color: AppTheme.primary,
                size: JtrResponsive.getResponsiveSize(context, 28),
              ),
            ),
            IconButton(
              onPressed: () {
                if (controller.returnToSelection) {
                  AppNavigation.backToMenuSelection();
                } else {
                  Get.back();
                }
              },
              icon: Icon(
                Icons.arrow_back,
                color: AppTheme.darkText,
                size: JtrResponsive.getResponsiveSize(context, 28),
              ),
            ),
            IconButton(
              onPressed: AppNavigation.logout,
              icon: Icon(
                Icons.logout,
                color: const Color(0xFF2EC4B6),
                size: JtrResponsive.getResponsiveSize(context, 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
