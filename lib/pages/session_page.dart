import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import '../controllers/session_controller.dart';
import '../data/mappers/order_mapper.dart';
import '../data/models/sales_zone_info.dart';
import '../models/order_display_entry.dart';
import '../models/order_product.dart';
import '../models/session_order.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_pages.dart';
import '../utils/app_features.dart';
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
        child: Stack(
          children: [
            Column(
          children: [
            _SessionHeader(),
            Divider(height: 1, color: AppTheme.cardBorder),
            const _TableHeader(),
            Expanded(
              child: SlidableAutoCloseBehavior(
                child: Obx(() {
                  if (controller.isLoadingOrders.value &&
                      controller.orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.primary,
                            ),
                          ),
                          JtrResponsive.getResponsiveSpacing(context, 12),
                          Text(
                            'Chargement…',
                            style: TextStyle(
                              fontSize: JtrResponsive.getResponsiveFontSize(
                                context,
                                13,
                              ),
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (controller.orders.isEmpty) {
                    return RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: () => controller.loadSessionOrders(
                        forceRefresh: true,
                        // Full replace + table-key dedupe: avoids draft+server
                        // duplicates after Send → quick swipe refresh.
                        replaceExistingList: true,
                      ),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.35,
                            child: Center(
                              child: Text(
                                controller.ordersError.value ??
                                    'Aucune commande ouverte',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: JtrResponsive.getResponsiveFontSize(
                                    context,
                                    13,
                                  ),
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () => controller.loadSessionOrders(
                      forceRefresh: true,
                      // Full replace + table-key dedupe: avoids draft+server
                      // duplicates after Send → quick swipe refresh.
                      replaceExistingList: true,
                    ),
                    child: const _SessionOrdersList(),
                  );
                }),
              ),
            ),
            const _ActionButtons(),
            if (kShowBottomNavigationBar) ...[
              Divider(height: 1, color: AppTheme.cardBorder),
              _BottomNavBar(),
            ],
          ],
        ),
            Obx(() {
              if (!controller.isCreatingOrder.value) {
                return const SizedBox.shrink();
              }
              return const ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SessionOrdersList extends StatefulWidget {
  const _SessionOrdersList();

  @override
  State<_SessionOrdersList> createState() => _SessionOrdersListState();
}

class _SessionOrdersListState extends State<_SessionOrdersList> {
  final _scrollController = ScrollController();
  Worker? _scrollWorker;

  SessionController get controller => Get.find<SessionController>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _scrollWorker = ever<int>(controller.listScrollSignal, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      });
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (!controller.hasMoreSessionOrders) return;
    if (controller.isLoadingMoreOrders.value) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final fitsOnScreen = position.maxScrollExtent <= 0;
    final nearBottom = position.pixels >= position.maxScrollExtent - 400;
    if (fitsOnScreen || nearBottom) {
      controller.loadMoreSessionOrders();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // toList() so in-place total/product updates rebuild rows
      // (length alone does not always notify Obx).
      controller.listScrollSignal.value;
      controller.isLoadingMoreOrders.value;
      controller.resetSessionListToTop.value;
      final visibleOrders = controller.orders.toList();
      final loadingMore = controller.isLoadingMoreOrders.value;
      final resetToTop = controller.resetSessionListToTop.value;
      if (resetToTop || controller.hasMoreSessionOrders) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          if (controller.resetSessionListToTop.value) {
            _scrollController.jumpTo(0);
            controller.resetSessionListToTop.value = false;
          }
          _onScroll();
        });
      }
      return ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: JtrResponsive.getResponsivePadding(
          context,
          top: 8,
          bottom: 8,
        ),
        itemCount: visibleOrders.length + (loadingMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            JtrResponsive.getResponsiveSpacing(context, 8),
        itemBuilder: (context, index) {
          if (index >= visibleOrders.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _OrderRow(
            order: visibleOrders[index],
          );
        },
      );
    });
  }
}

class _SessionHeader extends GetView<SessionController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final day = controller.activeDay.value;
      controller.salesZones.length;
      controller.selectedSalesZone.value;
      final auth = Get.find<AuthRepository>();
      final userName = auth.cachedSession?.user.name?.trim() ?? '';
      final headerLabel =
          userName.isNotEmpty ? userName.toUpperCase() : 'SESSION ACTIVE';

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
                day.sessionNumber ?? '${day.id}',
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
                    headerLabel,
                    style: TextStyle(
                      fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.8,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  JtrResponsive.getResponsiveSpacing(context, 2),
                  Text(
                    day.displayDate,
                    style: TextStyle(
                      fontSize: JtrResponsive.getResponsiveFontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: controller.salesZones.isEmpty
                  ? null
                  : () => _showSalesZonePicker(context, controller),
              child: Container(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.selectedSalesZoneLabel,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (controller.salesZones.length > 1) ...[
                    SizedBox(width: JtrResponsive.getResponsiveSize(context, 4)),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: JtrResponsive.getResponsiveSize(context, 18),
                      color: AppTheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            ),
            JtrResponsive.getResponsiveHorizontalSpacing(context, 4),
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
    });
  }
}

void _showSalesZonePicker(BuildContext context, SessionController controller) {
  final zones = controller.salesZones.toList();
  if (zones.isEmpty) return;
  final selectedId = controller.selectedSalesZone.value?.id;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.background,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(JtrResponsive.getResponsiveRadius(context, 20)),
      ),
    ),
    builder: (ctx) {
      final maxHeight = MediaQuery.of(ctx).size.height * 0.72;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(
                    top: JtrResponsive.getResponsiveSize(ctx, 10),
                  ),
                  width: JtrResponsive.getResponsiveSize(ctx, 40),
                  height: JtrResponsive.getResponsiveSize(ctx, 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: JtrResponsive.getResponsivePadding(
                  ctx,
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zone de vente',
                      style: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(ctx, 18),
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkText,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: JtrResponsive.getResponsiveSize(ctx, 4)),
                    Text(
                      'Choisissez le centre de profit actif',
                      style: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(ctx, 12),
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: JtrResponsive.getResponsivePadding(
                    ctx,
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemCount: zones.length,
                  separatorBuilder: (_, __) => SizedBox(
                    height: JtrResponsive.getResponsiveSize(ctx, 10),
                  ),
                  itemBuilder: (_, index) {
                    final zone = zones[index];
                    final selected = zone.id == selectedId;
                    return _SalesZonePickerTile(
                      zone: zone,
                      selected: selected,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        unawaited(controller.selectSalesZone(zone));
                      },
                    );
                  },
                ),
              ),
              JtrResponsive.getResponsiveSpacing(ctx, 12),
            ],
          ),
        ),
      );
    },
  );
}

class _SalesZonePickerTile extends StatelessWidget {
  const _SalesZonePickerTile({
    required this.zone,
    required this.selected,
    required this.onTap,
  });

  final SalesZoneInfo zone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = JtrResponsive.getResponsiveRadius(context, 14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: JtrResponsive.getResponsivePadding(
            context,
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected ? AppTheme.lightButton : AppTheme.inactiveSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.cardBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.displayLabel,
                      style: TextStyle(
                        fontSize:
                            JtrResponsive.getResponsiveFontSize(context, 14),
                        fontWeight: FontWeight.w700,
                        color: AppTheme.darkText,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: JtrResponsive.getResponsiveSize(context, 6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: JtrResponsive.getResponsiveSize(context, 8),
                        vertical: JtrResponsive.getResponsiveSize(context, 3),
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : AppTheme.background,
                        borderRadius: BorderRadius.circular(
                          JtrResponsive.getResponsiveRadius(context, 20),
                        ),
                      ),
                      child: Text(
                        zone.usesTableFlow ? 'Avec tables' : 'Sans table',
                        style: TextStyle(
                          fontSize: JtrResponsive.getResponsiveFontSize(
                            context,
                            11,
                          ),
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: selected ? 1 : 0.35,
                child: Container(
                  width: JtrResponsive.getResponsiveSize(context, 26),
                  height: JtrResponsive.getResponsiveSize(context, 26),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: JtrResponsive.getResponsiveSize(context, 16),
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTableLayout {
  _SessionTableLayout._();

  static const List<int> columnFlexes = [2, 1, 2, 3, 1, 2, 4];
  static const List<Alignment> columnAlignments = [
    Alignment.center,
    Alignment.center,
    Alignment.center,
    Alignment.center,
    Alignment.center,
    Alignment.center,
    Alignment.centerRight,
  ];

  static EdgeInsets outerPadding(BuildContext context) =>
      JtrResponsive.getResponsivePadding(context, horizontal: 8);

  static EdgeInsets innerPadding(BuildContext context) =>
      JtrResponsive.getResponsivePadding(context, horizontal: 8, vertical: 12);

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
            for (var i = 0; i < cells.length; i++)
              Expanded(
                flex: _SessionTableLayout.columnFlexes[i],
                child: Align(
                  alignment: _SessionTableLayout.columnAlignments[i],
                  child: cells[i],
                ),
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
          Text('TOTAL', textAlign: TextAlign.right, style: _SessionTableLayout.headerStyle(context)),
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
      // Re-read from the live session list so ticket / total / couverts updates
      // show immediately (constructor [order] can be a stale snapshot).
      controller.orders.length;
      final order =
          controller.findOrder(orderNumber: this.order.number) ?? this.order;
      final state = controller.tableUiState.value;
      final isExpanded = state.expandedOrderNumber == order.number;
      final selectedNumber = state.selectedRow?.orderNumber;
      final isRowSelected = selectedNumber != null &&
          state.selectedRow?.productIndex == null &&
          SessionController.normalizeTableKey(selectedNumber) ==
              SessionController.normalizeTableKey(order.number);
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
                onPressed: (_) =>
                    controller.requestDeleteOrder(order.number, context: context),
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
                onPressed: controller.canAccessOffert
                    ? (_) => controller.requestApplyOffer(
                          order.number,
                          context: context,
                        )
                    : null,
                backgroundColor: AppTheme.background,
                foregroundColor: controller.canAccessOffert
                    ? AppTheme.primary
                    : AppTheme.darkText.withValues(alpha: 0.28),
                icon: Icons.local_offer_outlined,
                spacing: 0,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          child: GestureDetector(
            onDoubleTap: () => controller.openTableDetailsEnsuringLines(
                      order.number,
                      orderId: order.id > 0 ? order.id : null,
                      deferDetailFetch: order.isLocalOnly,
                      seedOrder: order,
                    ),
            child: Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: AppTheme.cardBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
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
                        flex: _SessionTableLayout.columnFlexes[0],
                        expandOnTap: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              order.displayNumber,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: JtrResponsive.getResponsiveFontSize(
                                  context,
                                  13,
                                ),
                                fontWeight: FontWeight.bold,
                                color: order.numberColor,
                              ),
                            ),
                            if (order.isPartiallyPaid) ...[
                              const SizedBox(height: 2),
                              Text(
                                'PARTIEL',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize:
                                      JtrResponsive.getResponsiveFontSize(
                                    context,
                                    8,
                                  ),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: const Color(0xFFE67E22),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        flex: _SessionTableLayout.columnFlexes[1],
                        child: Text(
                          order.group,
                          textAlign: TextAlign.center,
                          style: _SessionTableLayout.cellStyle(context),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        flex: _SessionTableLayout.columnFlexes[2],
                        child: Text(
                          order.poste,
                          textAlign: TextAlign.center,
                          style: _SessionTableLayout.cellStyle(context),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        flex: _SessionTableLayout.columnFlexes[3],
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
                        flex: _SessionTableLayout.columnFlexes[4],
                        child: Text(
                          order.couverts,
                          textAlign: TextAlign.center,
                          style: _SessionTableLayout.cellStyle(context),
                        ),
                      ),
                      _OrderTableCell(
                        orderNumber: order.number,
                        flex: _SessionTableLayout.columnFlexes[5],
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
                        flex: _SessionTableLayout.columnFlexes[6],
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            order.total,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: JtrResponsive.getResponsiveFontSize(context, 12),
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                Divider(height: 1, color: AppTheme.cardBorder),
                if (controller.isLoadingOrderDetail(order.number) ||
                    (order.displayEntries.isEmpty &&
                        (order.products.isNotEmpty || order.itemCount > 0)))
                  Padding(
                    padding: JtrResponsive.getResponsivePadding(
                      context,
                      vertical: 16,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: JtrResponsive.getResponsiveSize(context, 20),
                        height: JtrResponsive.getResponsiveSize(context, 20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  )
                else if (order.displayEntries.isEmpty &&
                    order.products.isEmpty)
                  Padding(
                    padding: JtrResponsive.getResponsivePadding(
                      context,
                      vertical: 12,
                    ),
                    child: Text(
                      'Aucun produit',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: JtrResponsive.getResponsiveFontSize(context, 10),
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  )
                else
                  ..._buildExpandedDetailRows(context, order),
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

List<Widget> _buildExpandedDetailRows(BuildContext context, SessionOrder order) {
  final rows = <Widget>[];
  final entries = OrderMapper.withoutEmptyDemandeSeparators(
    order.displayEntries,
  );

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];

    if (entry.type == OrderDisplayEntryType.product && entry.product != null) {
      rows.add(
        _ProductRow(
          orderNumber: order.number,
          productIndex: entry.lineIndex ?? 0,
          product: entry.product!,
        ),
      );
    } else {
      rows.add(_SessionCourseDivider(entry: entry));
    }

    if (i < entries.length - 1) {
      rows.add(Divider(height: 1, color: AppTheme.subtleDivider));
    }
  }

  return rows;
}

class _OrderTableCell extends GetView<SessionController> {
  const _OrderTableCell({
    required this.orderNumber,
    required this.child,
    this.flex = 1,
    this.alignment = Alignment.center,
    this.expandOnTap = false,
  });

  final String orderNumber;
  final Widget child;
  final int flex;
  final Alignment alignment;
  final bool expandOnTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => controller.selectRow(
          orderNumber: orderNumber,
          expandOnNumberTap: expandOnTap,
        ),
        behavior: HitTestBehavior.opaque,
        child: Align(alignment: alignment, child: child),
      ),
    );
  }
}

class _SessionCourseDivider extends StatelessWidget {
  const _SessionCourseDivider({required this.entry});

  final OrderDisplayEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDemande = entry.type == OrderDisplayEntryType.demandeSeparator;
    final accent = isDemande ? const Color(0xFF27AE60) : AppTheme.primary;
    final label = isDemande
        ? 'DEMANDÉE ${entry.demandeTimeLabel ?? ''}'.trim()
        : 'À SUIVRE';

    return Padding(
      padding: JtrResponsive.getResponsivePadding(
        context,
        horizontal: 12,
        vertical: 6,
      ),
      child: Container(
        padding: JtrResponsive.getResponsivePadding(
          context,
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(
            JtrResponsive.getResponsiveRadius(context, 10),
          ),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDemande ? Icons.done_all_rounded : Icons.restaurant_menu,
              size: JtrResponsive.getResponsiveSize(context, 14),
              color: accent,
            ),
            JtrResponsive.getResponsiveHorizontalSpacing(context, 6),
            Text(
              label,
              style: TextStyle(
                fontSize: JtrResponsive.getResponsiveFontSize(context, 11),
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 0.35,
              ),
            ),
          ],
        ),
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

  bool _isActionEnabled(SessionAction action) {
    switch (action) {
      case SessionAction.ticket:
        return controller.canPrintTicket;
      case SessionAction.statistics:
        return controller.canAccessStatistics;
      case SessionAction.nouvelleCommande:
      case SessionAction.demanderSuite:
        return true;
    }
  }

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
        () {
          // Touch selection so Obx rebuilds with action highlight.
          controller.selectedAction.value;

          return Row(
            children: [
              for (var i = 0; i < _actions.length; i++) ...[
                if (i > 0)
                  JtrResponsive.getResponsiveHorizontalSpacing(context, 8),
                Expanded(
                  child: _ActionButton(
                    label: _actions[i].label,
                    icon: _actions[i].icon,
                    iconSize: _actions[i].iconSize,
                    isActive: controller.selectedAction.value ==
                            _actions[i].action &&
                        _isActionEnabled(_actions[i].action),
                    isEnabled: _isActionEnabled(_actions[i].action),
                    onTap: () {
                      final action = _actions[i].action;
                      if (!_isActionEnabled(action)) return;
                      if (action == SessionAction.ticket) {
                        controller.printTicket(context: context);
                      } else if (action == SessionAction.nouvelleCommande) {
                        controller.showTableNumberDialog(context: context);
                      } else if (action == SessionAction.demanderSuite) {
                        controller.requestNextCourse(context: context);
                      } else if (action == SessionAction.statistics) {
                        controller.openStatistics();
                      } else {
                        controller.selectAction(action);
                      }
                    },
                  ),
                ),
              ],
            ],
          );
        },
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
    this.isEnabled = true,
  });

  final String label;
  final IconData icon;
  final double iconSize;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = !isEnabled
        ? AppTheme.inactiveSurface.withValues(alpha: 0.55)
        : isActive
            ? AppTheme.primary
            : AppTheme.inactiveSurface;
    final labelColor = !isEnabled
        ? AppTheme.darkText.withValues(alpha: 0.35)
        : isActive
            ? Colors.white
            : AppTheme.darkText;
    final iconColor = !isEnabled
        ? AppTheme.darkText.withValues(alpha: 0.35)
        : isActive
            ? Colors.white
            : AppTheme.toolbarIconColor(icon);
    final responsiveIconSize =
        JtrResponsive.getResponsiveSize(context, iconSize);

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
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
          boxShadow: !isEnabled
              ? null
              : isActive
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
            if (isActive && isEnabled)
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
