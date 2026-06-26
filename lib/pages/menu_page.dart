import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/order_menu_controller.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../routes/app_pages.dart';
import '../utils/app_navigation.dart';
import '../utils/app_theme.dart';

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
    return Scaffold(
      backgroundColor: AppTheme.connectBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _MenuHeader(),
            Divider(height: 1, color: AppTheme.cardBorder),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 88),
                child: Padding(
                  // Figma: content starts at x=24, width=342
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      for (final category in controller.visibleCategories) ...[
                        _CourseSectionHeader(category: category),
                        const SizedBox(height: 16),
                        _CourseItemsGrid(category: category),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const _MenuBottomNav(),
          ],
        ),
      ),
      floatingActionButton: const _ConfirmFab(),
    );
  }
}

// ─── TopHeader (h=64) ─────────────────────────────────────────────────────────

class _MenuHeader extends GetView<OrderMenuController> {
  const _MenuHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        // Figma: left container at x=16; confirm button at x=334 → right pad=16
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const _MenuIconButton(),
            const SizedBox(width: 12),
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
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => Get.back(),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.menu,
                size: 24,
                color: AppTheme.darkText,
              ),
            ),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.background, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
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
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        // Access .value inside build — tracked by GetView's implicit Obx
        Obx(() => Text(
              'Table ${controller.currentTable.value}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
                height: 1.2,
              ),
            )),
      ],
    );
  }
}

// Confirm icon — enabled when items are selected.
class _ConfirmIconButton extends GetView<OrderMenuController> {
  const _ConfirmIconButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = controller.selectedCount > 0;
      return IconButton(
        onPressed: enabled ? controller.confirmOrder : null,
        icon: Icon(
          Icons.check_circle_outline,
          size: 24,
          color: enabled
              ? AppTheme.primary
              : AppTheme.textSecondary.withValues(alpha: 0.35),
        ),
      );
    });
  }
}

// ─── Course Section Header ─────────────────────────────────────────────────────

class _CourseSectionHeader extends StatelessWidget {
  const _CourseSectionHeader({required this.category});

  final MenuCategory category;

  @override
  Widget build(BuildContext context) {
    // Figma: header h=33, circle 24×24, heading at x=32
    return SizedBox(
      height: 33,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${category.number}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'CHOIX ${category.number} — ${category.label}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.expand_more,
            size: 16,
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
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

      return GestureDetector(
        onTap: () => controller.toggleItem(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: 128,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent bar — h=4, border-radius top only
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isSelected
                      ? category.color
                      : category.color.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Price text — y=16 in Figma (12px below accent bar)
                      Text(
                        item.formattedPrice,
                        style: TextStyle(
                          fontSize: 11,
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
                          fontSize: 10,
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

// ─── FAB (Figma: x=302 y=724, 64×64) ─────────────────────────────────────────

class _ConfirmFab extends GetView<OrderMenuController> {
  const _ConfirmFab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.selectedCount;
      final enabled = count > 0;
      return FloatingActionButton(
        onPressed: enabled ? controller.confirmOrder : null,
        backgroundColor: enabled
            ? AppTheme.primary
            : AppTheme.primary.withValues(alpha: 0.4),
        elevation: enabled ? 6 : 0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.check, color: Colors.white, size: 28),
            if (count > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
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

// ─── Bottom Nav (Figma: y=820, h=64, 3 buttons) ───────────────────────────────

class _MenuBottomNav extends StatelessWidget {
  const _MenuBottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => Get.offAllNamed(AppRoutes.session),
              icon: Icon(Icons.home, color: AppTheme.primary, size: 28),
            ),
            IconButton(
              onPressed: () => Get.back(),
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
      ),
    );
  }
}
