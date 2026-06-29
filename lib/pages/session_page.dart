import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';
import '../routes/app_pages.dart';
import '../utils/app_navigation.dart';
import '../utils/app_theme.dart';
import '../utils/responsive.dart';

class SessionPage extends GetView<SessionController> {
  const SessionPage({super.key});

  static const _orderSlidableGroupTag = 'session-orders';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _SessionHeader(),
            Divider(height: 1, color: AppTheme.cardBorder),
            const _TableHeader(),
            Expanded(
              child: SlidableAutoCloseBehavior(
                child: Obx(
                  () => ListView.separated(
                    padding: JtrResponsive.getResponsivePadding(
                      context,
                      top: 8,
                      bottom: 8,
                    ),
                    itemCount: controller.orders.length,
                    separatorBuilder: (context, index) =>
                        JtrResponsive.getResponsiveSpacing(context, 8),
                    itemBuilder: (context, index) {
                      return _OrderRow(order: controller.orders[index]);
                    },
                  ),
                ),
              ),
            ),
            const _ActionButtons(),
            Divider(height: 1, color: AppTheme.cardBorder),
            _BottomNavBar(),
          ],
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        left: 16,
        right: 16,
        top: 12,
        bottom: 12,
      ),
      child: Row(
        children: [
          Container(
            width: JtrResponsive.getResponsiveSize(context, 44),
            height: JtrResponsive.getResponsiveSize(context, 44),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '1',
              style: TextStyle(
                color: Colors.white,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          JtrResponsive.getResponsiveHorizontalSpacing(context, 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MANAGER',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    color: AppTheme.textSecondary,
                  ),
                ),
                JtrResponsive.getResponsiveSpacing(context, 2),
                Text(
                  'Vendredi 12 Juin 2026',
                  style: TextStyle(
                    fontSize: JtrResponsive.getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: JtrResponsive.getResponsivePadding(
              context,
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.lightButton,
              borderRadius: BorderRadius.circular(
                JtrResponsive.getResponsiveRadius(context, 20),
              ),
            ),
            child: Text(
              'SUR PLACE',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTableLayout {
  _SessionTableLayout._();

  static EdgeInsets outerPadding(BuildContext context) =>
      JtrResponsive.getResponsivePadding(context, horizontal: 8);

  static EdgeInsets innerPadding(BuildContext context) =>
      JtrResponsive.getResponsivePadding(context, horizontal: 0, vertical: 12);

  static TextStyle headerStyle(BuildContext context) => TextStyle(
        fontSize: JtrResponsive.getResponsiveFontSize(context, 9),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppTheme.textSecondary,
        height: 1.2,
      );

  static TextStyle cellStyle(BuildContext context) => TextStyle(
        fontSize: JtrResponsive.getResponsiveFontSize(context, 9),
        fontWeight: FontWeight.w500,
        color: AppTheme.darkText,
      );
}

class _SessionTableRow extends StatelessWidget {
  const _SessionTableRow({
    required this.cells,
    this.padding,
  });

  final List<Widget> cells;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    assert(cells.length == 7);

    return Padding(
      padding: _SessionTableLayout.outerPadding(context),
      child: Padding(
        padding: padding ?? _SessionTableLayout.innerPadding(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final cell in cells)
              Expanded(
                child: Center(child: cell),
              ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        top: 10,
        bottom: 4,
      ),
      child: _SessionTableRow(
        padding: JtrResponsive.getResponsivePadding(context, horizontal: 12),
        cells: [
          Text('N°', textAlign: TextAlign.center, style: _SessionTableLayout.headerStyle(context)),
          Text('G.', textAlign: TextAlign.center, style: _SessionTableLayout.headerStyle(context)),
          Text('POSTE', textAlign: TextAlign.center, style: _SessionTableLayout.headerStyle(context)),
          Text('CTR.\nPROFIT', textAlign: TextAlign.center, style: _SessionTableLayout.headerStyle(context)),
          Text('CVT.', textAlign: TextAlign.center, style: _SessionTableLayout.headerStyle(context)),
          Text('IMP.', textAlign: TextAlign.center, style: _SessionTableLayout.headerStyle(context)),
          Text('TOTAL', textAlign: TextAlign.center, style: _SessionTableLayout.headerStyle(context)),
        ],
      ),
    );
  }
}

class _OrderRow extends GetView<SessionController> {
  const _OrderRow({required this.order});

  final SessionOrder order;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.tableUiState.value;
      final isExpanded = state.expandedOrderNumber == order.number;
      final isRowSelected = state.selectedRow?.orderNumber == order.number &&
          state.selectedRow?.productIndex == null;
      final cardRadius = JtrResponsive.getResponsiveRadius(context, 12);

      return Padding(
        padding: _SessionTableLayout.outerPadding(context),
        child: Slidable(
          key: ValueKey(order.number),
          groupTag: SessionPage._orderSlidableGroupTag,
          startActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.14,
            children: [
              SlidableAction(
                onPressed: (_) => controller.requestDeleteOrder(order.number),
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
            extentRatio: 0.14,
            children: [
              SlidableAction(
                onPressed: (_) => controller.requestApplyOffer(order.number),
                backgroundColor: AppTheme.background,
                foregroundColor: AppTheme.primary,
                icon: Icons.local_offer_outlined,
                spacing: 0,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          child: GestureDetector(
            onDoubleTap: () => controller.openTableDetails(order.number),
            child: Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: AppTheme.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                decoration: BoxDecoration(
                  color: isRowSelected ? AppTheme.lightButton : Colors.transparent,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(cardRadius),
                    bottom: isExpanded ? Radius.zero : Radius.circular(cardRadius),
                  ),
                ),
                child: Padding(
                  padding: _SessionTableLayout.innerPadding(context),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _OrderTableCell(
                        orderNumber: order.number,
                        expandOnTap: true,
                        child: Text(
                          order.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: JtrResponsive.getResponsiveFontSize(context, 13),
                            fontWeight: FontWeight.bold,
                            color: order.numberColor,
                          ),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        child: Text(
                          order.group,
                          textAlign: TextAlign.center,
                          style: _SessionTableLayout.cellStyle(context),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        child: Text(
                          order.poste,
                          textAlign: TextAlign.center,
                          style: _SessionTableLayout.cellStyle(context),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        child: Text(
                          order.profitCenter,
                          textAlign: TextAlign.center,
                          style: _SessionTableLayout.cellStyle(context).copyWith(
                            fontSize: JtrResponsive.getResponsiveFontSize(context, 9),
                            height: 1.2,
                          ),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        child: Text(
                          order.couverts,
                          textAlign: TextAlign.center,
                          style: _SessionTableLayout.cellStyle(context),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        child: Container(
                          width: JtrResponsive.getResponsiveSize(context, 22),
                          height: JtrResponsive.getResponsiveSize(context, 22),
                          decoration: BoxDecoration(
                            color: order.impressionColor,
                            borderRadius: BorderRadius.circular(
                              JtrResponsive.getResponsiveRadius(context, 6),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${order.impressionCount}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        child: Text(
                          order.total,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                Divider(height: 1, color: AppTheme.cardBorder),
                for (var i = 0; i < order.products.length; i++) ...[
                  _ProductRow(
                    orderNumber: order.number,
                    productIndex: i,
                    product: order.products[i],
                  ),
                  if (i < order.products.length - 1)
                    Divider(height: 1, color: AppTheme.subtleDivider),
                ],
                JtrResponsive.getResponsiveSpacing(context, 4),
              ],
            ],
            ),
          ),
          ),
        ),
      );
    });
  }
}

class _OrderTableCell extends GetView<SessionController> {
  const _OrderTableCell({
    required this.orderNumber,
    required this.child,
    this.expandOnTap = false,
  });

  final String orderNumber;
  final Widget child;
  final bool expandOnTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.selectRow(
          orderNumber: orderNumber,
          expandOnNumberTap: expandOnTap,
        ),
        behavior: HitTestBehavior.opaque,
        child: Center(child: child),
      ),
    );
  }
}

class _ProductRow extends GetView<SessionController> {
  const _ProductRow({
    required this.orderNumber,
    required this.productIndex,
    required this.product,
  });

  final String orderNumber;
  final int productIndex;
  final OrderProduct product;

  @override
  Widget build(BuildContext context) {
    final productStyle = TextStyle(
      fontSize: JtrResponsive.getResponsiveFontSize(context, 10),
      fontWeight: FontWeight.w500,
      color: AppTheme.textSecondary,
      letterSpacing: 0.2,
    );

    return Obx(() {
      final selected = controller.tableUiState.value.selectedRow;
      final isRowSelected = selected?.orderNumber == orderNumber &&
          selected?.productIndex == productIndex;

      return ColoredBox(
        color: isRowSelected ? AppTheme.lightButton : Colors.transparent,
        child: Padding(
          padding: JtrResponsive.getResponsivePadding(
            context,
            horizontal: 12,
            vertical: 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.selectRow(
                    orderNumber: orderNumber,
                    productIndex: productIndex,
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: JtrResponsive.getResponsivePadding(
                      context,
                      vertical: 8,
                    ),
                    child: Text(
                      product.quantity,
                      textAlign: TextAlign.center,
                      style: productStyle,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: GestureDetector(
                  onTap: () => controller.selectRow(
                    orderNumber: orderNumber,
                    productIndex: productIndex,
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: JtrResponsive.getResponsivePadding(
                      context,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        product.name,
                        textAlign: TextAlign.left,
                        style: productStyle.copyWith(
                          color: AppTheme.darkText.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.selectRow(
                    orderNumber: orderNumber,
                    productIndex: productIndex,
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: JtrResponsive.getResponsivePadding(
                      context,
                      vertical: 8,
                    ),
                    child: Text(
                      product.price,
                      textAlign: TextAlign.center,
                      style: productStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
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

class _ActionButtons extends GetView<SessionController> {
  const _ActionButtons();

  static const _actions = [
    (
      action: SessionAction.nouvelleCommande,
      label: 'NOUVELLE\nCOMMANDE',
      icon: Icons.add,
      iconSize: 28.0,
    ),
    (
      action: SessionAction.demanderSuite,
      label: 'DEMANDER\nLA SUITE',
      icon: Icons.restaurant,
      iconSize: 32.0,
    ),
    (
      action: SessionAction.ticket,
      label: 'TICKET',
      icon: Icons.receipt_long_outlined,
      iconSize: 32.0,
    ),
    (
      action: SessionAction.statistics,
      label: 'STATISTICS',
      icon: Icons.bar_chart_rounded,
      iconSize: 32.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        left: 12,
        right: 12,
        top: 8,
        bottom: 8,
      ),
      child: Obx(
        () => Row(
          children: [
            for (var i = 0; i < _actions.length; i++) ...[
              if (i > 0) JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
              Expanded(
                child: _ActionButton(
                  label: _actions[i].label,
                  icon: _actions[i].icon,
                  iconSize: _actions[i].iconSize,
                  isActive: controller.selectedAction.value == _actions[i].action,
                  onTap: () {
                    final action = _actions[i].action;
                    if (action == SessionAction.ticket) {
                      controller.printTicket();
                    } else if (action == SessionAction.nouvelleCommande) {
                      controller.showTableNumberDialog();
                    } else if (action == SessionAction.demanderSuite) {
                      controller.requestNextCourse();
                    } else if (action == SessionAction.statistics) {
                      controller.selectAction(action);
                      Get.toNamed(AppRoutes.statistics);
                    } else {
                      controller.selectAction(action);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.iconSize,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final double iconSize;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isActive ? AppTheme.primary : AppTheme.inactiveSurface;
    final labelColor = isActive ? Colors.white : AppTheme.darkText;
    final iconColor = isActive ? Colors.white : AppTheme.actionIcon;
    final responsiveIconSize = JtrResponsive.getResponsiveSize(context, iconSize);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: JtrResponsive.adaptiveHeight(context, 110, compact: 78),
        padding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 6,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(
            JtrResponsive.getResponsiveRadius(context, 16),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActive)
              Container(
                width: JtrResponsive.getResponsiveSize(context, 44),
                height: JtrResponsive.getResponsiveSize(context, 44),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(
                    JtrResponsive.getResponsiveRadius(context, 12),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: responsiveIconSize),
              )
            else
              Icon(icon, color: iconColor, size: responsiveIconSize),
            JtrResponsive.getResponsiveSpacing(context, 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 9),
                fontWeight: FontWeight.bold,
                height: 1.2,
                letterSpacing: 0.3,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iconSize = JtrResponsive.getResponsiveSize(context, 28);

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
            icon: Icon(Icons.home, color: AppTheme.primary, size: iconSize),
          ),
          IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Icons.arrow_back, color: AppTheme.darkText, size: iconSize),
          ),
          IconButton(
            onPressed: AppNavigation.logout,
            icon: Icon(
              Icons.logout,
              color: const Color(0xFF2EC4B6),
              size: iconSize,
            ),
          ),
        ],
      ),
    );
  }
}
