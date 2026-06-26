import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../controllers/table_details_controller.dart';
import '../data/demo_table_menu.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';
import '../utils/app_theme.dart';

class TableDetailsPage extends GetView<TableDetailsController> {
  const TableDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Obx(() {
          if (!Get.isRegistered<SessionController>()) {
            return const SizedBox.shrink();
          }

          final session = Get.find<SessionController>();
          SessionOrder? order;
          for (final item in session.orders) {
            if (item.number == controller.orderNumber) {
              order = item;
              break;
            }
          }

          if (order == null) {
            return Center(
              child: Text(
                'Table introuvable',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return Column(
            children: [
              _TableDetailsHeader(order: order),
              const Divider(height: 1, color: Color(0xFFE8E8E8)),
              Expanded(
                child: Obx(() {
                  final expanded = controller.isBottomPanelExpanded.value;
                  final showPayment = controller.showPaymentOptions.value;
                  SessionOrder? currentOrder;
                  for (final item in session.orders) {
                    if (item.number == controller.orderNumber) {
                      currentOrder = item;
                      break;
                    }
                  }
                  currentOrder ??= order!;

                  return Column(
                    children: [
                      Expanded(child: _OrderSummary(order: currentOrder)),
                      const _ActionToolbar(),
                      if (showPayment)
                        const _PaymentButtons()
                      else if (expanded) ...[
                        const _CategoryTabs(),
                        const Expanded(flex: 2, child: _MenuGrid()),
                      ],
                    ],
                  );
                }),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _TableDetailsHeader extends StatelessWidget {
  const _TableDetailsHeader({required this.order});

  final SessionOrder order;

  String _currentTime() {
    final now = TimeOfDay.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: order.numberColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              order.number,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: order.numberColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.person_outline, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            order.couverts,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const Spacer(),
          Text(
            order.profitCenter,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Text(
            _currentTime(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order summary ──────────────────────────────────────────────────────────────

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final SessionOrder order;

  static const _productSlidableGroupTag = 'table-details-products';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  'QTÉ',
                  style: _headerStyle,
                ),
              ),
              Expanded(
                flex: 5,
                child: Text('ARTICLE', style: _headerStyle),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PRIX',
                  textAlign: TextAlign.right,
                  style: _headerStyle,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SlidableAutoCloseBehavior(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: order.products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) => _ProductLine(
                orderNumber: order.number,
                productIndex: index,
                product: order.products[index],
                groupTag: _productSlidableGroupTag,
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8E8E8)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              const Spacer(),
              Text(
                order.total,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static final _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppTheme.textSecondary,
  );
}

class _ProductLine extends GetView<TableDetailsController> {
  const _ProductLine({
    required this.orderNumber,
    required this.productIndex,
    required this.product,
    required this.groupTag,
  });

  final String orderNumber;
  final int productIndex;
  final OrderProduct product;
  final String groupTag;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey('$orderNumber-$productIndex-${product.name}'),
      groupTag: groupTag,
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.52,
        children: [
          _ProductSlidableAction(
            icon: Icons.card_giftcard_outlined,
            backgroundColor: AppTheme.lightButton,
            iconColor: AppTheme.primary,
            onPressed: () => controller.offerProduct(productIndex),
          ),
          _ProductSlidableAction(
            icon: Icons.remove,
            onPressed: () => controller.decrementProduct(productIndex),
          ),
          _ProductSlidableAction(
            icon: Icons.add,
            onPressed: () => controller.incrementProduct(productIndex),
          ),
          _ProductSlidableAction(
            icon: Icons.edit_outlined,
            onPressed: () => _showMessageDialog(context),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Text(
                product.quantity,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkText,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (product.message != null &&
                      product.message!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          product.message!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
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
            Expanded(
              flex: 2,
              child: Text(
                product.price,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(BuildContext context) {
    final messageController = TextEditingController(text: product.message ?? '');

    Get.dialog(
      AlertDialog(
        title: Text(
          'Message',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product.name,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ex: À SUIVRE',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('ANNULER', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              controller.setProductMessage(
                productIndex: productIndex,
                message: messageController.text,
              );
              Get.back();
            },
            child: const Text(
              'ENREGISTRER',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}

class _ProductSlidableAction extends StatelessWidget {
  const _ProductSlidableAction({
    required this.icon,
    required this.onPressed,
    this.backgroundColor = const Color(0xFFF0F0F0),
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? AppTheme.darkText,
        ),
      ),
    );
  }
}

// ── Action toolbar ─────────────────────────────────────────────────────────────

class _ActionToolbar extends StatefulWidget {
  const _ActionToolbar();

  @override
  State<_ActionToolbar> createState() => _ActionToolbarState();
}

class _ActionToolbarState extends State<_ActionToolbar> {
  late final ScrollController _scrollController;

  static const _icons = [
    Icons.home_outlined,
    Icons.keyboard_return_outlined,
    Icons.grid_view,
    Icons.arrow_forward,
    Icons.restaurant,
    Icons.restaurant_menu,
    Icons.message_outlined,
    Icons.receipt_long_outlined,
    Icons.payments_outlined,
    Icons.send_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TableDetailsController>();

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8)),
          bottom: BorderSide(color: Color(0xFFE8E8E8)),
        ),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Obx(() {
            final expanded = controller.isBottomPanelExpanded.value;

            return Row(
              children: [
                for (final icon in _icons)
                  _ToolbarIconButton(
                    icon: icon,
                    isActive: controller.isToolbarIconActive(icon),
                    onPressed: () => controller.onToolbarIconTap(icon),
                  ),
                _ToolbarIconButton(
                  icon: expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  isActive: expanded && !controller.showPaymentOptions.value,
                  onPressed: controller.toggleBottomPanel,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 22,
        color: isActive ? AppTheme.primary : AppTheme.textSecondary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      constraints: const BoxConstraints(),
    );
  }
}

// ── Payment buttons ────────────────────────────────────────────────────────────

class _PaymentButtons extends StatelessWidget {
  const _PaymentButtons();

  static const _cashGrey = Color(0xFFB8B8B8);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _PaymentButton(
              label: 'ESPECE',
              backgroundColor: _cashGrey,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PaymentButton(
              label: 'CARTE DE CREDIT',
              backgroundColor: AppTheme.primary,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentButton extends StatelessWidget {
  const _PaymentButton({
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category tabs ──────────────────────────────────────────────────────────────

class _CategoryTabs extends GetView<TableDetailsController> {
  const _CategoryTabs();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedIndex = controller.selectedCategoryIndex.value;

      return SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: demoTableMenuCategories.length,
          itemBuilder: (context, index) {
            final category = demoTableMenuCategories[index];
            final isSelected = selectedIndex == index;

            return GestureDetector(
              onTap: () => controller.selectCategory(index),
              child: Container(
                margin: const EdgeInsets.only(right: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

// ── Menu grid ──────────────────────────────────────────────────────────────────

class _MenuGrid extends GetView<TableDetailsController> {
  const _MenuGrid();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedIndex = controller.selectedCategoryIndex.value;
      final selectedItems = controller.selectedMenuItems.toSet();
      final items = demoTableMenuCategories[selectedIndex].items;

      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selectedItems.contains(item.name);

          return GestureDetector(
            onTap: () => controller.toggleMenuItem(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: _menuGridItemBackground(isSelected),
                borderRadius: BorderRadius.circular(10),
                border: _menuGridItemBorder(isSelected),
                boxShadow: _menuGridItemShadow(isSelected),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      item.name,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText.withValues(alpha: 0.85),
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

Color _menuGridItemBackground(bool isSelected) {
  if (Get.isDarkMode) {
    return AppTheme.inactiveSurface;
  }

  return isSelected ? AppTheme.lightButton : AppTheme.background;
}

Border? _menuGridItemBorder(bool isSelected) {
  if (Get.isDarkMode) {
    return isSelected
        ? Border.all(color: AppTheme.primary, width: 2)
        : null;
  }

  return Border.all(
    color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
    width: isSelected ? 2 : 1,
  );
}

List<BoxShadow>? _menuGridItemShadow(bool isSelected) {
  if (Get.isDarkMode) return null;

  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
}
