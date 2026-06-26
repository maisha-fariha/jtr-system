import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/order_menu_controller.dart';
import '../models/menu_item.dart';
import '../models/order_product.dart';
import '../utils/app_theme.dart';

/// ORDER-TAKING screen — the primary Figma deliverable.
///
/// Layout (tablet-first, responsive):
///   ┌────────────────────────────────────────────┐
///   │  Header: Table number + actions             │
///   ├──────────────┬─────────────────────────────┤
///   │  Categories  │  Menu items (grid)          │
///   │  (left rail) │                             │
///   ├──────────────┴─────────────────────────────┤
///   │  Order summary footer + CONFIRMER button    │
///   └────────────────────────────────────────────┘
///
/// On narrow phones the category rail slides to a horizontal scroll bar.
class MenuPage extends GetView<OrderMenuController> {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _MenuHeader(tableNumber: controller.tableNumber),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  return isWide
                      ? _WideLayout(controller: controller)
                      : _NarrowLayout(controller: controller);
                },
              ),
            ),
            _OrderFooter(controller: controller),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.tableNumber});
  final int tableNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppTheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: Get.back,
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'PRISE DE COMMANDE',
              style: AppTheme.title1.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          // Table badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Table $tableNumber',
              style: AppTheme.title2.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wide layout (tablet / landscape) ──────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.controller});
  final OrderMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left rail — categories
        SizedBox(
          width: 140,
          child: _CategoryRailVertical(controller: controller),
        ),
        const VerticalDivider(width: 1),
        // Right area — items grid + mini cart
        Expanded(
          child: Column(
            children: [
              Expanded(child: _MenuItemsGrid(controller: controller)),
            ],
          ),
        ),
        // Cart panel (tablet only)
        SizedBox(
          width: 280,
          child: _CartPanel(controller: controller),
        ),
      ],
    );
  }
}

// ── Narrow layout (phone / portrait) ──────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.controller});
  final OrderMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CategoryRailHorizontal(controller: controller),
        Expanded(child: _MenuItemsGrid(controller: controller)),
      ],
    );
  }
}

// ── Category rails ─────────────────────────────────────────────────────────────

class _CategoryRailVertical extends StatelessWidget {
  const _CategoryRailVertical({required this.controller});
  final OrderMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Obx(() => ListView.builder(
            itemCount: controller.categories.length,
            itemBuilder: (context, index) {
              final cat = controller.categories[index];
              final isSelected =
                  controller.selectedCategoryId.value == cat.id;
              return _CategoryTile(
                category: cat,
                isSelected: isSelected,
                onTap: () => controller.selectCategory(cat.id),
              );
            },
          )),
    );
  }
}

class _CategoryRailHorizontal extends StatelessWidget {
  const _CategoryRailHorizontal({required this.controller});
  final OrderMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppTheme.surface,
      child: Obx(() => ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: controller.categories.length,
            itemBuilder: (context, index) {
              final cat = controller.categories[index];
              final isSelected =
                  controller.selectedCategoryId.value == cat.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => controller.selectCategory(cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            },
          )),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final MenuCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconData(category.iconCode ?? Icons.restaurant.codePoint,
                  fontFamily: 'MaterialIcons'),
              size: 22,
              color: isSelected ? AppTheme.primary : AppTheme.textMedium,
            ),
            const SizedBox(height: 4),
            Text(
              category.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? AppTheme.primary : AppTheme.textMedium,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Menu items grid ────────────────────────────────────────────────────────────

class _MenuItemsGrid extends StatelessWidget {
  const _MenuItemsGrid({required this.controller});
  final OrderMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.filteredItems;
      if (items.isEmpty) {
        return const Center(
          child: Text('Aucun article dans cette catégorie.',
              style: TextStyle(color: AppTheme.textLight)),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _MenuItemCard(
          item: items[index],
          controller: controller,
        ),
      );
    });
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.controller,
  });

  final MenuItem item;
  final OrderMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final qty = controller.quantityInCart(item.id);
      final inCart = qty > 0;

      return GestureDetector(
        onTap: () => controller.addToCart(item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inCart
                  ? AppTheme.primary
                  : AppTheme.border,
              width: inCart ? 2 : 1,
            ),
            boxShadow: inCart ? AppTheme.subtleShadow : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image / icon placeholder
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: inCart
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : AppTheme.background,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(11)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 36,
                        color: inCart
                            ? AppTheme.primary
                            : AppTheme.border,
                      ),
                      if (inCart)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$qty',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Info area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                          height: 1.2,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.price.toStringAsFixed(0)} MAD',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                          if (inCart)
                            GestureDetector(
                              onTap: () =>
                                  controller.removeFromCart(item.id),
                              child: const Icon(Icons.remove_circle_outline,
                                  size: 18, color: AppTheme.error),
                            ),
                        ],
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

// ── Cart panel (wide screens only) ────────────────────────────────────────────

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.controller});
  final OrderMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // Panel header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: AppTheme.textMedium),
                const SizedBox(width: 8),
                Text('COMMANDE',
                    style: AppTheme.label
                        .copyWith(color: AppTheme.textDark)),
                const Spacer(),
                Obx(() => GestureDetector(
                      onTap: controller.cartItems.isEmpty
                          ? null
                          : controller.clearCart,
                      child: Text(
                        'VIDER',
                        style: AppTheme.label.copyWith(
                          color: controller.cartItems.isEmpty
                              ? AppTheme.border
                              : AppTheme.error,
                        ),
                      ),
                    )),
              ],
            ),
          ),

          // Cart items
          Expanded(
            child: Obx(() {
              if (controller.cartItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_cart_outlined,
                          size: 40, color: AppTheme.border),
                      const SizedBox(height: 8),
                      Text('Commande vide',
                          style: AppTheme.body2
                              .copyWith(color: AppTheme.textLight)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: controller.cartItems.length,
                itemBuilder: (context, index) =>
                    _CartItemRow(item: controller.cartItems[index]),
              );
            }),
          ),

          // Sub-total
          Obx(() => controller.cartItems.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppTheme.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppTheme.textMedium)),
                      Text(
                        '${controller.cartTotal.toStringAsFixed(0)} MAD',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({required this.item});
  final OrderProduct item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              'x${item.quantity}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(item.name,
                  style: AppTheme.body1
                      .copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(
            item.totalPrice.toStringAsFixed(0),
            style: AppTheme.body2
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Order footer ───────────────────────────────────────────────────────────────

class _OrderFooter extends StatelessWidget {
  const _OrderFooter({required this.controller});
  final OrderMenuController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isEmpty = controller.cartItems.isEmpty;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Count badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isEmpty
                    ? AppTheme.background
                    : AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isEmpty ? AppTheme.border : AppTheme.primary),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${controller.cartItemCount}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isEmpty
                          ? AppTheme.textLight
                          : AppTheme.primary,
                    ),
                  ),
                  Text('article${controller.cartItemCount != 1 ? 's' : ''}',
                      style: AppTheme.caption),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Total
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL', style: AppTheme.label),
                  Text(
                    '${controller.cartTotal.toStringAsFixed(2)} MAD',
                    style: AppTheme.title1
                        .copyWith(color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            // Confirm button
            SizedBox(
              width: 160,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isEmpty ? null : controller.confirmOrder,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('CONFIRMER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isEmpty ? AppTheme.border : AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.border,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
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
