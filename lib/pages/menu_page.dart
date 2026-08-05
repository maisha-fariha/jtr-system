import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/order_menu_controller.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../routes/app_pages.dart';
import '../utils/app_features.dart';
import '../utils/app_navigation.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

/// Shared type scale for the CHOIX screen — one adaptive size per role so
/// sidebar, headers, and every item card stay visually consistent.
class _MenuStyle {
  _MenuStyle._();

  static double fs(BuildContext context, double base) {
    final size = JtrResponsive.getResponsiveFontSize(context, base);
    if (JtrResponsive.isLargeDevice(context)) return size + 1;
    return size;
  }

  static TextStyle overline(BuildContext context) => TextStyle(
        fontSize: fs(context, 10),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        height: 1.2,
        color: AppTheme.textSecondary,
      );

  static TextStyle caption(BuildContext context, {Color? color}) => TextStyle(
        fontSize: fs(context, 11),
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color ?? AppTheme.textSecondary,
      );

  static TextStyle body(BuildContext context, {Color? color}) => TextStyle(
        fontSize: fs(context, 12),
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: color ?? AppTheme.darkText,
      );

  static TextStyle title(BuildContext context, {Color? color}) => TextStyle(
        fontSize: fs(context, 13),
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: color ?? AppTheme.darkText,
      );

  static TextStyle headline(BuildContext context) => TextStyle(
        fontSize: fs(context, 16),
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: AppTheme.darkText,
      );

  static TextStyle price(BuildContext context) => TextStyle(
        fontSize: fs(context, 12),
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppTheme.primary,
      );

  /// Same name size for every card in a row — based on cell width, not content.
  static double itemNameSize(BuildContext context, double cellWidth) {
    final base = fs(context, 12);
    if (cellWidth < 100) return (base - 1).clamp(10.0, base);
    if (cellWidth < 120) return base;
    return (base + 0.5).clamp(base, base + 1);
  }

  static double cardRadius(BuildContext context) =>
      JtrResponsive.getResponsiveRadius(context, 12);

  static EdgeInsets cardPadding(BuildContext context) =>
      JtrResponsive.getResponsivePadding(
        context,
        left: 12,
        top: 10,
        right: 12,
        bottom: 10,
      );
}

/// CHOIX product-selection screen (menu list + side selection summary).
///
/// Obx rule: every reactive read must happen *inside* the Obx closure.
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
                    final sideWidth = (constraints.maxWidth * 0.30).clamp(
                      124.0,
                      200.0,
                    );

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
                              bottom: 20,
                            ),
                            child: Padding(
                              padding: JtrResponsive.getResponsivePadding(
                                context,
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  JtrResponsive.getResponsiveSpacing(
                                    context,
                                    20,
                                  ),
                                  for (final category
                                      in controller.visibleCategories) ...[
                                    _CourseSectionHeader(category: category),
                                    _CourseSectionBody(category: category),
                                    JtrResponsive.getResponsiveSpacing(
                                      context,
                                      28,
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
        bottomNavigationBar: kShowBottomNavigationBar
            ? const SafeArea(
                top: false,
                child: _MenuBottomNav(),
              )
            : null,
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _MenuHeader extends GetView<OrderMenuController> {
  const _MenuHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: JtrResponsive.adaptiveHeight(context, 64, compact: 48),
      child: Padding(
        padding: JtrResponsive.getResponsivePadding(context, horizontal: 16),
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

class _MenuIconButton extends GetView<OrderMenuController> {
  const _MenuIconButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.selectedCount;
      final buttonSize = JtrResponsive.getResponsiveSize(context, 40);
      final badgeSize = JtrResponsive.getResponsiveSize(context, 18);

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
                    style: _MenuStyle.caption(context, color: Colors.white)
                        .copyWith(
                      fontSize: _MenuStyle.fs(context, 10),
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: Colors.white,
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

class _OrderDisplay extends GetView<OrderMenuController> {
  const _OrderDisplay();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COMMANDE EN COURS', style: _MenuStyle.overline(context)),
        JtrResponsive.getResponsiveSpacing(context, 2),
        Obx(
          () => Text(
            'Table ${controller.currentTable.value}',
            style: _MenuStyle.headline(context),
          ),
        ),
      ],
    );
  }
}

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
                      fontSize: _MenuStyle.fs(context, 10),
                      fontWeight: FontWeight.w800,
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

// ─── Side panel (same type scale as grid) ─────────────────────────────────────

class _SelectedMenuSidePanel extends GetView<OrderMenuController> {
  const _SelectedMenuSidePanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final menu = controller.presetMenu;
      if (menu == null) return const SizedBox.shrink();

      final selectedByCourse = <int, List<MenuItem>>{};
      for (final item in controller.selectedItems) {
        selectedByCourse
            .putIfAbsent(item.courseNumber, () => <MenuItem>[])
            .add(item);
      }

      final badgeSize = JtrResponsive.getResponsiveSize(context, 44);

      return Container(
        padding: JtrResponsive.getResponsivePadding(
          context,
          left: 14,
          right: 12,
          top: 18,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(right: BorderSide(color: AppTheme.cardBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: AppTheme.lightButton,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.22),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                menu.badgeLabel,
                textAlign: TextAlign.center,
                style: _MenuStyle.body(context, color: AppTheme.primary)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            JtrResponsive.getResponsiveSpacing(context, 12),
            Text(
              'QTÉ ${controller.choiceNumber}',
              style: _MenuStyle.overline(context),
            ),
            JtrResponsive.getResponsiveSpacing(context, 6),
            Text(
              menu.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _MenuStyle.title(context),
            ),
            JtrResponsive.getResponsiveSpacing(context, 4),
            Text(menu.formattedPrice, style: _MenuStyle.price(context)),
            JtrResponsive.getResponsiveSpacing(context, 14),
            Divider(height: 1, color: AppTheme.cardBorder),
            JtrResponsive.getResponsiveSpacing(context, 12),
            Text('SÉLECTION', style: _MenuStyle.overline(context)),
            JtrResponsive.getResponsiveSpacing(context, 10),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final category in controller.visibleCategories)
                    Padding(
                      padding: JtrResponsive.getResponsivePadding(
                        context,
                        bottom: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHOIX ${category.number}',
                            style: _MenuStyle.caption(context),
                          ),
                          JtrResponsive.getResponsiveSpacing(context, 4),
                          if (selectedByCourse[category.number]?.isNotEmpty ??
                              false)
                            for (final item
                                in selectedByCourse[category.number]!)
                              Padding(
                                padding: JtrResponsive.getResponsivePadding(
                                  context,
                                  bottom: 4,
                                ),
                                child: Text(
                                  '1x ${item.name}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _MenuStyle.body(context),
                                ),
                              )
                          else
                            Text(
                              '—',
                              style: _MenuStyle.body(
                                context,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.55),
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

// ─── Course sections ──────────────────────────────────────────────────────────

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
          height: JtrResponsive.getResponsiveHeight(context, 36),
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
                    fontSize: _MenuStyle.fs(context, 12),
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              JtrResponsive.getResponsiveHorizontalSpacing(context, 10),
              Expanded(
                child: Text(
                  'CHOIX ${category.number} — ${category.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _MenuStyle.title(context),
                ),
              ),
              Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                size: JtrResponsive.getResponsiveSize(context, 22),
                color: AppTheme.textSecondary.withValues(alpha: 0.55),
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
          JtrResponsive.getResponsiveSpacing(context, 14),
          _CourseItemsGrid(category: category),
        ],
      );
    });
  }
}

class _CourseItemsGrid extends StatelessWidget {
  const _CourseItemsGrid({required this.category});

  final MenuCategory category;

  @override
  Widget build(BuildContext context) {
    final spacing = JtrResponsive.getResponsiveWidth(context, 10);
    final runSpacing = JtrResponsive.getResponsiveHeight(context, 10);

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns;
        if (constraints.maxWidth < 280) {
          columns = 2;
        } else if (constraints.maxWidth < 420) {
          columns = 3;
        } else {
          columns = JtrResponsive.gridColumns<int>(
            context,
            small: 3,
            medium: 4,
            large: 4,
          );
        }

        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final nameSize = _MenuStyle.itemNameSize(context, cellWidth);
        final cardHeight =
            JtrResponsive.adaptiveHeight(context, 112, compact: 88);

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final item in category.items)
              _MenuItemButton(
                item: item,
                category: category,
                width: cellWidth,
                height: cardHeight,
                nameFontSize: nameSize,
              ),
          ],
        );
      },
    );
  }
}

class _MenuItemButton extends GetView<OrderMenuController> {
  const _MenuItemButton({
    required this.item,
    required this.category,
    required this.width,
    required this.height,
    required this.nameFontSize,
  });

  final MenuItem item;
  final MenuCategory category;
  final double width;
  final double height;
  final double nameFontSize;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.isSelected(item);
      final bg = isSelected ? AppTheme.lightButton : AppTheme.background;
      final borderColor = isSelected ? AppTheme.primary : AppTheme.cardBorder;
      final radius = _MenuStyle.cardRadius(context);

      return GestureDetector(
        onTap: () => controller.toggleItem(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: JtrResponsive.getResponsiveHeight(context, 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? category.color
                      : category.color.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: _MenuStyle.cardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayPriceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _MenuStyle.caption(
                          context,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.name,
                        maxLines: item.name.trim().contains(RegExp(r'\s'))
                            ? 2
                            : 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: _MenuStyle.body(
                          context,
                          color: isSelected
                              ? AppTheme.darkText
                              : AppTheme.darkText.withValues(alpha: 0.8),
                        ).copyWith(
                          fontSize: nameFontSize,
                          height: 1.2,
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
        padding: JtrResponsive.getResponsivePadding(context, horizontal: 32),
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
