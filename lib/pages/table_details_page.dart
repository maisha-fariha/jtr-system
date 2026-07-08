import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import '../data/models/catalog/category_tree_node.dart';
import '../controllers/session_controller.dart';
import '../controllers/table_details_controller.dart';
import '../models/order_display_entry.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/api_debug_dialog.dart';

class TableDetailsPage extends GetView<TableDetailsController> {
  const TableDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await controller.navigateBackOrExitTable();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Obx(() {
          if (!Get.isRegistered<SessionController>()) {
            return const SizedBox.shrink();
          }

          final session = Get.find<SessionController>();
          final order = session.findOrder(
            orderNumber: controller.orderNumber,
            orderId: controller.orderId,
          );

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
                  SessionOrder? currentOrder = session.findOrder(
                    orderNumber: controller.orderNumber,
                    orderId: controller.orderId,
                  );
                  currentOrder ??= order;

                  final showCatalog =
                      showPayment || expanded;
                  final useSideBySide =
                      JtrResponsive.isLargeDevice(context) && showCatalog;

                  if (useSideBySide) {
                    return Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _OrderSummary(
                                  orderNumber: controller.orderNumber,
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                color: Color(0xFFE8E8E8),
                              ),
                              Expanded(
                                child: showPayment
                                    ? const _PaymentButtons()
                                    : Column(
                                        children: const [
                                          _CategoryTabs(),
                                          Expanded(child: _MenuGrid()),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const _ActionToolbar(),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: _OrderSummary(
                          orderNumber: controller.orderNumber,
                        ),
                      ),
                      const _ActionToolbar(),
                      if (showPayment)
                        const Expanded(flex: 1, child: _PaymentButtons())
                      else if (expanded) ...[
                        const _CategoryTabs(),
                        const Expanded(flex: 1, child: _MenuGrid()),
                      ],
                    ],
                  );
                }),
              ),
            ],
          );
        }),
      ),
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
      padding: JtrResponsive.getResponsivePadding(
        context,
        left: 16,
        right: 16,
        top: 10,
        bottom: 10,
      ),
      child: Row(
        children: [
          Container(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: order.numberColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(
                JtrResponsive.getResponsiveRadius(context, 8),
              ),
            ),
            child: Text(
              order.number,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w800,
                color: order.numberColor,
              ),
            ),
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
          Icon(
            Icons.person_outline,
            size: JtrResponsive.getResponsiveSize(context, 18),
            color: AppTheme.textSecondary,
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 4),
          Text(
            order.couverts,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const Spacer(),
          Text(
            order.profitCenter,
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Text(
            _currentTime(),
            style: TextStyle(
              fontSize: JtrResponsive.getResponsiveFontSize(context, 14),
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

class _OrderSummary extends StatefulWidget {
  const _OrderSummary({required this.orderNumber});

  final String orderNumber;

  @override
  State<_OrderSummary> createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<_OrderSummary> {
  static const _productSlidableGroupTag = 'table-details-products';

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _lastRowKey = GlobalKey();
  int _lastProductCount = -1;

  TableDetailsController get controller => Get.find<TableDetailsController>();

  String get orderNumber => widget.orderNumber;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatestItemIfNeeded(SessionOrder order) {
    final lineCount = order.displayEntries
        .where((entry) => entry.type == OrderDisplayEntryType.product)
        .length;

    if (_lastProductCount < 0) {
      _lastProductCount = lineCount;
      return;
    }

    if (lineCount <= _lastProductCount) {
      _lastProductCount = lineCount;
      return;
    }

    _lastProductCount = lineCount;
    _scrollToLastRow();
  }

  void _scrollToLastRow() {
    void attemptScroll(int attempt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = _lastRowKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            alignment: 1.0,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
          return;
        }

        if (_scrollController.hasClients) {
          final position = _scrollController.position;
          _scrollController.jumpTo(position.maxScrollExtent);
        }

        if (attempt < 4) {
          attemptScroll(attempt + 1);
        }
      });
    }

    attemptScroll(0);
  }

  SessionOrder? _resolveOrder() {
    if (!Get.isRegistered<SessionController>()) return null;
    return Get.find<SessionController>().findOrder(
      orderNumber: orderNumber,
      orderId: controller.orderId,
    );
  }

  SessionOrder? _resolveOrderFromSession(SessionController session) {
    final targetId = controller.resolvedOrderId;
    for (final candidate in session.orders) {
      if (targetId != null && targetId > 0 && candidate.id == targetId) {
        return candidate;
      }
    }
    for (final candidate in session.orders) {
      if (candidate.number == orderNumber ||
          SessionController.normalizeTableKey(candidate.number) ==
              SessionController.normalizeTableKey(orderNumber)) {
        return candidate;
      }
    }
    return _resolveOrder();
  }

  TextStyle _headerStyle(BuildContext context) => TextStyle(
        fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppTheme.textSecondary,
      );

  List<Widget> _buildVisibleRows(BuildContext context, SessionOrder order) {
    final rows = <Widget>[];
    final entries = order.displayEntries;
    var index = 0;

    while (index < entries.length) {
      final entry = entries[index];

      if (entry.isSectionDivider) {
        final sectionIndex = entry.sectionIndex ?? 0;
        final collapsed = controller.isSuivreSectionCollapsed(sectionIndex);
        final isDemande =
            entry.type == OrderDisplayEntryType.demandeSeparator;

        rows.add(
          _CourseSectionDivider(
            sectionIndex: sectionIndex,
            isDemande: isDemande,
            demandeTimeLabel: entry.demandeTimeLabel,
            isCollapsed: collapsed,
            onSelect: isDemande
                ? null
                : () => controller.selectSuivreSection(sectionIndex),
            onToggleCollapse: () =>
                controller.toggleSuivreSection(sectionIndex),
            groupTag: _productSlidableGroupTag,
          ),
        );
        index++;

        if (!collapsed) {
          while (index < entries.length && !entries[index].isSectionDivider) {
            final productEntry = entries[index];
            if (productEntry.type != OrderDisplayEntryType.product) {
              index++;
              continue;
            }
            rows.add(
              _ProductLine(
                orderNumber: order.number,
                productIndex: productEntry.lineIndex!,
                product: productEntry.product!,
                groupTag: _productSlidableGroupTag,
              ),
            );
            index++;
          }
        } else {
          while (index < entries.length && !entries[index].isSectionDivider) {
            index++;
          }
        }
        continue;
      }

      final productEntry = entry;
      rows.add(
        _ProductLine(
          orderNumber: order.number,
          productIndex: productEntry.lineIndex!,
          product: productEntry.product!,
          groupTag: _productSlidableGroupTag,
        ),
      );
      index++;
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!Get.isRegistered<SessionController>()) {
        return const SizedBox.shrink();
      }

      final session = Get.find<SessionController>();
      session.orders.length;
      controller.suivreUiRevision.value;
      controller.selectedSuivreSection.value;

      final resolvedOrder = _resolveOrderFromSession(session);
      if (resolvedOrder == null) {
        return const SizedBox.shrink();
      }

      final rows = _buildVisibleRows(context, resolvedOrder);
      _scrollToLatestItemIfNeeded(resolvedOrder);

      return Column(
        children: [
          Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              left: 20,
              right: 20,
              top: 12,
              bottom: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'QTÉ',
                    style: _headerStyle(context),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text('ARTICLE', style: _headerStyle(context)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PRIX',
                    textAlign: TextAlign.right,
                    style: _headerStyle(context),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SlidableAutoCloseBehavior(
              child: ListView.separated(
                controller: _scrollController,
                key: ValueKey(resolvedOrder.id),
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 20,
                  bottom: 12,
                ),
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    JtrResponsive.getResponsiveSpacing(context, 4),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  if (index != rows.length - 1) return row;
                  return KeyedSubtree(
                    key: _lastRowKey,
                    child: row,
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E8E8)),
          Padding(
            padding: JtrResponsive.getResponsivePadding(
              context,
              left: 20,
              right: 20,
              top: 6,
              bottom: 6,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 14),
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    resolvedOrder.total,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize:
                          JtrResponsive.getResponsiveFontSize(context, 15),
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _CourseSectionDivider extends GetView<TableDetailsController> {
  static const Color _demandeGreen = Color(0xFF27AE60);

  const _CourseSectionDivider({
    required this.sectionIndex,
    required this.isDemande,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.groupTag,
    this.demandeTimeLabel,
    this.onSelect,
  });

  final int sectionIndex;
  final bool isDemande;
  final String? demandeTimeLabel;
  final bool isCollapsed;
  final VoidCallback? onSelect;
  final VoidCallback onToggleCollapse;
  final String groupTag;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final collapsed = controller.isSuivreSectionCollapsed(sectionIndex);
      final selected = !isDemande &&
          controller.isSuivreSectionSelected(sectionIndex);
      controller.suivreUiRevision.value;
      controller.selectedSuivreSection.value;

      final accentColor = isDemande ? _demandeGreen : AppTheme.primary;
      final label = isDemande
          ? 'DEMANDÉE À ${demandeTimeLabel ?? '--:--:--'}'
          : 'À SUIVRE';

      final content = InkWell(
        onTap: isDemande ? onToggleCollapse : onSelect,
        borderRadius: BorderRadius.circular(
          JtrResponsive.getResponsiveRadius(context, 6),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.14)
                : null,
            borderRadius: BorderRadius.circular(
              JtrResponsive.getResponsiveRadius(context, 6),
            ),
            border: selected
                ? Border.all(color: AppTheme.primary, width: 1.5)
                : null,
          ),
          padding: JtrResponsive.getResponsivePadding(context, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 0.6,
                ),
              ),
              JtrResponsive.getResponsiveHorizontalSpacing(context, 4),
              GestureDetector(
                onTap: onToggleCollapse,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  collapsed ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                  color: accentColor,
                  size: JtrResponsive.getResponsiveSize(context, 20),
                ),
              ),
            ],
          ),
        ),
      );

      if (isDemande) {
        return KeyedSubtree(
          key: ValueKey('demande-$sectionIndex'),
          child: content,
        );
      }

      return Slidable(
        key: ValueKey('suivre-$sectionIndex'),
        groupTag: groupTag,
        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.14,
          children: [
            SlidableAction(
              onPressed: (_) => controller.cancelSuivreSection(sectionIndex),
              backgroundColor: AppTheme.background,
              foregroundColor: const Color(0xFFE74C3C),
              icon: CupertinoIcons.delete,
              spacing: 0,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        child: content,
      );
    });
  }
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
    return Obx(() {
      final isSelected = controller.isOrderLineSelected(productIndex);

      return Slidable(
        key: ValueKey('$orderNumber-$productIndex-${product.name}'),
        groupTag: groupTag,
        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.14,
          children: [
            SlidableAction(
              onPressed: (_) => controller.cancelOrderLine(productIndex),
              backgroundColor: AppTheme.background,
              foregroundColor: const Color(0xFFE74C3C),
              icon: CupertinoIcons.delete,
              spacing: 0,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.39,
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
          ],
        ),
        child: Material(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: InkWell(
            onTap: () => controller.selectOrderLine(productIndex, product),
            child: Padding(
              padding: JtrResponsive.getResponsivePadding(context, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      product.quantity,
                      style: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(context, 14),
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
                            fontSize:
                                JtrResponsive.getResponsiveFontSize(context, 13),
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.darkText,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product.message != null &&
                            product.message!.isNotEmpty) ...[
                          JtrResponsive.getResponsiveSpacing(context, 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  product.message!,
                                  style: TextStyle(
                                    fontSize:
                                        JtrResponsive.getResponsiveFontSize(
                                      context,
                                      11,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: JtrResponsive.getResponsiveSize(
                                  context,
                                  14,
                                ),
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
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ProductSlidableAction extends StatelessWidget {
  const _ProductSlidableAction({
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.slidableActionBackground;
    final fgColor = iconColor ?? AppTheme.darkText;

    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: Colors.transparent,
      padding: JtrResponsive.getResponsivePadding(context, left: 6),
      child: Container(
        width: JtrResponsive.getResponsiveSize(context, 44),
        height: JtrResponsive.getResponsiveSize(context, 44),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(
            JtrResponsive.getResponsiveRadius(context, 10),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: JtrResponsive.getResponsiveSize(context, 20),
          color: fgColor,
        ),
      ),
    );
  }
}

// ── Action toolbar ─────────────────────────────────────────────────────────────

double _categoryPartFontSize(BuildContext context, double base) {
  final fontSize = JtrResponsive.getResponsiveFontSize(context, base);
  if (JtrResponsive.isLargeDevice(context)) {
    return fontSize + 2;
  }
  return fontSize;
}

double _toolbarIconSize(BuildContext context) {
  final size = JtrResponsive.getResponsiveSize(context, 22);
  if (JtrResponsive.isLargeDevice(context)) {
    return size + 2;
  }
  return size;
}

class _ActionToolbar extends StatefulWidget {
  const _ActionToolbar();

  @override
  State<_ActionToolbar> createState() => _ActionToolbarState();
}

class _ActionToolbarState extends State<_ActionToolbar> {
  late final ScrollController _scrollController;

  static const _icons = [
    Icons.keyboard_return_outlined,
    Icons.grid_view,
    Icons.menu_book,
    Icons.restaurant,
    Icons.restaurant_menu,
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
    final isLarge = JtrResponsive.isLargeDevice(context);

    Widget buildIconRow(BuildContext toolbarContext) {
      return Obx(() {
        final expanded = controller.isBottomPanelExpanded.value;

        return Row(
          mainAxisAlignment:
              isLarge ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
          children: [
            for (final icon in _icons)
              _ToolbarIconButton(
                icon: icon,
                isActive: controller.isToolbarIconActive(icon),
                isEnabled: controller.isToolbarIconEnabled(icon),
                onPressed: () =>
                    controller.onToolbarIconTap(icon, context: toolbarContext),
                compact: isLarge,
              ),
            _ToolbarIconButton(
              icon: expanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              isActive: expanded && !controller.showPaymentOptions.value,
              onPressed: controller.toggleBottomPanel,
              compact: isLarge,
            ),
          ],
        );
      });
    }

    return Container(
      padding: JtrResponsive.getResponsivePadding(
        context,
        top: 10,
        bottom: 4,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8)),
          bottom: BorderSide(color: Color(0xFFE8E8E8)),
        ),
      ),
      child: isLarge
          ? Padding(
              padding: JtrResponsive.getResponsivePadding(
                context,
                horizontal: 12,
              ),
              child: buildIconRow(context),
            )
          : Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: JtrResponsive.getResponsivePadding(
                  context,
                  horizontal: 12,
                ),
                child: buildIconRow(context),
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
    this.isEnabled = true,
    this.compact = false,
  });

  final IconData icon;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.toolbarIconColor(
      icon,
      active: isActive,
      enabled: isEnabled,
    );

    final tapSize = JtrResponsive.getResponsiveSize(context, 44);

    return SizedBox(
      width: tapSize,
      height: tapSize,
      child: IconButton(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(
          icon,
          size: _toolbarIconSize(context),
          color: color,
        ),
        padding: compact
            ? EdgeInsets.zero
            : JtrResponsive.getResponsivePadding(context, horizontal: 4),
        constraints: BoxConstraints(
          minWidth: tapSize,
          minHeight: tapSize,
        ),
      ),
    );
  }
}

// ── Payment buttons ────────────────────────────────────────────────────────────

class _PaymentButtons extends GetView<TableDetailsController> {
  const _PaymentButtons();

  static const _cashGrey = Color(0xFFB8B8B8);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.paymentModesLoading.value;
      final error = controller.paymentModesError.value;
      final busy = controller.isAddingProduct.value;
      final canPay = controller.canPay;

      return Padding(
        padding: JtrResponsive.getResponsivePadding(
          context,
          left: 16,
          right: 16,
          top: 12,
          bottom: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Total à encaisser : ${controller.payableTotalLabel}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 15),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (loading) ...[
              JtrResponsive.getResponsiveSpacing(context, 12),
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            ] else if (error != null) ...[
              JtrResponsive.getResponsiveSpacing(context, 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                ),
              ),
              JtrResponsive.getResponsiveSpacing(context, 8),
              TextButton(
                onPressed: busy ? null : () => controller.reloadPaymentModes(),
                child: const Text('Réessayer'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        final log = controller.lastPaymentModesLoadLog;
                        if (log == null || log.isEmpty) return;
                        ApiDebugDialog.show(
                          title: 'Chargement modes de paiement',
                          body: log,
                        );
                      },
                child: const Text('Détails'),
              ),
            ] else ...[
              JtrResponsive.getResponsiveSpacing(context, 12),
              Row(
                children: [
                  Expanded(
                    child: _PaymentButton(
                      label: 'ESPECE',
                      backgroundColor: _cashGrey,
                      enabled: canPay,
                      busy: busy,
                      onTap: () =>
                          controller.payOrder(context: context, isCash: true),
                    ),
                  ),
                  JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
                  Expanded(
                    child: _PaymentButton(
                      label: 'CARTE DE CREDIT',
                      backgroundColor: AppTheme.primary,
                      enabled: canPay,
                      busy: busy,
                      onTap: () =>
                          controller.payOrder(context: context, isCash: false),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _PaymentButton extends StatelessWidget {
  const _PaymentButton({
    required this.label,
    required this.backgroundColor,
    required this.onTap,
    this.enabled = true,
    this.busy = false,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;
  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final radius = JtrResponsive.getResponsiveRadius(context, 14);
    final background = enabled ? backgroundColor : backgroundColor.withValues(alpha: 0.45);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: enabled && !busy ? onTap : null,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          height: JtrResponsive.getResponsiveHeight(context, 56),
          alignment: Alignment.center,
          padding: JtrResponsive.getResponsivePadding(context, horizontal: 8),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
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
      if (controller.isCatalogLoading.value && controller.categoryRoots.isEmpty) {
        return const SizedBox(
          height: 44,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }

      if (controller.categoryRoots.isEmpty) {
        return SizedBox(
          height: 44,
          child: Center(
            child: Text(
              controller.catalogError.value ?? 'Aucune catégorie',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        );
      }

      final levelCategories = controller.currentLevelCategories;
      final selectedIndex = controller.selectedCategoryIndex.value;

      return SizedBox(
        height: JtrResponsive.adaptiveHeight(context, 44, compact: 36),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: JtrResponsive.getResponsivePadding(context, horizontal: 16),
          itemCount: levelCategories.length,
          itemBuilder: (context, index) {
            final category = levelCategories[index];
            final isSelected = selectedIndex == index;

            return GestureDetector(
              onTap: () => controller.selectCategory(index),
              child: Container(
                margin: JtrResponsive.getResponsiveMargin(
                  context,
                  right: 20,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: _categoryPartFontSize(context, 12),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      if (controller.isCatalogLoading.value && controller.products.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }

      if (controller.catalogError.value != null &&
          controller.categoryRoots.isEmpty &&
          controller.products.isEmpty) {
        return Center(
          child: Padding(
            padding: JtrResponsive.getResponsivePadding(context, all: 16),
            child: Text(
              controller.catalogError.value!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        );
      }

      if (controller.showingChildCategories) {
        return _CategoryGrid(
          categories: controller.childCategoriesForGrid,
          onCategoryTap: controller.openChildCategory,
        );
      }

      final items = controller.currentProducts;
      if (items.isEmpty) {
        return Center(
          child: Text(
            'Aucun produit dans cette catégorie',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        );
      }

      SessionOrder? currentOrder;
      if (Get.isRegistered<SessionController>()) {
        currentOrder = Get.find<SessionController>().findOrder(
          orderNumber: controller.orderNumber,
          orderId: controller.orderId,
        );
      }

      final isCompact = JtrResponsive.isCompactSquare(context);
      final isLarge = JtrResponsive.isLargeDevice(context);
      final crossAxisCount = JtrResponsive.gridColumns(
        context,
        small: 3,
        medium: 4,
        large: 4,
      );
      final gridSpacing = JtrResponsive.getResponsiveSize(context, 10);
      final gridPadding = JtrResponsive.getResponsivePadding(
        context,
        left: 16,
        right: 16,
        top: 12,
        bottom: 16,
      );

      return LayoutBuilder(
        builder: (context, constraints) {
          final fixedRowCount = isCompact ? 3 : (isLarge ? 4 : null);
          var childAspectRatio = 1.05;

          if (fixedRowCount != null) {
            final availableHeight = constraints.maxHeight -
                gridPadding.vertical -
                gridSpacing * (fixedRowCount - 1);
            final availableWidth = constraints.maxWidth -
                gridPadding.horizontal -
                gridSpacing * (crossAxisCount - 1);
            final cellWidth = availableWidth / crossAxisCount;
            final cellHeight = availableHeight / fixedRowCount;
            if (cellHeight > 0) {
              childAspectRatio = cellWidth / cellHeight;
            }
          }

          return GridView.builder(
            padding: gridPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: gridSpacing,
              crossAxisSpacing: gridSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final product = items[index];
              final isInOrder = controller.isProductInOrder(
                product,
                source: currentOrder,
              );
              final isSelected = controller.isProductSelected(product);
              final orderQty = controller.productQuantityInOrder(
                product,
                source: currentOrder,
              );
              final itemRadius =
                  JtrResponsive.getResponsiveRadius(context, 10);

              return GestureDetector(
                onTap: () => controller.onProductTap(product),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: _menuGridItemBackground(
                      isInOrder: isInOrder,
                      isSelected: isSelected,
                    ),
                    borderRadius: BorderRadius.circular(itemRadius),
                    border: _menuGridItemBorder(
                      isInOrder: isInOrder,
                      isSelected: isSelected,
                    ),
                    boxShadow: _menuGridItemShadow(isSelected),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: JtrResponsive.getResponsivePadding(
                          context,
                          all: 10,
                        ),
                        child: Text(
                          product.name,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _categoryPartFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText.withValues(
                              alpha: isInOrder ? 0.7 : 0.85,
                            ),
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (product.isComposed)
                        Positioned(
                          top: JtrResponsive.getResponsiveHeight(
                            context,
                            6,
                          ),
                          right: JtrResponsive.getResponsiveWidth(
                            context,
                            6,
                          ),
                          child: Icon(
                            Icons.tune,
                            size: JtrResponsive.getResponsiveSize(
                              context,
                              14,
                            ),
                            color: AppTheme.primary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      if (isInOrder)
                        Positioned(
                          bottom: JtrResponsive.getResponsiveHeight(
                            context,
                            8,
                          ),
                          child: Container(
                            padding: JtrResponsive.getResponsivePadding(
                              context,
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(
                                JtrResponsive.getResponsiveRadius(
                                  context,
                                  6,
                                ),
                              ),
                            ),
                            child: Text(
                              '×$orderQty',
                              style: TextStyle(
                                fontSize:
                                    JtrResponsive.getResponsiveFontSize(
                                  context,
                                  10,
                                ),
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    });
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.onCategoryTap,
  });

  final List<CategoryTreeNode> categories;
  final ValueChanged<CategoryTreeNode> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = JtrResponsive.isCompactSquare(context);
    final isLarge = JtrResponsive.isLargeDevice(context);
    final crossAxisCount = JtrResponsive.gridColumns(
      context,
      small: 3,
      medium: 4,
      large: 4,
    );
    final gridSpacing = JtrResponsive.getResponsiveSize(context, 10);
    final gridPadding = JtrResponsive.getResponsivePadding(
      context,
      left: 16,
      right: 16,
      top: 12,
      bottom: 16,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedRowCount = isCompact ? 3 : (isLarge ? 4 : null);
        var childAspectRatio = 1.05;

        if (fixedRowCount != null) {
          final availableHeight = constraints.maxHeight -
              gridPadding.vertical -
              gridSpacing * (fixedRowCount - 1);
          final availableWidth = constraints.maxWidth -
              gridPadding.horizontal -
              gridSpacing * (crossAxisCount - 1);
          final cellWidth = availableWidth / crossAxisCount;
          final cellHeight = availableHeight / fixedRowCount;
          if (cellHeight > 0) {
            childAspectRatio = cellWidth / cellHeight;
          }
        }

        return GridView.builder(
          padding: gridPadding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: gridSpacing,
            crossAxisSpacing: gridSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final itemRadius = JtrResponsive.getResponsiveRadius(context, 10);

            return GestureDetector(
              onTap: () => onCategoryTap(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _menuGridItemBackground(
                    isInOrder: false,
                    isSelected: false,
                  ),
                  borderRadius: BorderRadius.circular(itemRadius),
                  border: _menuGridItemBorder(
                    isInOrder: false,
                    isSelected: false,
                  ),
                  boxShadow: _menuGridItemShadow(false),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: JtrResponsive.getResponsivePadding(
                        context,
                        all: 10,
                      ),
                      child: Text(
                        category.name,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _categoryPartFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText.withValues(alpha: 0.85),
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (category.hasChildren)
                      Positioned(
                        top: JtrResponsive.getResponsiveHeight(context, 6),
                        right: JtrResponsive.getResponsiveWidth(context, 6),
                        child: Icon(
                          Icons.chevron_right,
                          size: JtrResponsive.getResponsiveSize(context, 16),
                          color: AppTheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Color _menuGridItemBackground({
  required bool isInOrder,
  required bool isSelected,
}) {
  if (Get.isDarkMode) {
    if (isSelected) return AppTheme.primary.withValues(alpha: 0.18);
    return AppTheme.inactiveSurface;
  }

  if (isSelected) return AppTheme.lightButton;
  return isInOrder ? AppTheme.lightButton.withValues(alpha: 0.55) : AppTheme.background;
}

Border? _menuGridItemBorder({
  required bool isInOrder,
  required bool isSelected,
}) {
  if (isSelected) {
    return Border.all(color: AppTheme.primary, width: 2.5);
  }

  if (Get.isDarkMode) {
    return isInOrder
        ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1.5)
        : null;
  }

  return Border.all(
    color: isInOrder ? AppTheme.primary.withValues(alpha: 0.45) : AppTheme.cardBorder,
    width: isInOrder ? 1.5 : 1,
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
