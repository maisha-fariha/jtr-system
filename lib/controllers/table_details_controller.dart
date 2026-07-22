import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/network/api_exception.dart';
import '../data/mappers/order_mapper.dart';
import '../data/models/local_draft_line.dart';
import '../data/models/catalog/catalog_product_model.dart';
import '../data/models/catalog/category_tree_node.dart';
import '../data/order_optimistic_sync.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/order_repository.dart';
import '../data/mappers/menu_mapper.dart';
import '../models/order_product.dart';
import '../models/order_display_entry.dart';
import '../models/session_order.dart';
import '../models/menu_active_selection.dart';
import '../models/menu_selection_submit_result.dart';
import '../routes/app_pages.dart';
import '../utils/api_log.dart';
import '../utils/app_snackbar.dart';
import '../widgets/api_debug_dialog.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/menu_message_typing_dialog.dart';
import '../widgets/table_number_dialog.dart';
import '../widgets/ticket_loading_dialog.dart';
import '../widgets/ticket_success_dialog.dart';
import 'session_controller.dart';

class TableDetailsController extends GetxController {
  TableDetailsController({
    required CatalogRepository catalogRepository,
    required OrderRepository orderRepository,
  })  : _catalogRepository = catalogRepository,
        _orderRepository = orderRepository;

  final CatalogRepository _catalogRepository;
  final OrderRepository _orderRepository;

  OrderOptimisticSync get _optimisticSync =>
      _orderRepository.optimisticSyncFor(_optimisticSyncKey);

  final selectedCategoryIndex = 0.obs;
  final isBottomPanelExpanded = true.obs;
  final showPaymentOptions = false.obs;
  final selectedProductId = RxnInt();
  final selectedOrderLineIndex = RxnInt();
  final activeToolbarIcon = Rx<IconData?>(Icons.grid_view);
  final isCatalogLoading = false.obs;
  final isAddingProduct = false.obs;
  /// `true` = cash payment in progress, `false` = card, `null` = idle.
  final payingIsCash = Rxn<bool>();
  final paymentModesLoading = false.obs;
  final paymentModesReady = false.obs;
  final paymentModesError = RxnString();
  String? lastPaymentModesLoadLog;
  final catalogError = RxnString();
  final categoryRoots = <CategoryTreeNode>[].obs;
  final categoryPath = <CategoryTreeNode>[].obs;
  final products = <CatalogProductModel>[].obs;

  late final String orderNumber;
  int? orderId;

  /// When true (fresh empty create), skip blocking GET detail on open.
  bool _deferDetailFetch = false;

  /// Lines queued locally until Send All POSTs /api/orders (no seed product).
  final List<LocalDraftLine> _localDraftLines = [];

  bool get _isLocalDraft {
    if (orderId != null && orderId! > 0) return false;
    final current = _rawSessionOrder ?? seedOrder;
    if (current != null && current.id > 0) return false;
    if (_deferDetailFetch || _localDraftLines.isNotEmpty) return true;
    // Placeholder row (id <= 0) reopened from session after refresh.
    if (current != null && current.isLocalOnly) return true;
    return false;
  }

  /// Snapshot from navigation — avoids empty flashes and keeps latest total.
  SessionOrder? seedOrder;

  final collapsedSuivreSections = <int>{}.obs;
  final expandedMenuLineIndices = <int>{}.obs;
  final selectedSuivreSection = RxnInt();
  final suivreUiRevision = 0.obs;
  final orderUiRevision = 0.obs;

  /// Rapid simple-product taps are UI-immediate; network uses one coalesced
  /// `PUT` with every line queued since the last flush (not one PUT per tap).
  final List<CatalogProductModel> _queuedSimpleAdds = [];
  Timer? _simpleAddBatchTimer;
  SessionOrder? _simpleAddBatchRollback;
  bool _simpleAddSyncEnqueued = false;
  /// Coalesce rapid taps into **one** PUT. Do not shorten this — flushing on
  /// every tap while a sync is pending causes N API calls and ANRs.
  static const _simpleAddBatchWindow = Duration(milliseconds: 400);
  DateTime? _lastOrderUiRevisionAt;
  static const _orderUiRevisionMinInterval = Duration(milliseconds: 50);

  /// Bumped on every line delete so an in-flight add sync can detect that the
  /// waiter already cleared/changed the ticket and must not PUT/apply adds.
  int _ticketMutationEpoch = 0;

  Set<int> get _suppressDeletedItemIds {
    final orderKey = orderId ?? _rawSessionOrder?.id ?? 0;
    if (orderKey <= 0) return const {};
    return _orderRepository.suppressedItemIdsFor(orderKey);
  }

  void _suppressDeletedLine(int? itemId, {required int orderId}) {
    if (orderId <= 0) return;
    _orderRepository.markPendingLocalDelete(orderId);
    _orderRepository.bumpDetailRevision(orderId);
    if (itemId != null && itemId > 0) {
      _orderRepository.suppressOrderItemIds(orderId, [itemId]);
    }
  }

  void _releaseDeletedLinesConfirmedBy(SessionOrder server) {
    if (server.id <= 0) return;
    final stillOnServer = OrderMapper.productItemIds(server.displayEntries);
    for (final id in _orderRepository.suppressedItemIdsFor(server.id)) {
      if (!stillOnServer.contains(id)) {
        _orderRepository.clearSuppressedOrderItemIds(server.id, itemId: id);
      }
    }
    if (_orderRepository.suppressedItemIdsFor(server.id).isEmpty) {
      _orderRepository.clearSuppressedOrderItemIds(server.id);
    }
  }

  void _invalidateBackgroundApplies() {
    _optimisticSync.invalidateApplies(_optimisticSyncKey);
  }

  /// Delete/cancel sync must never rebuild the visible ticket — only adopt ids
  /// and release suppress flags confirmed by the server.
  void _applyDeleteSyncSilently(SessionOrder updated) {
    if (updated.id > 0) {
      final previousId = orderId ?? _rawSessionOrder?.id ?? 0;
      orderId = updated.id;
      if (previousId > 0 && previousId != updated.id) {
        _orderRepository.clearSuppressedOrderItemIds(previousId);
        _orderRepository.clearPendingLocalDeleteFlag(previousId);
        _orderRepository.clearEmptyShellDisplay(previousId);
      }
    }

    _releaseDeletedLinesConfirmedBy(updated);

    final orderKey = updated.id > 0 ? updated.id : (orderId ?? 0);
    if (orderKey <= 0) return;

    _orderRepository.clearPendingLocalDeleteFlag(orderKey);
    final live = _rawSessionOrder;
    if (live != null && live.products.isNotEmpty) {
      _orderRepository.clearEmptyShellDisplay(orderKey);
      return;
    }
    if (live == null || live.products.isEmpty) {
      _orderRepository.rememberEmptyShellDisplay(orderKey);
    }
  }

  bool _shouldPreferLiveTicket(
    SessionOrder live,
    SessionOrder updated,
    Set<int> suppress,
  ) {
    final liveCount = OrderMapper.productEntryCount(live.displayEntries);
    final updatedCount =
        OrderMapper.productEntryCount(updated.displayEntries);

    if (OrderMapper.hasOptimisticProductEntries(live.displayEntries)) {
      return true;
    }
    if (liveCount > updatedCount) return true;
    if (suppress.isNotEmpty && liveCount <= updatedCount) return true;
    if (OrderMapper.suivreSeparatorCount(live.displayEntries) >
        OrderMapper.suivreSeparatorCount(updated.displayEntries)) {
      return true;
    }
    // Open À SUIVRE with lines under it — API often still parks them on
    // course 1; never let sync flatten them above the divider.
    if (OrderMapper.layoutHasProductsUnderPendingSuivre(live.displayEntries)) {
      return true;
    }
    return false;
  }

  bool _liveItemIdsDiffer(SessionOrder before, SessionOrder after) {
    List<int> orderedIds(List<OrderDisplayEntry> entries) => [
          for (final entry in entries)
            if (entry.type == OrderDisplayEntryType.product)
              entry.itemId ?? 0,
        ];
    final beforeIds = orderedIds(before.displayEntries);
    final afterIds = orderedIds(after.displayEntries);
    if (beforeIds.length != afterIds.length) return true;
    for (var i = 0; i < beforeIds.length; i++) {
      if (beforeIds[i] != afterIds[i]) return true;
    }
    return false;
  }

  /// Apply a background sync result without flashing stale server data.
  ///
  /// Local ticket wins while deletes/adds race. Suppressed item ids are always
  /// stripped from whatever the API returns before it touches the UI.
  void _applySyncedOrder(SessionOrder updated) {
    // Always adopt a real server id from sync — delete-all may recreate the
    // order and a stale live.id must not win (causes ORDER ID not found).
    if (updated.id > 0) {
      final previousId = orderId ?? _rawSessionOrder?.id ?? 0;
      orderId = updated.id;
      _deferDetailFetch = false;
      if (previousId > 0 && previousId != updated.id) {
        _orderRepository.clearSuppressedOrderItemIds(previousId);
        _orderRepository.clearPendingLocalDeleteFlag(previousId);
        _orderRepository.clearEmptyShellDisplay(previousId);
      }
    }

    final live = _rawSessionOrder;
    final suppress = _suppressDeletedItemIds;
    final orderKey = updated.id > 0 ? updated.id : (live?.id ?? 0);
    final pendingDelete = orderKey > 0 &&
        _orderRepository.hasPendingLocalDelete(orderKey);
    final liveCount = live == null
        ? 0
        : OrderMapper.productEntryCount(live.displayEntries);
    final updatedCount =
        OrderMapper.productEntryCount(updated.displayEntries);
    final adoptingNewServerLines = suppress.isEmpty &&
        !pendingDelete &&
        live != null &&
        updatedCount > liveCount &&
        (OrderMapper.sectionDividerCount(live.displayEntries) > 0 ||
            OrderMapper.hasOptimisticProductEntries(live.displayEntries) ||
            OrderMapper.layoutHasTrailingPendingSuivre(live.displayEntries) ||
            OrderMapper.layoutHasProductsUnderPendingSuivre(
              live.displayEntries,
            ));

    // Waiter's current ticket wins — patch server ids only, never relayout.
    if (live != null && _shouldPreferLiveTicket(live, updated, suppress)) {
      _releaseDeletedLinesConfirmedBy(updated);
      if (orderKey > 0) {
        _orderRepository.clearPendingLocalDeleteFlag(orderKey);
        if (live.products.isNotEmpty) {
          _orderRepository.clearEmptyShellDisplay(orderKey);
        }
      }

      final patched = OrderMapper.mergeLiveWithPendingSuivreAdds(
        server: updated,
        live: live,
        selectedSuivreSectionIndex: selectedSuivreSection.value,
        preferAdoptingNewServerLines: adoptingNewServerLines,
      );
      if (_liveItemIdsDiffer(live, patched) ||
          OrderMapper.suivreSeparatorCount(live.displayEntries) !=
              OrderMapper.suivreSeparatorCount(patched.displayEntries)) {
        _syncOrderInSession(
          patched,
          orderNumber,
          displayEntriesOverride: patched.displayEntries,
        );
      }
      return;
    }

    // No-op when the visible ticket already matches — avoid GetX rebuild storms.
    if (live != null &&
        live.id == updated.id &&
        liveCount == updatedCount &&
        suppress.isEmpty &&
        !pendingDelete &&
        OrderMapper.suivreSeparatorCount(live.displayEntries) ==
            OrderMapper.suivreSeparatorCount(updated.displayEntries) &&
        OrderMapper.demandeSeparatorCount(live.displayEntries) ==
            OrderMapper.demandeSeparatorCount(updated.displayEntries) &&
        live.total == updated.total &&
        !_liveItemIdsDiffer(live, updated)) {
      _releaseDeletedLinesConfirmedBy(updated);
      return;
    }

    // Live ticket already empty after delete — never refill from a stale GET
    // while delete suppress ids are still active.
    final emptyShell = orderKey > 0 &&
        _orderRepository.shouldDisplayAsEmptyCreateShell(orderKey);
    if (liveCount == 0 &&
        (suppress.isNotEmpty || pendingDelete) &&
        updatedCount > 0) {
      return;
    }
    if (liveCount == 0 && emptyShell && updatedCount > 0) {
      _orderRepository.clearEmptyShellDisplay(orderKey);
    }
    if (liveCount == 0 && (suppress.isNotEmpty || pendingDelete)) {
      if (updatedCount == 0) {
        _releaseDeletedLinesConfirmedBy(updated);
        _orderRepository.clearSuppressedOrderItemIds(orderKey);
        _orderRepository.clearPendingLocalDeleteFlag(orderKey);
        final empty = updated.copyWith(
          products: const [],
          displayEntries: const [],
          itemCount: 0,
          total: OrderMapper.formatPrice('0'),
        );
        _syncOrderInSession(
          empty,
          orderNumber,
          displayEntriesOverride: empty.displayEntries,
        );
      }
      return;
    }

    // Prefer live when it already has newer adds and the sync payload is empty.
    SessionOrder base;
    if (updatedCount == 0 && liveCount > 0) {
      base = live!;
    } else {
      base = OrderMapper.mergeLiveWithPendingSuivreAdds(
        server: updated,
        live: live ?? updated,
        selectedSuivreSectionIndex: selectedSuivreSection.value,
        preferAdoptingNewServerLines: adoptingNewServerLines,
      );
      if (suppress.isNotEmpty) {
        base = OrderMapper.mergeLiveOptimisticDetail(
          server: base,
          live: live ?? base,
          suppressItemIds: suppress,
        );
      }
    }
    // Hard guarantee: deleted ids never re-enter the ticket from any response.
    var toShow = base;

    if (toShow.products.isEmpty && toShow.id > 0) {
      _orderRepository.rememberEmptyShellDisplay(toShow.id);
    } else if (toShow.id > 0) {
      _orderRepository.clearEmptyShellDisplay(toShow.id);
    }

    _releaseDeletedLinesConfirmedBy(updated);

    // Skip rebuild when layout already matches live (prevents jump).
    if (live != null &&
        OrderMapper.productEntryCount(live.displayEntries) ==
            OrderMapper.productEntryCount(toShow.displayEntries) &&
        OrderMapper.suivreSeparatorCount(live.displayEntries) ==
            OrderMapper.suivreSeparatorCount(toShow.displayEntries) &&
        OrderMapper.demandeSeparatorCount(live.displayEntries) ==
            OrderMapper.demandeSeparatorCount(toShow.displayEntries) &&
        !_liveItemIdsDiffer(live, toShow)) {
      return;
    }

    _syncOrderInSession(
      toShow,
      orderNumber,
      displayEntriesOverride: toShow.displayEntries,
    );
  }

  /// Session row without empty-shell masking (sync/merge must see real lines).
  SessionOrder? get _rawSessionOrder {
    if (Get.isRegistered<SessionController>()) {
      final raw = Get.find<SessionController>().findOrder(
        orderNumber: orderNumber,
        orderId: orderId,
      );
      if (raw != null) return raw;
    }
    return seedOrder;
  }

  /// Lift empty-shell lock before an optimistic add.
  ///
  /// Do **not** clear suppressed delete ids here — a quick add must not let a
  /// racing GET/PUT resurrect a line the waiter just removed.
  void _prepareForNewAdd() {
    final id = orderId ?? _rawSessionOrder?.id ?? seedOrder?.id;
    if (id == null || id <= 0) return;
    _orderRepository.clearEmptyShellDisplay(id);
    _orderRepository.clearPendingLocalDeleteFlag(id);
    _orderRepository.bumpDetailRevision(id);
  }

  /// Drop in-flight delete applies when the waiter starts adding after deletes.
  void _invalidateDeleteAppliesIfNeeded() {
    final id = orderId ?? _rawSessionOrder?.id ?? 0;
    if (id > 0 &&
        (_orderRepository.hasPendingLocalDelete(id) ||
            _suppressDeletedItemIds.isNotEmpty)) {
      _invalidateBackgroundApplies();
    }
  }

  /// Keep catalog highlight in sync with the real ticket.
  void _reconcileCatalogSelection({SessionOrder? source}) {
    final current = source ?? _rawSessionOrder;
    if (current == null || current.products.isEmpty) {
      selectedProductId.value = null;
      selectedOrderLineIndex.value = null;
      return;
    }

    final selectedId = selectedProductId.value;
    if (selectedId != null) {
      final stillInOrder = current.products.any((line) {
        final catalog = catalogProductByName(line.name);
        return catalog?.id == selectedId;
      });
      if (!stillInOrder) {
        selectedProductId.value = null;
      }
    }

    final lineIndex = selectedOrderLineIndex.value;
    if (lineIndex != null &&
        (lineIndex < 0 || lineIndex >= current.products.length)) {
      selectedOrderLineIndex.value = null;
    }
  }

  bool isSuivreSectionCollapsed(int sectionIndex) =>
      collapsedSuivreSections.contains(sectionIndex);

  bool isMenuLineExpanded(int lineIndex) =>
      expandedMenuLineIndices.contains(lineIndex);

  void toggleMenuLineExpansion(int lineIndex) {
    if (expandedMenuLineIndices.contains(lineIndex)) {
      expandedMenuLineIndices.remove(lineIndex);
    } else {
      expandedMenuLineIndices.add(lineIndex);
    }
    expandedMenuLineIndices.refresh();
    orderUiRevision.value++;
  }

  /// Tap on a product row: select it, and toggle menu choices expand/collapse.
  void onOrderLineRowTap(int lineIndex, OrderProduct product) {
    selectOrderLine(lineIndex, product);
    if (product.hasMenuItems) {
      toggleMenuLineExpansion(lineIndex);
    }
  }

  Future<void> editOrderLineComment(
    int lineIndex, {
    BuildContext? context,
  }) async {
    if (_blockIfOrderOffered()) return;

    final current = order;
    if (current == null ||
        lineIndex < 0 ||
        lineIndex >= current.products.length) {
      return;
    }

    final product = current.products[lineIndex];
    await MenuMessageTypingDialog.show(
      context: context,
      itemLabel: product.name,
      initialMessage: product.message ?? '',
      onSave: (message) => unawaited(
        _saveOrderLineComment(lineIndex: lineIndex, comment: message),
      ),
    );
  }

  Future<void> _saveOrderLineComment({
    required int lineIndex,
    required String comment,
  }) async {
    final current = order;
    if (current == null ||
        lineIndex < 0 ||
        lineIndex >= current.products.length) {
      return;
    }

    final trimmed = comment.trim();
    final snapshot = OrderOptimisticSync.deepSnapshot(current);
    final updatedProducts = [...current.products];
    updatedProducts[lineIndex] = current.products[lineIndex].copyWith(
      message: trimmed.isEmpty ? null : trimmed,
      clearMessage: trimmed.isEmpty,
    );
    final updatedEntries = [
      for (final entry in current.displayEntries)
        if (entry.type == OrderDisplayEntryType.product &&
            entry.lineIndex == lineIndex &&
            entry.product != null)
          OrderDisplayEntry.product(
            product: entry.product!.copyWith(
              message: trimmed.isEmpty ? null : trimmed,
              clearMessage: trimmed.isEmpty,
            ),
            lineIndex: lineIndex,
            sectionIndex: entry.sectionIndex ?? 0,
            courseNumber: entry.courseNumber,
            itemId: entry.itemId,
          )
        else
          entry,
    ];
    final optimistic = current.copyWith(
      products: updatedProducts,
      displayEntries: updatedEntries,
    );

    _syncOrderInSession(
      optimistic,
      orderNumber,
      displayEntriesOverride: updatedEntries,
    );

    if (_isLocalDraft) return;

    final id = resolvedOrderId ?? await _ensureResolvedOrderId();
    if (id == null || id <= 0) return;

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: (updated) {
        if (updated.id > 0) orderId = updated.id;
        _syncOrderInSession(updated, orderNumber);
      },
      sync: () async {
        final updated = await _orderRepository.updateOrderLineCommentAtIndex(
          orderId: id,
          lineIndex: lineIndex,
          comment: trimmed,
        );
        if (updated.id > 0) orderId = updated.id;
        return updated;
      },
      recover: (snap) async {
        try {
          return await _orderRepository.getOrderDetail(
            id,
            previousDisplayEntries: snap.displayEntries,
          );
        } catch (_) {
          return snap;
        }
      },
      onError: (error) =>
          _showOptimisticMutationError('enregistrer le message', error),
    );
  }

  bool isSuivreSectionSelected(int sectionIndex) =>
      selectedSuivreSection.value == sectionIndex;

  bool isSelectedSectionRequestable(List<OrderDisplayEntry> entries) {
    final sectionIndex = selectedSuivreSection.value;
    if (sectionIndex == null || sectionIndex <= 0) return false;

    for (final entry in entries) {
      if (entry.type == OrderDisplayEntryType.suivreSeparator &&
          entry.sectionIndex == sectionIndex) {
        return true;
      }
      if (entry.type == OrderDisplayEntryType.demandeSeparator &&
          entry.sectionIndex == sectionIndex) {
        return false;
      }
    }

    return false;
  }

  void selectSuivreSection(int sectionIndex) {
    selectedSuivreSection.value = sectionIndex;
    collapsedSuivreSections.remove(sectionIndex);
    collapsedSuivreSections.refresh();
    suivreUiRevision.value++;
  }

  void toggleSuivreSection(int sectionIndex) {
    if (collapsedSuivreSections.contains(sectionIndex)) {
      collapsedSuivreSections.remove(sectionIndex);
    } else {
      collapsedSuivreSections.add(sectionIndex);
    }
    collapsedSuivreSections.refresh();
    suivreUiRevision.value++;
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    orderNumber = (args is Map ? args['orderNumber'] as String? : null) ?? '';
    final rawId = args is Map ? args['orderId'] : null;
    orderId = rawId is int ? rawId : (rawId is num ? rawId.toInt() : null);
    _deferDetailFetch = args is Map && args['deferDetailFetch'] == true;
    final rawSeed = args is Map ? args['seedOrder'] : null;
    if (rawSeed is SessionOrder) {
      seedOrder = rawSeed;
      if ((orderId == null || orderId! <= 0) && rawSeed.id > 0) {
        orderId = rawSeed.id;
      }
      if (orderNumber.isEmpty) {
        orderNumber = rawSeed.number;
      }
      if ((orderId == null || orderId! <= 0) && rawSeed.isLocalOnly) {
        _deferDetailFetch = true;
      }
    }
    logOrderFlow(
      'TableDetailsController.onInit table=$orderNumber '
      'orderId=${orderId ?? 'none'} deferDetailFetch=$_deferDetailFetch '
      'hasSeed=${seedOrder != null}',
    );

    _loadCatalog();
    unawaited(_bootstrapOrder());
  }

  Future<void> _bootstrapOrder() async {
    await _ensureResolvedOrderId();
    final resolved = resolvedOrderId;
    if (resolved != null && resolved > 0) {
      _deferDetailFetch = false;
      await _refreshOrder();
      return;
    }
    if (_deferDetailFetch && _localDraftLines.isEmpty) return;
    if (_isLocalDraft) return;
    await _refreshOrder();
  }

  Future<void> _loadCatalog() async {
    isCatalogLoading.value = true;
    catalogError.value = null;

    try {
      final loadedTree = await _catalogRepository.getCategoryTree();
      final loadedProducts = await _catalogRepository.getProducts();
      categoryRoots.assignAll(loadedTree);
      products.assignAll(loadedProducts);
      categoryPath.clear();
      if (selectedCategoryIndex.value >= currentLevelCategories.length) {
        selectedCategoryIndex.value = 0;
      }
    } on ApiException catch (e) {
      catalogError.value = e.message;
    } catch (_) {
      catalogError.value = 'Impossible de charger le menu.';
    } finally {
      isCatalogLoading.value = false;
    }
  }

  Future<void> _refreshOrder({
    List<OrderDisplayEntry>? layoutBeforeNav,
  }) async {
    // Don't refresh over a debounce window that hasn't POSTed yet.
    if (_queuedSimpleAdds.isNotEmpty) {
      _flushQueuedSimpleAddsNow();
    }
    if (_optimisticSync.hasPending(_optimisticSyncKey)) return;
    // Local delete still syncing — don't pull a fatter stale ticket over it.
    final liveId = orderId ?? _rawSessionOrder?.id;
    if (liveId != null &&
        liveId > 0 &&
        _orderRepository.hasPendingLocalDelete(liveId)) {
      return;
    }
    if (isAddingProduct.value) return;
    if (!Get.isRegistered<SessionController>()) return;

    final current = order;
    // Local-only shell has no remote detail yet.
    if (current != null && current.isLocalOnly) return;

    if (current != null && current.id > 0) {
      orderId = current.id;
    }

    // Session list rows are lightweight (total only, no lines). Always fetch
    // GET /api/orders/:id so table details can show seat_orders items.
    await Get.find<SessionController>().loadOrderDetails(
      orderNumber,
      orderId: orderId,
      forceRefresh: true,
      previousDisplayEntries: layoutBeforeNav ?? order?.displayEntries,
    );
  }

  /// Presentation-only: empty-shell lock after delete-all (not create-seed hiding).
  SessionOrder forDisplay(SessionOrder raw) {
    if (raw.id > 0 &&
        Get.isRegistered<OrderRepository>() &&
        _orderRepository.shouldDisplayAsEmptyCreateShell(raw.id)) {
      final hasLines = raw.products.isNotEmpty || raw.displayEntries.isNotEmpty;
      if (!hasLines) return raw;
      // Optimistic add already wrote lines — do not hide them again.
      _orderRepository.clearEmptyShellDisplay(raw.id);
      return raw;
    }
    return raw;
  }

  SessionOrder? get order {
    SessionOrder? raw;
    if (Get.isRegistered<SessionController>()) {
      raw = Get.find<SessionController>().findOrder(
        orderNumber: orderNumber,
        orderId: orderId,
      );
    }
    raw ??= seedOrder;
    if (raw == null) return null;
    return forDisplay(OrderMapper.ensureSessionDisplayHydrated(raw));
  }

  int? get resolvedOrderId {
    if (orderId != null && orderId! > 0) return orderId;
    final current = order;
    if (current != null && current.id > 0) return current.id;
    return null;
  }

  /// Cached API order id — no network verification (hot path for optimistic UI).
  int? get _fastResolvedOrderId => resolvedOrderId;

  int get _optimisticSyncKey => orderNumber.hashCode;

  int get _parsedTableNumber {
    final normalized = orderNumber.replaceFirst(RegExp(r'^T'), '').trim();
    return int.tryParse(normalized) ?? 0;
  }

  int get _currentWaiterId {
    if (Get.isRegistered<AuthRepository>()) {
      return Get.find<AuthRepository>().cachedSession?.user.id ?? 0;
    }
    return 0;
  }

  Future<int?> _ensureResolvedOrderId() async {
    if (orderId != null && orderId! > 0) {
      if (await _verifyOrderExists(orderId!)) return orderId;
      orderId = null;
    }

    final current = order;
    if (current != null && current.id > 0) {
      if (await _verifyOrderExists(current.id)) {
        orderId = current.id;
        return orderId;
      }
    }

    final resolved =
        await _orderRepository.resolveOrderIdForTableNumber(orderNumber);
    if (resolved == null || resolved <= 0) return null;

    try {
      final previous = order;
      final detail = await _orderRepository.getOrderDetail(
        resolved,
        previousDisplayEntries: previous?.displayEntries,
      );
      orderId = resolved;
      _syncOrderInSession(detail, detail.number);
      return orderId;
    } catch (_) {
      orderId = null;
      return null;
    }
  }

  Future<bool> _verifyOrderExists(int id) async {
    try {
      await _orderRepository.getOrderDetail(
        id,
        previousDisplayEntries: order?.displayEntries,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  List<CategoryTreeNode> get currentLevelCategories {
    if (categoryPath.isEmpty) return categoryRoots;
    return categoryPath.last.children;
  }

  CategoryTreeNode? get selectedCategory {
    final level = currentLevelCategories;
    if (level.isEmpty) return null;
    final index = selectedCategoryIndex.value;
    if (index < 0 || index >= level.length) return level.first;
    return level[index];
  }

  bool get canNavigateCategoryBack {
    if (categoryPath.isNotEmpty) return true;
    final selected = selectedCategory;
    if (selected == null) return false;
    return _findAncestorChain(selected.id).isNotEmpty;
  }

  List<CategoryTreeNode> _findAncestorChain(int categoryId) {
    List<CategoryTreeNode>? search(
      List<CategoryTreeNode> nodes,
      List<CategoryTreeNode> ancestors,
    ) {
      for (final node in nodes) {
        if (node.id == categoryId) return ancestors;
        if (node.children.isEmpty) continue;
        final found = search(node.children, [...ancestors, node]);
        if (found != null) return found;
      }
      return null;
    }

    return search(categoryRoots.toList(), const []) ?? const [];
  }

  void _applyCategoryLevel({
    required List<CategoryTreeNode> path,
    required CategoryTreeNode selected,
  }) {
    categoryPath.assignAll(path);
    final siblings = path.isEmpty ? categoryRoots : path.last.children;
    final index = siblings.indexWhere((node) => node.id == selected.id);
    selectedCategoryIndex.value = index >= 0 ? index : 0;
  }

  bool get showingChildCategories {
    final category = selectedCategory;
    return category != null && category.hasChildren;
  }

  List<CategoryTreeNode> get childCategoriesForGrid {
    final category = selectedCategory;
    if (category == null || !category.hasChildren) return const [];
    return category.children;
  }

  List<CatalogProductModel> get currentProducts {
    final category = selectedCategory;
    if (category == null || category.hasChildren) return const [];
    return _catalogRepository.productsForCategory(products, category.id);
  }

  CatalogProductModel? catalogProductByName(String orderLineName) {
    final normalized = orderLineName.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    for (final product in products) {
      if (product.name.trim().toUpperCase() == normalized) return product;
    }
    return null;
  }

  CatalogProductModel? get selectedCatalogProduct {
    final id = selectedProductId.value;
    if (id == null) return null;
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  int productQuantityInOrder(
    CatalogProductModel product, {
    SessionOrder? source,
  }) {
    final currentOrder = source ?? order;
    if (currentOrder == null) return 0;
    final normalized = product.name.toUpperCase();
    var total = 0;
    for (final line in currentOrder.products) {
      if (line.name.toUpperCase() == normalized) {
        total += int.tryParse(line.quantity) ?? 0;
      }
    }
    return total;
  }

  bool isProductSelected(CatalogProductModel product) =>
      selectedProductId.value == product.id;

  bool isOrderLineSelected(int lineIndex) =>
      selectedOrderLineIndex.value == lineIndex;

  void selectOrderLine(int lineIndex, OrderProduct line) {
    final catalog = catalogProductByName(line.name);
    if (catalog == null) {
      AppSnackbar.show(
        'Article non sélectionnable',
        'Cet article ne peut pas être modifié via le clavier.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    selectedProductId.value = catalog.id;
    selectedOrderLineIndex.value = lineIndex;
  }

  void selectCatalogProduct(CatalogProductModel product) {
    selectedProductId.value = product.id;
    selectedOrderLineIndex.value = null;
  }

  void selectCategory(int index) {
    if (index < 0 || index >= currentLevelCategories.length) return;
    selectedCategoryIndex.value = index;
  }

  void openChildCategory(CategoryTreeNode child) {
    final parent = selectedCategory;
    if (parent == null) return;

    _applyCategoryLevel(
      path: [...categoryPath, parent],
      selected: child,
    );
  }

  void navigateCategoryBack() {
    if (categoryPath.isNotEmpty) {
      final parent = categoryPath.removeLast();
      _applyCategoryLevel(path: categoryPath.toList(), selected: parent);
      return;
    }

    final selected = selectedCategory;
    if (selected == null) return;

    final ancestors = _findAncestorChain(selected.id);
    if (ancestors.isEmpty) return;

    final parent = ancestors.last;
    _applyCategoryLevel(
      path: ancestors.sublist(0, ancestors.length - 1),
      selected: parent,
    );
  }

  /// Category hierarchy first; only leaves the table when already at root.
  Future<void> openMenuSelection() async {
    if (_blockIfOrderOffered()) return;

    showPaymentOptions.value = false;
    final layoutBeforeNav = order?.displayEntries == null
        ? null
        : List<OrderDisplayEntry>.from(order!.displayEntries);
    final suivreSectionBeforeNav = selectedSuivreSection.value;
    final id = await _ensureResolvedOrderId();

    final menuResult = await Get.toNamed(
      AppRoutes.menuSelection,
      arguments: {
        'orderNumber': orderNumber,
        if (id != null && id > 0) 'orderId': id,
      },
    );

    if (menuResult is MenuSelectionSubmitResult) {
      _applyMenuSelectionFromToolbar(
        menuResult,
        suivreSectionIndex: suivreSectionBeforeNav,
      );
      orderUiRevision.value++;
      return;
    }

    _restoreDisplayLayoutIfNeeded(layoutBeforeNav);
    orderUiRevision.value++;
  }

  void _applyMenuSelectionFromToolbar(
    MenuSelectionSubmitResult submit, {
    int? suivreSectionIndex,
  }) {
    _prepareForNewAdd();
    _invalidateDeleteAppliesIfNeeded();

    final product = CatalogProductModel(
      id: submit.productId,
      name: submit.productName,
      price: submit.basePrice.toStringAsFixed(2),
      categoryId: 0,
      categoryName: '',
      isComposed: true,
      isActive: true,
    );

    final layoutHints = _rawSessionOrder?.displayEntries ?? order?.displayEntries;
    final rollbackSnapshot = _rawSessionOrder != null
        ? OrderOptimisticSync.deepSnapshot(_rawSessionOrder!)
        : (order != null ? OrderOptimisticSync.deepSnapshot(order!) : null);
    final effectiveSuivreSection =
        suivreSectionIndex ?? selectedSuivreSection.value;

    _applyAddComposedProductToUi(
      product: product,
      menuSelections: submit.menuSelections,
      layoutHints: layoutHints,
      comment: submit.comment,
      selectedSuivreSectionIndex: effectiveSuivreSection,
    );

    unawaited(
      _syncAddComposedProductInBackground(
        product: product,
        menuSelections: submit.menuSelections,
        rollbackSnapshot: rollbackSnapshot,
        layoutHints: layoutHints,
        comment: submit.comment,
        selectedSuivreSectionIndex: effectiveSuivreSection,
      ),
    );
  }

  void _restoreDisplayLayoutIfNeeded(List<OrderDisplayEntry>? layout) {
    if (layout == null || layout.isEmpty) return;

    final current = order;
    if (current == null) return;

    final currentSuivreCount =
        OrderMapper.suivreSeparatorCount(current.displayEntries);
    final savedSuivreCount = OrderMapper.suivreSeparatorCount(layout);
    if (savedSuivreCount <= currentSuivreCount) return;

    _syncOrderInSession(
      current.copyWith(displayEntries: layout),
      orderNumber,
      displayEntriesOverride: layout,
    );
  }

  Future<void> navigateBackOrExitTable() async {
    if (canNavigateCategoryBack) {
      navigateCategoryBack();
      activeToolbarIcon.value = Icons.grid_view;
      return;
    }

    final currentOrder = order;
    if (Get.isRegistered<SessionController>() && currentOrder != null) {
      // Sync this table's row only — do not force-refresh the whole session
      // list (that re-sorts and moves rows when returning from details).
      Get.find<SessionController>().updateOrderRow(
        currentOrder,
        replaceDetail: true,
      );
    }
    Get.back();
  }

  /// After a successful kitchen send / payment, return to the session list.
  void _returnToSessionPage({
    bool skipOrderSnapshot = false,
    bool scrollListToTop = false,
  }) {
    if (!skipOrderSnapshot) {
      final currentOrder = order;
      if (Get.isRegistered<SessionController>() && currentOrder != null) {
        Get.find<SessionController>().updateOrderRow(
          currentOrder,
          replaceDetail: true,
        );
      }
    }
    if (scrollListToTop && Get.isRegistered<SessionController>()) {
      Get.find<SessionController>().listScrollSignal.value++;
    }

    // Prefer popping back to the existing session route. Avoid lone Get.back()
    // after a snackbar — that only dismisses the snackbar.
    if (Get.currentRoute == AppRoutes.session) return;

    Get.until(
      (route) =>
          route.settings.name == AppRoutes.session || route.isFirst,
    );
    if (Get.currentRoute != AppRoutes.session) {
      Get.offNamed(AppRoutes.session);
    }
  }

  void toggleBottomPanel() {
    isBottomPanelExpanded.value = !isBottomPanelExpanded.value;
    if (isBottomPanelExpanded.value) {
      showPaymentOptions.value = false;
      activeToolbarIcon.value = Icons.grid_view;
    } else if (!showPaymentOptions.value) {
      activeToolbarIcon.value = null;
    }
  }

  void togglePaymentOptions() {
    final show = !showPaymentOptions.value;
    showPaymentOptions.value = show;
    if (show) {
      isBottomPanelExpanded.value = false;
      activeToolbarIcon.value = Icons.payments_outlined;
      unawaited(_loadPaymentModes());
    } else {
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = Icons.grid_view;
    }
  }

  Future<void> _loadPaymentModes({bool forceRefresh = false}) async {
    paymentModesLoading.value = true;
    paymentModesError.value = null;
    try {
      final modes = await _orderRepository.getPaymentModes(
        forceRefresh: forceRefresh,
      );
      paymentModesReady.value = modes.isNotEmpty;
      if (modes.isEmpty) {
        paymentModesError.value = 'Aucun mode de paiement configuré.';
      }
    } on ApiException catch (e) {
      paymentModesReady.value = false;
      paymentModesError.value = e.message;
      lastPaymentModesLoadLog = _orderRepository.lastPaymentModesLog;
    } catch (e) {
      paymentModesReady.value = false;
      paymentModesError.value =
          'Impossible de charger les modes de paiement.';
      lastPaymentModesLoadLog =
          '${_orderRepository.lastPaymentModesLog ?? ''}\n$e';
    } finally {
      paymentModesLoading.value = false;
    }
  }

  Future<void> reloadPaymentModes() =>
      _loadPaymentModes(forceRefresh: true);

  String get payableTotalLabel => order?.total ?? '—';

  bool get isPaying => payingIsCash.value != null;

  bool get isPayingCash => payingIsCash.value == true;

  bool get isPayingCard => payingIsCash.value == false;

  bool get canPay =>
      resolvedOrderId != null &&
      (order?.products.isNotEmpty ?? false) &&
      !isPaying &&
      !paymentModesLoading.value;

  /// True when cached API detail has `status: "offered"`.
  bool get isOrderOffered {
    final id = resolvedOrderId;
    if (id == null || id <= 0) return false;
    final status = _orderRepository
        .cachedOrderDetail(id)?['status']
        ?.toString()
        .trim()
        .toLowerCase();
    return status == 'offered';
  }

  bool get canModifyOrder => !isOrderOffered;

  bool _blockIfOrderOffered() {
    if (!isOrderOffered) return false;
    AppSnackbar.show(
      'Table offerte',
      'Modification impossible sur une commande offerte.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
    );
    return true;
  }

  bool get canSendToKitchen {
    final currentOrder = order;
    if (currentOrder == null) return false;
    if (currentOrder.products.isEmpty) return false;
    if (isAddingProduct.value) return false;
    if (_isLocalDraft) return true;
    if (resolvedOrderId == null || resolvedOrderId! <= 0) return false;
    return true;
  }

  OrderProduct? get selectedOrderLine {
    final currentOrder = order;
    final lineIndex = selectedOrderLineIndex.value;
    if (currentOrder == null || lineIndex == null) return null;
    if (lineIndex < 0 || lineIndex >= currentOrder.products.length) return null;
    return currentOrder.products[lineIndex];
  }

  void showQuantityDialog({required BuildContext context}) {
    if (_blockIfOrderOffered()) return;

    final line = selectedOrderLine;
    if (line == null) {
      isBottomPanelExpanded.value = true;
      showPaymentOptions.value = false;
      AppSnackbar.show(
        'Sélectionnez une ligne',
        'Touchez une ligne dans la commande avant le clavier.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final product = catalogProductByName(line.name);
    if (product?.isComposed == true) {
      AppSnackbar.show(
        'Produit composé',
        'Ce produit se configure via le sélecteur de menu.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final currentQty = int.tryParse(line.quantity) ?? 0;

    TableNumberDialog.show(
      context: context,
      title: line.name.toUpperCase(),
      initialValue: currentQty > 0 ? '$currentQty' : null,
      integerOnly: true,
      maxDigits: 3,
      onConfirm: (value) {
        final parsed = int.tryParse(value.trim());
        if (parsed == null || parsed < 0) return;

        final selectedLineIndex = selectedOrderLineIndex.value;
        if (selectedLineIndex == null) return;

        unawaited(_setOrderLineQuantity(selectedLineIndex, parsed));
      },
    );
  }

  void onToolbarIconTap(IconData icon, {required BuildContext context}) {
    if (!isToolbarIconEnabled(icon)) {
      if (icon == Icons.send_outlined) {
        AppSnackbar.show(
          'Envoi indisponible',
          order?.products.isEmpty ?? true
              ? 'Ajoutez au moins un article avant l\'envoi.'
              : 'Ajoutez des articles à une commande active avant l\'envoi.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        );
      }
      return;
    }

    if (icon == Icons.keyboard_return_outlined) {
      if (canNavigateCategoryBack) {
        navigateCategoryBack();
        activeToolbarIcon.value = Icons.grid_view;
      }
      return;
    }

    if (icon == Icons.grid_view) {
      showPaymentOptions.value = false;
      isBottomPanelExpanded.value = true;
      activeToolbarIcon.value = Icons.grid_view;
      showQuantityDialog(context: context);
      return;
    }

    if (icon == Icons.menu_book) {
      activeToolbarIcon.value = Icons.menu_book;
      unawaited(openMenuSelection());
      return;
    }

    if (icon == Icons.restaurant) {
      activeToolbarIcon.value = Icons.restaurant;
      unawaited(addSuivreAfterLatestItems());
      return;
    }

    if (icon == Icons.restaurant_menu) {
      activeToolbarIcon.value = Icons.restaurant_menu;
      requestNextCourse(context: context);
      return;
    }

    if (icon == Icons.receipt_long_outlined) {
      printTicket(context: context);
      return;
    }

    if (icon == Icons.send_outlined) {
      sendToKitchen(context: context);
      return;
    }

    if (icon == Icons.payments_outlined) {
      togglePaymentOptions();
      return;
    }

    activeToolbarIcon.value = icon;
  }

  bool isToolbarIconActive(IconData icon) => activeToolbarIcon.value == icon;

  bool isToolbarIconEnabled(IconData icon) {
    // Offered order: only ticket, payment, and send stay available.
    if (isOrderOffered) {
      if (icon == Icons.receipt_long_outlined) return true;
      if (icon == Icons.payments_outlined) return true;
      if (icon == Icons.send_outlined) return canSendToKitchen;
      return false;
    }
    if (icon == Icons.send_outlined) {
      return canSendToKitchen;
    }
    if (icon == Icons.keyboard_return_outlined) {
      return canNavigateCategoryBack;
    }
    return true;
  }

  Future<void> printTicket({required BuildContext context}) async {
    final id = await _ensureResolvedOrderId();
    if (id == null || id <= 0) {
      AppSnackbar.show('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    activeToolbarIcon.value = Icons.receipt_long_outlined;
    showPaymentOptions.value = false;

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const TicketLoadingDialog(),
    );

    try {
      final updated = await _orderRepository.markOrderPrinted(
        id,
        previousDisplayEntries: order?.displayEntries,
      );
      _syncOrderInSession(updated, orderNumber);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.45),
          builder: (_) => const TicketSuccessDialog(),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      AppSnackbar.show('Erreur', e.message);
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      AppSnackbar.show('Erreur', 'Impossible d\'imprimer le ticket.');
    }
  }

  Future<void> sendToKitchen({required BuildContext context}) async {
    final currentOrder = order;
    if (currentOrder == null) return;

    if (currentOrder.products.isEmpty) {
      AppSnackbar.show(
        'Envoi impossible',
        'Ajoutez au moins un article avant l\'envoi.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    if (_isLocalDraft) {
      _sendLocalDraftToKitchen(context: context, currentOrder: currentOrder);
      return;
    }

    final id = await _ensureResolvedOrderId();
    if (id == null || id <= 0) {
      AppSnackbar.show('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    AppConfirmDialog.show(
      context: context,
      title: 'Envoyer en cuisine',
      message:
          'Envoyer toutes les commandes en attente pour la table $orderNumber ?',
      onConfirm: () {
        activeToolbarIcon.value = Icons.send_outlined;
        showPaymentOptions.value = false;
        selectedSuivreSection.value = null;

        final layoutBeforeSend = List<OrderDisplayEntry>.from(
          order?.displayEntries ?? const [],
        );
        final snapshot = order != null
            ? OrderOptimisticSync.deepSnapshot(order!)
            : OrderMapper.buildSessionPlaceholderOrder(
                tableNumber: _parsedTableNumber,
                numberOfGuests: 1,
              );

        // Queue sync first so Get.back() dispose cannot drop the send job.
        _flushQueuedSimpleAddsNow();
        _optimisticSync.enqueue(
          syncKey: _optimisticSyncKey,
          snapshot: snapshot,
          apply: (updated) {
            _applySyncedOrder(updated);
            if (Get.isRegistered<SessionController>()) {
              Get.find<SessionController>().promoteOrderToTop(
                updated,
                replaceDetail: true,
              );
            }
          },
          sync: () async {
            final updated = await _orderRepository.requestAllCourses(
              id,
              previousDisplayEntries: layoutBeforeSend,
            );
            if (_orderRepository.lastKitchenSendLog != null) {
              debugPrint(_orderRepository.lastKitchenSendLog);
            }
            return updated;
          },
          recover: (snap) async {
            try {
              return await _orderRepository.getOrderDetail(
                id,
                previousDisplayEntries: snap.displayEntries,
              );
            } catch (_) {
              return snap;
            }
          },
          onError: (error) => _showKitchenMutationError(
            title: 'Erreur envoi',
            action: 'envoyer en cuisine',
            error: error,
          ),
        );

        _returnToSessionPage(skipOrderSnapshot: true, scrollListToTop: true);
      },
    );
  }

  void _sendLocalDraftToKitchen({
    required BuildContext context,
    required SessionOrder currentOrder,
  }) {
    AppConfirmDialog.show(
      context: context,
      title: 'Envoyer en cuisine',
      message:
          'Envoyer toutes les commandes en attente pour la table $orderNumber ?',
      onConfirm: () {
        final draftLines = _buildDraftLinesForSend();
        if (draftLines.isEmpty) {
          AppSnackbar.show(
            'Envoi impossible',
            'Ajoutez au moins un article avant l\'envoi.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
          return;
        }

        activeToolbarIcon.value = Icons.send_outlined;
        showPaymentOptions.value = false;
        selectedSuivreSection.value = null;

        final layoutBeforeSend = List<OrderDisplayEntry>.from(
          currentOrder.displayEntries,
        );
        final snapshot = OrderOptimisticSync.deepSnapshot(currentOrder);
        final guests = int.tryParse(currentOrder.couverts) ?? 1;

        int? salesZoneId;
        if (Get.isRegistered<SessionController>()) {
          salesZoneId =
              Get.find<SessionController>().activeDay.value.salesZoneId;
        }
        String? waiterName;
        if (Get.isRegistered<AuthRepository>()) {
          final user = Get.find<AuthRepository>().cachedSession?.user;
          waiterName = user?.name;
        }

        _optimisticSync.enqueue(
          syncKey: _optimisticSyncKey,
          snapshot: snapshot,
          apply: (updated) {
            if (updated.id > 0) {
              orderId = updated.id;
              seedOrder = updated;
              _localDraftLines.clear();
              _deferDetailFetch = false;
            }
            // Session list must update even if this details controller is
            // already disposed after Get.back().
            if (Get.isRegistered<SessionController>()) {
              final session = Get.find<SessionController>();
              session.promoteOrderToTop(updated, replaceDetail: true);
            }
            try {
              _applySyncedOrder(updated);
            } catch (_) {}
          },
          sync: () async {
            final sent = await _orderRepository.createAndSendLocalDraft(
              tableNumber: orderNumber,
              numberOfGuests: guests,
              waiterId: _currentWaiterId,
              lines: draftLines,
              salesZoneId: salesZoneId,
              waiterName: waiterName,
              previousDisplayEntries: layoutBeforeSend,
            );
            orderId = sent.id;
            seedOrder = sent;
            _localDraftLines.clear();
            _deferDetailFetch = false;
            if (_orderRepository.lastKitchenSendLog != null) {
              debugPrint(_orderRepository.lastKitchenSendLog);
            }
            return sent;
          },
          recover: (snap) async {
            final recovered = await _orderRepository.tryRecoverCreatedOrder(
              tableNumber: orderNumber,
            );
            if (recovered != null && recovered.order.id > 0) {
              if (Get.isRegistered<SessionController>()) {
                Get.find<SessionController>().promoteOrderToTop(
                  recovered.order,
                  replaceDetail: true,
                );
              }
              return recovered.order;
            }
            return snap;
          },
          onError: (error) async {
            // Final safety: if the order exists on the server, drop the false
            // error snack after adopting it into the session list.
            final recovered = await _orderRepository.tryRecoverCreatedOrder(
              tableNumber: orderNumber,
            );
            if (recovered != null && recovered.order.id > 0) {
              if (Get.isRegistered<SessionController>()) {
                Get.find<SessionController>().promoteOrderToTop(
                  recovered.order,
                  replaceDetail: true,
                );
              }
              return;
            }
            _showKitchenMutationError(
              title: 'Erreur envoi',
              action: 'envoyer en cuisine',
              error: error,
            );
          },
        );

        _returnToSessionPage(skipOrderSnapshot: true, scrollListToTop: true);
      },
    );
  }

  Future<bool> _orderNeedsKitchenSendBeforePayment(int orderId) async {
    try {
      final cached = _orderRepository.cachedOrderDetail(orderId);
      if (cached != null) {
        return OrderMapper.requiresKitchenSendBeforePayment(cached);
      }
      await _orderRepository.getOrderDetail(orderId);
      final detail = _orderRepository.cachedOrderDetail(orderId);
      return detail != null &&
          OrderMapper.requiresKitchenSendBeforePayment(detail);
    } catch (_) {
      return false;
    }
  }

  Future<void> payOrder({required BuildContext context, required bool isCash}) async {
    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      AppSnackbar.show('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final currentOrder = order;
    if (currentOrder == null || currentOrder.products.isEmpty) {
      AppSnackbar.show(
        'Paiement indisponible',
        'Aucun article à encaisser sur cette commande.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    if (!paymentModesReady.value) {
      await _loadPaymentModes();
      if (!paymentModesReady.value) {
        AppSnackbar.show(
          'Paiement indisponible',
          paymentModesError.value ??
              'Les modes de paiement ne sont pas chargés.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }
    }

    if (!context.mounted) return;

    final label = isCash ? 'espèces' : 'carte de crédit';
    final amountLabel = payableTotalLabel;
    final needsKitchenSend = await _orderNeedsKitchenSendBeforePayment(id);
    final sendNotice = needsKitchenSend
        ? '\n\nLes articles non envoyés seront transmis en cuisine avant l\'encaissement.'
        : '';
    AppConfirmDialog.show(
      context: context,
      title: 'Paiement',
      message:
          'Encaisser $amountLabel pour la table $orderNumber en $label ?$sendNotice',
      onConfirm: () async {
        payingIsCash.value = isCash;
        try {
          final updated = await _orderRepository.payOrder(
            orderId: id,
            isCash: isCash,
            previousDisplayEntries: currentOrder.displayEntries,
          );
          _syncOrderInSession(updated, orderNumber);
          showPaymentOptions.value = false;
          isBottomPanelExpanded.value = true;
          activeToolbarIcon.value = Icons.grid_view;

          // Navigate first — showing Get.snackbar before Get.back() only
          // dismisses the snackbar and leaves the waiter on this page.
          if (Get.isSnackbarOpen) {
            Get.closeCurrentSnackbar();
          }
          _returnToSessionPage(skipOrderSnapshot: true, scrollListToTop: true);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackbar.show(
              'Paiement enregistré',
              'Le paiement en $label a été enregistré.',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
              margin: const EdgeInsets.all(16),
            );
          });
        } on ApiException catch (e) {
          AppSnackbar.show(
            'Erreur paiement',
            e.message,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(16),
          );
          debugPrint(_orderRepository.lastPaymentLog);
        } catch (e) {
          AppSnackbar.show(
            'Erreur',
            'Impossible d\'enregistrer le paiement.',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
          );
          debugPrint(_orderRepository.lastPaymentLog);
          debugPrint('payOrder unexpected: $e');
        } finally {
          payingIsCash.value = null;
        }
      },
    );
  }

  Future<void> addSuivreAfterLatestItems() async {
    if (_blockIfOrderOffered()) return;
    if (isAddingProduct.value) {
      AppSnackbar.show(
        'À SUIVRE',
        'Veuillez patienter pendant l\'annulation de la suite.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final currentOrder = _rawSessionOrder ?? order;
    if (currentOrder == null) {
      AppSnackbar.show('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    if (currentOrder.products.isEmpty) {
      AppSnackbar.show(
        'À SUIVRE',
        'Ajoutez d\'abord un article avant d\'ouvrir la suite.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // Drop empty À SUIVRE ghosts left after delete/sync so create adds exactly one.
    final cleaned = OrderMapper.stripEmptySuivreSectionsForCreate(
      currentOrder.displayEntries,
    );

    final beforeCount = OrderMapper.suivreSeparatorCount(cleaned);
    final displayEntries = OrderMapper.appendSuivreSeparatorAfterRequest(cleaned);
    final afterCount = OrderMapper.suivreSeparatorCount(displayEntries);

    if (afterCount <= beforeCount) {
      AppSnackbar.show(
        'À SUIVRE',
        'La suite est déjà ouverte.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final suivreEntry = displayEntries.lastWhere(
      (entry) => entry.type == OrderDisplayEntryType.suivreSeparator,
    );
    final sectionIndex = suivreEntry.sectionIndex ?? 0;

    collapsedSuivreSections.remove(sectionIndex);
    collapsedSuivreSections.refresh();
    suivreUiRevision.value++;
    showPaymentOptions.value = false;
    isBottomPanelExpanded.value = true;
    activeToolbarIcon.value = Icons.restaurant;
    selectedSuivreSection.value = sectionIndex;

    final id = resolvedOrderId;
    // Invalidate + bump BEFORE any await — a late cancel/sync must not wipe
    // this newly opened À SUIVRE (or items added under it).
    _invalidateBackgroundApplies();
    if (id != null && id > 0) {
      _orderRepository.bumpDetailRevision(id);
    }

    _syncOrderInSession(
      currentOrder.copyWith(displayEntries: displayEntries),
      orderNumber,
      displayEntriesOverride: displayEntries,
    );

    if (id != null && id > 0) {
      unawaited(
        _orderRepository.persistSuivreLayoutHints(id, displayEntries),
      );
    }
  }

  Future<void> requestNextCourse({BuildContext? context}) async {
    if (_blockIfOrderOffered()) return;

    if (_isLocalDraft) {
      AppSnackbar.show(
        'Envoi requis',
        'Envoyez d\'abord la commande avant une demande.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final id = await _ensureResolvedOrderId();
    if (id == null || id <= 0) {
      AppSnackbar.show(
        'Envoi requis',
        'Envoyez d\'abord la commande avant une demande.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final sectionIndex = selectedSuivreSection.value;
    if (sectionIndex == null || sectionIndex <= 0) {
      AppSnackbar.show(
        'Sélection requise',
        'Sélectionnez un À SUIVRE avant de demander.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final currentOrder = order;
    if (currentOrder != null &&
        !isSelectedSectionRequestable(currentOrder.displayEntries)) {
      selectedSuivreSection.value = null;
      AppSnackbar.show(
        'Sélection invalide',
        'Ce service est déjà demandé. Sélectionnez un À SUIVRE ouvert.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final courseNumber = currentOrder == null
        ? null
        : OrderMapper.resolveCourseNumberForSuivreSection(
            currentOrder.displayEntries,
            sectionIndex,
          );
    // À SUIVRE divider stores the "course above" number used to route new
    // items into the next course. When user taps Demande for that divider,
    // we must request the follow-up service (= courseNumber + 1).
    final demandeCourseNumber = courseNumber != null ? courseNumber + 1 : null;

    if (demandeCourseNumber == null || demandeCourseNumber <= 0) {
      AppSnackbar.show(
        'Erreur',
        'Impossible d\'identifier le service à demander.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    AppConfirmDialog.show(
      context: context,
      title: 'Demande',
      message:
          'Envoyer en cuisine le service sélectionné (course $demandeCourseNumber) ?',
      onConfirm: () {
        final orderSnapshot = order;
        if (orderSnapshot == null) return;

        activeToolbarIcon.value = Icons.restaurant_menu;
        showPaymentOptions.value = false;

        final snapshot = OrderOptimisticSync.deepSnapshot(orderSnapshot);
        final layoutBefore = List<OrderDisplayEntry>.from(
          orderSnapshot.displayEntries,
        );
        final demandeTimeLabel = _freshDemandeTimeLabel();
        final predicted = _predictAfterSuivreDemande(
          current: orderSnapshot,
          sectionIndex: sectionIndex,
          demandeTimeLabel: demandeTimeLabel,
        );

        if (selectedSuivreSection.value == sectionIndex) {
          selectedSuivreSection.value = null;
        }
        collapsedSuivreSections.clear();
        collapsedSuivreSections.refresh();

        _syncOrderInSession(
          predicted,
          orderNumber,
          displayEntriesOverride: predicted.displayEntries,
        );
        AppSnackbar.show(
          'Demande envoyée',
          'Le service a été envoyé en cuisine.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        );

        _flushQueuedSimpleAddsNow();
        _optimisticSync.enqueue(
          syncKey: _optimisticSyncKey,
          snapshot: snapshot,
          apply: (updated) {
            final merged = OrderMapper.rebuildOrderAfterSuivreDemande(
              serverOrder: updated,
              liveLayout: predicted.displayEntries,
              suivreSectionIndex: sectionIndex,
              demandeTimeLabel: demandeTimeLabel,
            );
            _syncOrderInSession(
              merged,
              orderNumber,
              displayEntriesOverride: merged.displayEntries,
            );
          },
          sync: () async {
            final liveOrder = _rawSessionOrder ?? snapshot;
            var layoutForDemande = OrderMapper.coalesceLayoutHints(
                  liveOrder.displayEntries,
                ) ??
                layoutBefore;

            try {
              final serverOrder = await _orderRepository.getOrderDetail(
                id,
                previousDisplayEntries: layoutForDemande,
              );
              layoutForDemande = OrderMapper.patchServerItemIdsOntoLive(
                live: liveOrder,
                server: serverOrder,
                suppressItemIds: _suppressDeletedItemIds,
              ).displayEntries;
            } catch (_) {}

            return _orderRepository.requestCourseForSuivreSection(
              id,
              courseNumber: demandeCourseNumber,
              previousDisplayEntries: layoutForDemande,
              suivreSectionIndex: sectionIndex,
            );
          },
          recover: (snap) async {
            try {
              return await _orderRepository.getOrderDetail(
                id,
                previousDisplayEntries: snap.displayEntries,
              );
            } catch (_) {
              return snap;
            }
          },
          onError: (error) {
            _syncOrderInSession(snapshot, orderNumber);
            _showKitchenMutationError(
              title: 'Erreur demande',
              action: 'envoyer la demande',
              error: error,
            );
          },
        );
      },
    );
  }

  void onProductTap(CatalogProductModel product) {
    if (_blockIfOrderOffered()) return;

    logOrderFlow(
      'onProductTap product=${product.id} ${product.name} table=$orderNumber',
    );

    _prepareForNewAdd();
    _invalidateDeleteAppliesIfNeeded();

    if (product.isComposed) {
      // Flush any pending simple batch before opening the menu composer.
      _flushQueuedSimpleAddsNow();
      unawaited(_handleComposedProductTap(product));
      return;
    }

    _queueSimpleProductAdd(product);
  }

  void _queueSimpleProductAdd(CatalogProductModel product) {
    // Snapshot once per burst — empty-shell must not poison rollback.
    _simpleAddBatchRollback ??= _rawSessionOrder != null
        ? OrderOptimisticSync.deepSnapshot(_rawSessionOrder!)
        : null;
    _applyAddSimpleProductToUi(product);
    if (isProductInOrder(product, source: _rawSessionOrder)) {
      selectedProductId.value = product.id;
      selectedOrderLineIndex.value = null;
    }
    if (_isLocalDraft) {
      _trackLocalDraftAddSimple(product);
      return;
    }
    _queuedSimpleAdds.add(product);
    // Always debounce. Never flush-on-pending — that spawned one sync job per
    // tap and froze the UI. One in-flight batch drains the whole queue after.
    if (!_simpleAddSyncEnqueued) {
      _scheduleCoalescedSimpleAddSync();
    }
  }

  /// Drop debounced/queued adds — waiter deleted; do not PUT them later.
  void _discardPendingSimpleAdds() {
    _simpleAddBatchTimer?.cancel();
    _simpleAddBatchTimer = null;
    _queuedSimpleAdds.clear();
    _simpleAddBatchRollback = null;
  }

  /// True when a background add must not hit the API / UI (ticket cleared).
  bool _shouldAbortBackgroundAdd() {
    final live = _rawSessionOrder;
    final id = orderId ?? live?.id ?? 0;
    if (id > 0 && _orderRepository.shouldDisplayAsEmptyCreateShell(id)) {
      return true;
    }
    if (live != null &&
        live.products.isEmpty &&
        id > 0 &&
        _orderRepository.hasPendingLocalDelete(id)) {
      return true;
    }
    return false;
  }

  SessionOrder _emptyTicketShell(SessionOrder template) {
    return template.copyWith(
      products: const [],
      displayEntries: const [],
      itemCount: 0,
      total: OrderMapper.formatPrice('0'),
    );
  }

  void _scheduleCoalescedSimpleAddSync() {
    _simpleAddBatchTimer?.cancel();
    _simpleAddBatchTimer = Timer(_simpleAddBatchWindow, () {
      _enqueueCoalescedSimpleAddSync();
    });
  }

  void _flushQueuedSimpleAddsNow() {
    _simpleAddBatchTimer?.cancel();
    _simpleAddBatchTimer = null;
    if (_queuedSimpleAdds.isEmpty) return;
    _enqueueCoalescedSimpleAddSync();
  }

  /// At most one sync job; it loops until the tap queue is empty so a burst
  /// becomes a few batched PUTs — never one HTTP call per tap.
  void _enqueueCoalescedSimpleAddSync() {
    if (_queuedSimpleAdds.isEmpty) return;
    if (_simpleAddSyncEnqueued) return;
    _simpleAddSyncEnqueued = true;

    final snapshot = _simpleAddBatchRollback ??
        _rawSessionOrder ??
        OrderMapper.buildSessionPlaceholderOrder(
          tableNumber: _parsedTableNumber,
          numberOfGuests: 1,
        );
    _simpleAddBatchRollback = null;

    final epochAtEnqueue = _ticketMutationEpoch;
    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: _applySyncedOrder,
      sync: () async {
        SessionOrder? lastResult;
        try {
          // Drain in rounds: each round = 1 GET+PUT with every line queued
          // since the previous round (or debounce). UI stays responsive.
          while (true) {
            await Future<void>.delayed(const Duration(milliseconds: 40));

            if (epochAtEnqueue != _ticketMutationEpoch ||
                _shouldAbortBackgroundAdd()) {
              logOrderFlow(
                'abort coalescedSimpleBatch — ticket cleared '
                '(epoch $epochAtEnqueue→$_ticketMutationEpoch)',
              );
              _queuedSimpleAdds.clear();
              return _rawSessionOrder ??
                  lastResult ??
                  _emptyTicketShell(snapshot);
            }

            if (_queuedSimpleAdds.isEmpty) {
              // Brief settle so taps mid-flight join this same job.
              await Future<void>.delayed(const Duration(milliseconds: 120));
              if (_queuedSimpleAdds.isEmpty ||
                  epochAtEnqueue != _ticketMutationEpoch ||
                  _shouldAbortBackgroundAdd()) {
                break;
              }
            }

            final batch = List<CatalogProductModel>.from(_queuedSimpleAdds);
            _queuedSimpleAdds.clear();
            if (batch.isEmpty) break;

            logOrderFlow(
              'coalescedSimpleBatch count=${batch.length} '
              'products=${batch.map((p) => p.id).join(',')}',
            );

            final lines = [
              for (final product in batch)
                SimpleProductBatchLine(
                  productId: product.id,
                  unitPrice: product.unitPrice,
                ),
            ];
            final live = _rawSessionOrder;
            final reopeningEmpty = live == null ||
                live.products.isEmpty ||
                (lastResult == null && snapshot.products.isEmpty);
            final layoutHints = live != null && live.displayEntries.isNotEmpty
                ? live.displayEntries
                : lastResult?.displayEntries ??
                    (snapshot.displayEntries.isNotEmpty
                        ? snapshot.displayEntries
                        : null);

            final id = await _resolveOrderIdForBackgroundSync();
            if (epochAtEnqueue != _ticketMutationEpoch ||
                _shouldAbortBackgroundAdd()) {
              return _rawSessionOrder ??
                  lastResult ??
                  _emptyTicketShell(snapshot);
            }

            if (id == null || id <= 0) {
              final first = batch.first;
              final rest = lines.sublist(1);
              final created =
                  await _orderRepository.createOrderWithFirstSimpleProduct(
                tableNumber: orderNumber,
                waiterId: _currentWaiterId,
                productId: first.id,
                unitPrice: first.unitPrice,
                qty: 1,
                numberOfGuests: int.tryParse(snapshot.couverts),
              );
              if (epochAtEnqueue != _ticketMutationEpoch ||
                  _shouldAbortBackgroundAdd()) {
                return _rawSessionOrder ?? _emptyTicketShell(created);
              }
              orderId = created.id;
              lastResult = created;
              if (rest.isNotEmpty) {
                lastResult =
                    await _orderRepository.addSimpleProductsBatchToOrder(
                  orderId: created.id,
                  items: rest,
                  layoutHints: created.displayEntries,
                  selectedSuivreSectionIndex: selectedSuivreSection.value,
                  tableNumber: orderNumber,
                  waiterId: _currentWaiterId,
                );
                orderId = lastResult.id;
              }
            } else {
              orderId = id;
              lastResult =
                  await _orderRepository.addSimpleProductsBatchToOrder(
                orderId: id,
                items: lines,
                layoutHints: layoutHints,
                selectedSuivreSectionIndex: selectedSuivreSection.value,
                tableNumber: orderNumber,
                waiterId: _currentWaiterId,
                expectEmptyShell: reopeningEmpty,
              );
              if (epochAtEnqueue != _ticketMutationEpoch ||
                  _shouldAbortBackgroundAdd()) {
                return _rawSessionOrder ?? _emptyTicketShell(lastResult);
              }
              orderId = lastResult.id;
            }

            // Yield so frames can paint between batch rounds.
            await Future<void>.delayed(Duration.zero);
          }

          return _rawSessionOrder ?? lastResult ?? snapshot;
        } finally {
          _simpleAddSyncEnqueued = false;
          if (_queuedSimpleAdds.isNotEmpty && !_shouldAbortBackgroundAdd()) {
            // More taps after we finished — one more job, no per-tap APIs.
            _scheduleCoalescedSimpleAddSync();
          }
        }
      },
      recover: (snap) async {
        _simpleAddSyncEnqueued = false;
        if (_queuedSimpleAdds.isNotEmpty && !_shouldAbortBackgroundAdd()) {
          _scheduleCoalescedSimpleAddSync();
        } else {
          _queuedSimpleAdds.clear();
        }
        final live = _rawSessionOrder;
        if (live != null) return live;
        return _emptyTicketShell(snap);
      },
      onError: (error) =>
          _showOptimisticMutationError('ajouter les articles', error),
    );
  }

  Future<void> _handleComposedProductTap(CatalogProductModel product) async {
    try {
      final layoutHints = order?.displayEntries;
      final detail = await _catalogRepository.getProductDetail(product.id);
      final presetMenu = MenuMapper.presetFromProduct(
        detail,
        badgeNumber: 1,
      );

      final result = await Get.toNamed(
        AppRoutes.menu,
        arguments: {
          'table': orderNumber,
          'presetMenu': presetMenu,
          'choiceNumber': 1,
          'returnToSelection': false,
        },
      );

      if (result is! MenuActiveSelection) return;

      final menuSelections = MenuMapper.menuSelectionsFromItems(
        result.allSelectedItems,
      );
      if (menuSelections.isEmpty) return;

      final rollbackSnapshot =
          order != null ? OrderOptimisticSync.deepSnapshot(order!) : null;

      _applyAddComposedProductToUi(
        product: detail,
        menuSelections: menuSelections,
        layoutHints: layoutHints,
      );
      if (_isLocalDraft) {
        _trackLocalDraftAddComposed(
          product: detail,
          menuSelections: menuSelections,
        );
        return;
      }
      unawaited(
        _syncAddComposedProductInBackground(
          product: detail,
          menuSelections: menuSelections,
          rollbackSnapshot: rollbackSnapshot,
          layoutHints: layoutHints,
        ),
      );
    } on ApiException catch (e) {
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur ajout article', body: e.message);
    } catch (_) {
      AppSnackbar.show('Erreur', 'Impossible d\'ajouter l\'article.');
    }
  }

  void _applyAddSimpleProductToUi(CatalogProductModel product) {
    _prepareForNewAdd();
    var current = _rawSessionOrder ?? order;
    if (current == null) {
      current = OrderMapper.buildSessionPlaceholderOrder(
        tableNumber: _parsedTableNumber,
        numberOfGuests: 1,
      );
    }
    current = OrderMapper.ensureSessionDisplayHydrated(current);
    if (current.products.isEmpty) {
      current = current.copyWith(
        products: const [],
        displayEntries: const [],
        itemCount: 0,
      );
    }

    final predicted = OrderMapper.predictAppendSimpleProductFast(
      current: current,
      productName: product.name,
      unitPrice: product.unitPrice,
      selectedSuivreSectionIndex: selectedSuivreSection.value,
    );
    _syncOrderInSession(
      predicted,
      orderNumber,
      displayEntriesOverride: predicted.displayEntries,
      throttleUiRevision: true,
    );
  }

  void _applyAddComposedProductToUi({
    required CatalogProductModel product,
    required List<Map<String, dynamic>> menuSelections,
    List<OrderDisplayEntry>? layoutHints,
    String comment = '',
    int? selectedSuivreSectionIndex,
  }) {
    _prepareForNewAdd();
    var current = _rawSessionOrder ?? order;
    if (current == null) {
      current = OrderMapper.buildSessionPlaceholderOrder(
        tableNumber: _parsedTableNumber,
        numberOfGuests: 1,
      );
    }
    current = OrderMapper.ensureSessionDisplayHydrated(current);
    if (current.products.isEmpty) {
      current = current.copyWith(
        products: const [],
        displayEntries: const [],
        itemCount: 0,
      );
    }

    final hints = layoutHints ?? current.displayEntries;
    final suivreCount = OrderMapper.suivreSeparatorCount(hints);
    final suivreSplits = OrderMapper.suivreSplitPositions(hints);
    final fastId = _fastResolvedOrderId;
    final cached =
        fastId != null ? _orderRepository.cachedOrderDetail(fastId) : null;
    final suivreTarget =
        selectedSuivreSectionIndex ?? selectedSuivreSection.value;

    final predicted = OrderMapper.predictAfterAppendComposedProduct(
      current: current,
      cachedDetail: cached,
      productId: product.id,
      productName: product.name,
      basePrice: product.unitPrice,
      menuSelections: menuSelections,
      comment: comment,
      suivreSectionCount: suivreCount,
      suivreSplitHints: suivreSplits,
      layoutHints: hints,
      selectedSuivreSectionIndex: suivreTarget,
    );
    _syncOrderInSession(
      predicted,
      orderNumber,
      displayEntriesOverride: predicted.displayEntries,
    );
    if (predicted.products.isNotEmpty) {
      selectedProductId.value = product.id;
      selectedOrderLineIndex.value = predicted.products.length - 1;
      final newLineIndex = predicted.products.length - 1;
      expandedMenuLineIndices.add(newLineIndex);
      expandedMenuLineIndices.refresh();
      orderUiRevision.value++;
    }
  }

  Future<void> _syncAddComposedProductInBackground({
    required CatalogProductModel product,
    required List<Map<String, dynamic>> menuSelections,
    SessionOrder? rollbackSnapshot,
    List<OrderDisplayEntry>? layoutHints,
    String comment = '',
    int? selectedSuivreSectionIndex,
  }) async {
    final snapshot = rollbackSnapshot ??
        _rawSessionOrder ??
        OrderMapper.buildSessionPlaceholderOrder(
          tableNumber: _parsedTableNumber,
          numberOfGuests: 1,
        );
    final effectiveLayoutHints = layoutHints ?? snapshot.displayEntries;
    final epochAtEnqueue = _ticketMutationEpoch;

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: _applySyncedOrder,
      sync: () async {
        if (epochAtEnqueue != _ticketMutationEpoch ||
            _shouldAbortBackgroundAdd()) {
          return _rawSessionOrder ?? _emptyTicketShell(snapshot);
        }
        final id = await _resolveOrderIdForBackgroundSync();
        if (epochAtEnqueue != _ticketMutationEpoch ||
            _shouldAbortBackgroundAdd()) {
          return _rawSessionOrder ?? _emptyTicketShell(snapshot);
        }
        final hints =
            _rawSessionOrder?.displayEntries ?? effectiveLayoutHints;
        if (id == null || id <= 0) {
          final created =
              await _orderRepository.createOrderWithFirstComposedProduct(
            tableNumber: orderNumber,
            waiterId: _currentWaiterId,
            productId: product.id,
            basePrice: product.unitPrice,
            menuSelections: menuSelections,
            numberOfGuests: int.tryParse(snapshot.couverts),
          );
          if (epochAtEnqueue != _ticketMutationEpoch ||
              _shouldAbortBackgroundAdd()) {
            return _rawSessionOrder ?? _emptyTicketShell(created);
          }
          orderId = created.id;
          return created;
        }

        orderId = id;
        final suivreTarget =
            selectedSuivreSectionIndex ?? selectedSuivreSection.value;
        final updated = await _orderRepository.addComposedProductToOrder(
          orderId: id,
          productId: product.id,
          basePrice: product.unitPrice,
          menuSelections: menuSelections,
          comment: comment,
          layoutHints: hints,
          selectedSuivreSectionIndex: suivreTarget,
          tableNumber: orderNumber,
          waiterId: _currentWaiterId,
          expectEmptyShell: snapshot.products.isEmpty,
        );
        if (epochAtEnqueue != _ticketMutationEpoch ||
            _shouldAbortBackgroundAdd()) {
          return _rawSessionOrder ?? _emptyTicketShell(updated);
        }
        orderId = updated.id;
        return updated;
      },
      recover: (snap) async {
        final live = _rawSessionOrder;
        if (live != null) return live;
        return _emptyTicketShell(snap);
      },
      onError: (error) =>
          _showOptimisticMutationError('ajouter le menu', error),
    );
  }

  Future<int?> _resolveOrderIdForBackgroundSync() async {
    final live = _rawSessionOrder;
    final liveEmpty = live == null || live.products.isEmpty;
    final fast = _fastResolvedOrderId;

    // After delete-all the cached id may be cancelled/gone. Prefer the table's
    // live active order so re-add / Demande use a real id.
    if (liveEmpty || fast == null || fast <= 0) {
      final resolved =
          await _orderRepository.resolveOrderIdForTableNumber(orderNumber);
      if (resolved != null && resolved > 0) {
        if (orderId != resolved) {
          orderId = resolved;
        }
        return resolved;
      }
    }

    if (fast != null && fast > 0) return fast;

    // Local session-only shell (id <= 0): create with the first selected item
    // instead of attaching whatever order the table list might still reference.
    final current = order;
    if (orderId == null || orderId! <= 0) {
      if (current == null || current.isLocalOnly) {
        return null;
      }
    }

    final resolved =
        await _orderRepository.resolveOrderIdForTableNumber(orderNumber);
    if (resolved != null && resolved > 0) {
      orderId = resolved;
      return resolved;
    }

    // Prefer the id we already opened with (create / seedOrder) when tables
    // list has not yet published the new active order.
    if (orderId != null && orderId! > 0) return orderId;
    if (current != null && current.id > 0 && !current.isLocalOnly) {
      return current.id;
    }
    return null;
  }

  Future<void> _setOrderLineQuantity(int lineIndex, int qty) async {
    final id = resolvedOrderId;
    final current = order;
    if (current == null) return;

    if (id == null || id <= 0) {
      if (!_isLocalDraft) return;
      if (qty <= 0) {
        cancelOrderLine(lineIndex);
        return;
      }
      final predicted = OrderMapper.predictAfterSetLineQuantityAtIndex(
        current: current,
        lineIndex: lineIndex,
        qty: qty,
      );
      _syncOrderInSession(predicted, orderNumber);
      _setLocalDraftLineQtyAt(lineIndex, qty);
      return;
    }

    await _optimisticSetLineQuantity(
      orderId: id,
      current: current,
      lineIndex: lineIndex,
      qty: qty,
    );
  }

  void _syncOrderInSession(
    SessionOrder updated,
    String displayNumber, {
    List<OrderDisplayEntry>? displayEntriesOverride,
    bool throttleUiRevision = false,
  }) {
    if (!Get.isRegistered<SessionController>()) return;

    var displayEntries = displayEntriesOverride ?? updated.displayEntries;
    final synced = updated.copyWith(
      displayEntries: displayEntries,
      itemCount: updated.products.isNotEmpty
          ? updated.products.length
          : updated.itemCount,
    );

    // Skip identical writes — rapid bg sync must not thrash Obx rebuilds.
    // Also require the same under-suivre product count so a flattened sync
    // cannot be ignored while the visible suite layout is wrong.
    // Session list shows impression / couverts / poste — those must sync too.
    final existing = _rawSessionOrder;
    if (existing != null &&
        existing.id == synced.id &&
        existing.total == synced.total &&
        existing.impressionCount == synced.impressionCount &&
        existing.couverts == synced.couverts &&
        existing.poste == synced.poste &&
        existing.profitCenter == synced.profitCenter &&
        existing.products.length == synced.products.length &&
        OrderMapper.productEntryCount(existing.displayEntries) ==
            OrderMapper.productEntryCount(synced.displayEntries) &&
        OrderMapper.suivreSeparatorCount(existing.displayEntries) ==
            OrderMapper.suivreSeparatorCount(synced.displayEntries) &&
        OrderMapper.demandeSeparatorCount(existing.displayEntries) ==
            OrderMapper.demandeSeparatorCount(synced.displayEntries) &&
        OrderMapper.layoutHasProductsUnderPendingSuivre(
              existing.displayEntries) ==
            OrderMapper.layoutHasProductsUnderPendingSuivre(
              synced.displayEntries) &&
        !_liveItemIdsDiffer(existing, synced) &&
        !OrderMapper.orderLineMessagesDiffer(existing, synced)) {
      _reconcileCatalogSelection(source: synced);
      return;
    }

    // Always write the real ticket; never mask an optimistic add/delete.
    if (synced.id > 0) {
      _orderRepository.bumpDetailRevision(synced.id);
      if (synced.products.isNotEmpty || displayEntries.isNotEmpty) {
        _orderRepository.clearEmptyShellDisplay(synced.id);
      }
    }

    // Keep seed in sync so back-navigation always has the latest total.
    if (seedOrder != null &&
        (seedOrder!.id == synced.id ||
            seedOrder!.number == synced.number ||
            seedOrder!.number == displayNumber)) {
      seedOrder = synced;
    }

    Get.find<SessionController>().updateOrderRow(
      synced,
      replaceDetail: true,
    );
    _reconcileCatalogSelection(source: synced);

    final now = DateTime.now();
    final shouldBumpRevision = !throttleUiRevision ||
        _lastOrderUiRevisionAt == null ||
        now.difference(_lastOrderUiRevisionAt!) >= _orderUiRevisionMinInterval;
    if (shouldBumpRevision) {
      _lastOrderUiRevisionAt = now;
      orderUiRevision.value++;
    }

    final id = synced.id;
    if (id > 0 && Get.isRegistered<OrderRepository>()) {
      unawaited(
        Get.find<OrderRepository>().persistSuivreLayoutHints(
          id,
          displayEntries,
        ),
      );
    }
  }

  bool isProductInOrder(
    CatalogProductModel product, {
    SessionOrder? source,
  }) {
    return productQuantityInOrder(product, source: source) > 0;
  }

  Future<void> incrementProduct(int productIndex) async {
    if (_blockIfOrderOffered()) return;
    await _mutateLineQuantity(productIndex, 1);
  }

  Future<void> decrementProduct(int productIndex) async {
    if (_blockIfOrderOffered()) return;
    await _mutateLineQuantity(productIndex, -1);
  }

  Future<void> offerProduct(int productIndex) async {
    if (_blockIfOrderOffered()) return;

    final id = resolvedOrderId;
    if (id == null || id <= 0) {
      AppSnackbar.show('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final currentOrder = order;
    if (currentOrder == null ||
        productIndex < 0 ||
        productIndex >= currentOrder.products.length) {
      return;
    }

    isAddingProduct.value = true;
    try {
      final updated = await _orderRepository.applyOfferAtLineIndex(
        orderId: id,
        lineIndex: productIndex,
      );
      _syncOrderInSession(updated, orderNumber);
      AppSnackbar.show(
        'Offert',
        '${currentOrder.products[productIndex].name} a été offert.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
    } on ApiException catch (e) {
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur offre', body: e.message);
    } catch (_) {
      AppSnackbar.show('Erreur', 'Impossible d\'offrir l\'article.');
    } finally {
      isAddingProduct.value = false;
    }
  }

  Future<void> _mutateLineQuantity(int productIndex, int delta) async {
    final id = resolvedOrderId;
    final currentOrder = order;
    if (currentOrder == null ||
        productIndex < 0 ||
        productIndex >= currentOrder.products.length) {
      return;
    }

    final line = currentOrder.products[productIndex];
    if (delta < 0) {
      final qty = int.tryParse(line.quantity) ?? 1;
      if (qty <= 1) {
        cancelOrderLine(productIndex);
        return;
      }
    }

    if (id == null || id <= 0) {
      if (!_isLocalDraft) {
        AppSnackbar.show('Erreur', 'Commande introuvable pour cette table.');
        return;
      }
      final predicted = OrderMapper.predictAfterAdjustLineQuantityAtIndex(
        current: currentOrder,
        lineIndex: productIndex,
        delta: delta,
      );
      _syncOrderInSession(predicted, orderNumber);
      final newQty = (int.tryParse(line.quantity) ?? 1) + delta;
      _setLocalDraftLineQtyAt(productIndex, newQty);
      return;
    }

    await _optimisticAdjustLineQuantity(
      orderId: id,
      current: currentOrder,
      lineIndex: productIndex,
      delta: delta,
    );
  }

  void _cancelSuivreSectionLocally(
    int sectionIndex,
    SessionOrder currentOrder,
  ) {
    final lineIndices = OrderMapper.productLineIndicesForSection(
      currentOrder.displayEntries,
      sectionIndex,
    );
    final trimmedDisplay = OrderMapper.removeSuivreSectionFromDisplay(
      currentOrder.displayEntries,
      sectionIndex,
    );

    final sortedIndices = lineIndices.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final i in sortedIndices) {
      _removeLocalDraftLineAt(i);
    }

    collapsedSuivreSections.remove(sectionIndex);
    collapsedSuivreSections.refresh();
    if (selectedSuivreSection.value == sectionIndex) {
      selectedSuivreSection.value = null;
    }
    suivreUiRevision.value++;
    if (selectedOrderLineIndex.value != null &&
        lineIndices.contains(selectedOrderLineIndex.value)) {
      selectedOrderLineIndex.value = null;
    }

    final optimisticProducts = [
      for (final entry in trimmedDisplay)
        if (entry.type == OrderDisplayEntryType.product && entry.product != null)
          entry.product!,
    ];
    final total = optimisticProducts.isEmpty
        ? OrderMapper.formatPrice('0')
        : OrderMapper.formatPrice(
            optimisticProducts
                .fold<double>(
                  0,
                  (sum, line) => sum + _parseFormattedLineTotal(line.price),
                )
                .toStringAsFixed(2),
          );

    _syncOrderInSession(
      currentOrder.copyWith(
        products: optimisticProducts,
        displayEntries: trimmedDisplay,
        itemCount: optimisticProducts.length,
        total: total,
      ),
      orderNumber,
      displayEntriesOverride: trimmedDisplay,
    );
  }

  Future<void> cancelSuivreSection(int sectionIndex) async {
    if (_blockIfOrderOffered()) return;

    final currentOrder = order;
    if (currentOrder == null) return;

    if (_isLocalDraft) {
      _cancelSuivreSectionLocally(sectionIndex, currentOrder);
      return;
    }

    final id = resolvedOrderId ?? await _ensureResolvedOrderId();
    if (id == null || id <= 0) {
      AppSnackbar.show('Erreur', 'Commande introuvable pour cette table.');
      return;
    }

    final lineIndices = OrderMapper.productLineIndicesForSection(
      currentOrder.displayEntries,
      sectionIndex,
    );
    final trimmedDisplay = OrderMapper.removeSuivreSectionFromDisplay(
      currentOrder.displayEntries,
      sectionIndex,
    );
    final trimmedSuivre =
        OrderMapper.suivreSeparatorCount(trimmedDisplay);
    final trimmedProducts =
        OrderMapper.productEntryCount(trimmedDisplay);

    // Suppress cancelled suite item ids so background refresh cannot resurrect.
    for (final entry in currentOrder.displayEntries) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      if ((entry.sectionIndex ?? 0) != sectionIndex) continue;
      _suppressDeletedLine(entry.itemId, orderId: id);
    }

    collapsedSuivreSections.remove(sectionIndex);
    collapsedSuivreSections.refresh();
    if (selectedSuivreSection.value == sectionIndex) {
      selectedSuivreSection.value = null;
    }
    suivreUiRevision.value++;
    if (selectedOrderLineIndex.value != null &&
        lineIndices.contains(selectedOrderLineIndex.value)) {
      selectedOrderLineIndex.value = null;
    }

    // Optimistic: remove items + the À SUIVRE row immediately.
    final optimisticProducts = [
      for (final entry in trimmedDisplay)
        if (entry.type == OrderDisplayEntryType.product && entry.product != null)
          entry.product!,
    ];
    final revisionAtStart = _orderRepository.detailRevision(id);
    _orderRepository.bumpDetailRevision(id);
    _invalidateBackgroundApplies();

    _syncOrderInSession(
      currentOrder.copyWith(
        products: optimisticProducts,
        displayEntries: trimmedDisplay,
        itemCount: optimisticProducts.length,
        total: optimisticProducts.isEmpty
            ? OrderMapper.formatPrice('0')
            : currentOrder.total,
      ),
      orderNumber,
      displayEntriesOverride: trimmedDisplay,
    );
    // Persist off the critical path — awaiting here let late syncs wipe a
    // newly recreated À SUIVRE while this cancel was still in flight.
    unawaited(_orderRepository.persistSuivreLayoutHints(id, trimmedDisplay));

    isAddingProduct.value = true;
    try {
      SessionOrder updated;
      if (lineIndices.isNotEmpty) {
        updated = await _orderRepository.cancelOrderLinesAtIndices(
          orderId: id,
          lineIndices: lineIndices,
          previousDisplayEntries: trimmedDisplay,
        );
      } else {
        updated = await _orderRepository.syncDisplayFromTrimmedLayout(
          id,
          trimmedDisplay: trimmedDisplay,
        );
      }
      if (updated.id > 0) orderId = updated.id;

      final live = _rawSessionOrder;
      final liveSuivre = live == null
          ? 0
          : OrderMapper.suivreSeparatorCount(live.displayEntries);
      final liveProducts = live == null
          ? 0
          : OrderMapper.productEntryCount(live.displayEntries);
      final revisionMoved =
          _orderRepository.detailRevision(id) != revisionAtStart + 1;
      // Waiter already opened a new suite / added items — never overwrite.
      if (revisionMoved ||
          liveSuivre > trimmedSuivre ||
          liveProducts > trimmedProducts) {
        _releaseDeletedLinesConfirmedBy(updated);
        if (live != null) {
          unawaited(
            _orderRepository.persistSuivreLayoutHints(id, live.displayEntries),
          );
        }
        return;
      }

      // Keep the waiter-trimmed layout — only refresh product payloads/ids.
      final cleanedDisplay = OrderMapper.stabilizeLiveLayoutWithServer(
        live: trimmedDisplay,
        server: updated.displayEntries,
      );
      final cleanedProducts = [
        for (final entry in cleanedDisplay)
          if (entry.type == OrderDisplayEntryType.product &&
              entry.product != null)
            entry.product!,
      ];
      await _orderRepository.persistSuivreLayoutHints(id, cleanedDisplay);
      _syncOrderInSession(
        updated.copyWith(
          products: cleanedProducts,
          displayEntries: cleanedDisplay,
          itemCount: cleanedProducts.length,
          total: cleanedProducts.isEmpty
              ? OrderMapper.formatPrice('0')
              : updated.total,
        ),
        orderNumber,
        displayEntriesOverride: cleanedDisplay,
      );
    } on ApiException catch (e) {
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur annulation', body: e.message);
    } catch (_) {
      AppSnackbar.show('Erreur', 'Impossible d\'annuler cette suite.');
    } finally {
      isAddingProduct.value = false;
    }
  }

  void cancelOrderLine(int productIndex) {
    if (_blockIfOrderOffered()) return;
    unawaited(_cancelOrderLine(productIndex));
  }

  /// Optimistic remove locally, then cancel on the API in the background.
  Future<void> _cancelOrderLine(int productIndex) async {
    final currentOrder = order;
    if (currentOrder == null ||
        productIndex < 0 ||
        productIndex >= currentOrder.products.length) {
      return;
    }

    // Abort in-flight adds only when clearing the whole ticket — partial
    // deletes must not discard items the waiter adds immediately after.
    final predicted = OrderMapper.predictAfterCancelLineAtIndex(
      currentOrder,
      productIndex,
    );
    final clearingTicket = predicted.products.isEmpty;
    if (clearingTicket) {
      _ticketMutationEpoch++;
      _discardPendingSimpleAdds();
    }

    final line = currentOrder.products[productIndex];
    final catalog = catalogProductByName(line.name);
    if (catalog != null && selectedProductId.value == catalog.id) {
      selectedProductId.value = null;
    }
    if (selectedOrderLineIndex.value == productIndex) {
      selectedOrderLineIndex.value = null;
    }

    final snapshot = OrderOptimisticSync.deepSnapshot(currentOrder);
    int? deletedItemId;
    for (final entry in currentOrder.displayEntries) {
      if (entry.type == OrderDisplayEntryType.product &&
          entry.lineIndex == productIndex) {
        deletedItemId = entry.itemId;
        break;
      }
    }

    final predictedAfterCancel = predicted;
    final activeId = orderId ?? currentOrder.id;
    logOrderDelete(
      phase: 'tap',
      orderId: activeId > 0 ? activeId : null,
      tableNumber: orderNumber,
      lineIndex: productIndex,
      itemId: deletedItemId,
      productName: line.name,
      clearingAll: predictedAfterCancel.products.isEmpty,
    );
    _suppressDeletedLine(deletedItemId, orderId: activeId);
    // Also suppress every remaining line id when clearing the ticket so a
    // late add response (new ids) is still blocked by empty-shell + epoch.
    if (predictedAfterCancel.products.isEmpty && activeId > 0) {
      for (final entry in currentOrder.displayEntries) {
        if (entry.type != OrderDisplayEntryType.product) continue;
        final id = entry.itemId ?? 0;
        if (id > 0) {
          _orderRepository.suppressOrderItemIds(activeId, [id]);
        }
      }
      _orderRepository.rememberEmptyShellDisplay(activeId);
      unawaited(_orderRepository.persistSuivreLayoutHints(activeId, const []));
      selectedProductId.value = null;
      selectedOrderLineIndex.value = null;
    }
    _syncOrderInSession(
      predicted,
      orderNumber,
      displayEntriesOverride: predicted.displayEntries,
    );

    if (_isLocalDraft) {
      _removeLocalDraftLineAt(productIndex);
    }

    // Clearing the ticket: one cancel-all that keeps/recreates an open order.
    // Per-line cancels let the API cancel the whole order → "ORDER ID not found".
    if (predicted.products.isEmpty) {
      _syncCancelAllInBackground(rollbackSnapshot: snapshot);
      return;
    }

    _syncCancelLineInBackground(
      lineIndex: productIndex,
      itemId: deletedItemId,
      rollbackSnapshot: snapshot,
    );
  }

  void _syncCancelAllInBackground({
    required SessionOrder rollbackSnapshot,
  }) {
    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: rollbackSnapshot,
      apply: _applyDeleteSyncSilently,
      sync: () async {
        final id = await _resolveOrderIdForBackgroundSync();
        if (id == null || id <= 0) {
          return _rawSessionOrder ?? rollbackSnapshot;
        }
        orderId = id;
        final updated = await _orderRepository.cancelAllVisibleLines(
          orderId: id,
          previousDisplayEntries: const [],
          tableNumber: orderNumber,
        );
        if (updated.id > 0) {
          orderId = updated.id;
          seedOrder = updated;
        }
        final live = _rawSessionOrder;
        if (live != null && live.products.isNotEmpty) {
          _orderRepository.clearEmptyShellDisplay(
            updated.id > 0 ? updated.id : id,
          );
          _orderRepository.clearPendingLocalDeleteFlag(
            updated.id > 0 ? updated.id : id,
          );
        }
        return updated;
      },
      recover: (snap) async {
        final id = _fastResolvedOrderId ?? snap.id;
        final live = _rawSessionOrder;
        if (live != null) return live;
        if (id > 0) {
          return _orderRepository.getOrderDetail(
            id,
            previousDisplayEntries: snap.displayEntries,
          );
        }
        return snap;
      },
      onError: (error) {
        if (error is ApiException) {
          final msg = error.message.toLowerCase();
          if (error.statusCode == 404 ||
              msg.contains('not found') ||
              msg.contains('introuvable')) {
            return;
          }
        }
        _showOptimisticMutationError('annuler les articles', error);
      },
    );
  }

  @override
  void onClose() {
    if (_isLocalDraft) {
      _discardPendingSimpleAdds();
    } else {
      _flushQueuedSimpleAddsNow();
    }
    super.onClose();
  }

  void _syncCancelLineInBackground({
    required int lineIndex,
    required SessionOrder rollbackSnapshot,
    int? itemId,
  }) {
    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: rollbackSnapshot,
      apply: _applyDeleteSyncSilently,
      sync: () async {
        final id = await _resolveOrderIdForBackgroundSync();
        if (id == null || id <= 0) {
          return _rawSessionOrder ?? rollbackSnapshot;
        }

        orderId = id;
        final liveLayout = _rawSessionOrder?.displayEntries ?? const [];
        // If the waiter already cleared the ticket, use cancel-all (keep open /
        // recreate) instead of another single-line cancel that would cancel
        // the order on the API.
        final live = _rawSessionOrder;
        final SessionOrder updated;
        if (live != null && live.products.isEmpty) {
          updated = await _orderRepository.cancelAllVisibleLines(
            orderId: id,
            previousDisplayEntries: const [],
            tableNumber: orderNumber,
          );
        } else {
          updated = await _orderRepository.cancelOrderLineAtIndex(
            orderId: id,
            lineIndex: lineIndex,
            itemId: itemId,
            previousDisplayEntries: liveLayout,
            tableNumber: orderNumber,
          );
        }
        if (updated.id > 0) orderId = updated.id;
        final liveAfter = _rawSessionOrder;
        if (liveAfter != null && liveAfter.products.isNotEmpty) {
          _orderRepository.clearEmptyShellDisplay(
            updated.id > 0 ? updated.id : id,
          );
          _orderRepository.clearPendingLocalDeleteFlag(
            updated.id > 0 ? updated.id : id,
          );
        }
        return updated;
      },
      recover: (snap) async {
        // Keep suppress on failure — do not resurrect the deleted line.
        final id = _fastResolvedOrderId ?? snap.id;
        final live = _rawSessionOrder;
        if (live != null) return live;
        if (id > 0) {
          return _orderRepository.getOrderDetail(
            id,
            previousDisplayEntries: snap.displayEntries,
          );
        }
        return snap;
      },
      onError: (error) {
        _showOptimisticMutationError('annuler l\'article', error);
      },
    );
  }

  Future<void> _optimisticAdjustLineQuantity({
    required int orderId,
    required SessionOrder current,
    required int lineIndex,
    required int delta,
  }) async {
    final snapshot = OrderOptimisticSync.deepSnapshot(current);

    final predicted = OrderMapper.predictAfterAdjustLineQuantityAtIndex(
      current: current,
      lineIndex: lineIndex,
      delta: delta,
    );
    _syncOrderInSession(predicted, orderNumber);

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: (updated) {
        // Never adopt an empty / replacement shell after a qty tweak.
        if (updated.products.isEmpty && snapshot.products.isNotEmpty) {
          return;
        }
        _applySyncedOrder(updated);
      },
      sync: () async {
        final updated = await _orderRepository.adjustOrderLineQuantityAtIndex(
          orderId: orderId,
          lineIndex: lineIndex,
          delta: delta,
          previousDisplayEntries:
              order?.displayEntries ?? predicted.displayEntries,
        );
        if (updated.id > 0) this.orderId = updated.id;
        return updated;
      },
      recover: (snap) async {
        try {
          final recovered = await _orderRepository.getOrderDetail(
            this.orderId ?? orderId,
            previousDisplayEntries: snap.displayEntries,
          );
          if (recovered.products.isEmpty && snap.products.isNotEmpty) {
            return snap;
          }
          return recovered;
        } catch (_) {
          return snap;
        }
      },
      onError: (error) =>
          _showOptimisticMutationError('modifier la quantité', error),
    );
  }

  Future<void> _optimisticSetLineQuantity({
    required int orderId,
    required SessionOrder current,
    required int lineIndex,
    required int qty,
  }) async {
    final snapshot = OrderOptimisticSync.deepSnapshot(current);

    final predicted = OrderMapper.predictAfterSetLineQuantityAtIndex(
      current: current,
      lineIndex: lineIndex,
      qty: qty,
    );
    _syncOrderInSession(predicted, orderNumber);

    _optimisticSync.enqueue(
      syncKey: _optimisticSyncKey,
      snapshot: snapshot,
      apply: (updated) {
        if (updated.products.isEmpty && snapshot.products.isNotEmpty) {
          return;
        }
        _applySyncedOrder(updated);
      },
      sync: () async {
        final updated = await _orderRepository.setOrderLineQuantityAtIndex(
          orderId: orderId,
          lineIndex: lineIndex,
          qty: qty,
        );
        if (updated.id > 0) this.orderId = updated.id;
        return updated;
      },
      recover: (snap) async {
        try {
          final recovered = await _orderRepository.getOrderDetail(
            this.orderId ?? orderId,
            previousDisplayEntries: snap.displayEntries,
          );
          if (recovered.products.isEmpty && snap.products.isNotEmpty) {
            return snap;
          }
          return recovered;
        } catch (_) {
          return snap;
        }
      },
      onError: (error) =>
          _showOptimisticMutationError('modifier la quantité', error),
    );
  }

  void _showOptimisticMutationError(String action, Object error) {
    if (error is ApiException) {
      debugPrint(_orderRepository.lastAddItemLog);
      ApiDebugDialog.show(title: 'Erreur', body: error.message);
      return;
    }
    AppSnackbar.show('Erreur', 'Impossible de $action.');
  }

  String _freshDemandeTimeLabel() {
    return OrderMapper.formatDemandeTime(
          DateTime.now().toUtc().toIso8601String(),
        ) ??
        '--:--:--';
  }

  SessionOrder _predictAfterSuivreDemande({
    required SessionOrder current,
    required int sectionIndex,
    String? demandeTimeLabel,
  }) {
    return OrderMapper.rebuildOrderAfterSuivreDemande(
      serverOrder: current,
      liveLayout: current.displayEntries,
      suivreSectionIndex: sectionIndex,
      demandeTimeLabel: demandeTimeLabel ?? _freshDemandeTimeLabel(),
    );
  }

  void _showKitchenMutationError({
    required String title,
    required String action,
    required Object error,
  }) {
    if (error is ApiException) {
      if (_orderRepository.lastKitchenSendLog != null) {
        debugPrint(_orderRepository.lastKitchenSendLog);
      }
      // Prefer the short API message — kitchen logs contain ── markers that
      // would otherwise collapse to a generic "Une erreur est survenue".
      final message = error.message.trim();
      ApiDebugDialog.show(
        title: title,
        body: message.isNotEmpty
            ? message
            : (_orderRepository.lastKitchenSendLog ??
                'Impossible de $action.'),
      );
      return;
    }
    AppSnackbar.show(
      'Erreur',
      'Impossible de $action.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  int _resolveDraftCourseNumber() {
    final layout = order?.displayEntries ?? const [];
    return OrderMapper.resolveAppendCourseNumberFromLayout(
          layout,
          selectedSectionIndex: selectedSuivreSection.value,
        ) ??
        1;
  }

  double _parseFormattedLineTotal(String price) {
    final normalized = price
        .replaceAll('€', '')
        .replaceAll('\u00a0', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(normalized) ?? 0;
  }

  void _trackLocalDraftAddSimple(CatalogProductModel product) {
    _localDraftLines.add(
      LocalDraftLine(
        productId: product.id,
        unitPrice: product.unitPrice,
        courseNumber: _resolveDraftCourseNumber(),
      ),
    );
  }

  void _trackLocalDraftAddComposed({
    required CatalogProductModel product,
    required List<Map<String, dynamic>> menuSelections,
    String comment = '',
  }) {
    final supplement = MenuMapper.menuSelectionsSupplement(menuSelections);
    _localDraftLines.add(
      LocalDraftLine(
        productId: product.id,
        unitPrice: product.unitPrice + supplement,
        menuSelections: menuSelections,
        comment: comment,
        courseNumber: _resolveDraftCourseNumber(),
      ),
    );
  }

  void _removeLocalDraftLineAt(int index) {
    if (index >= 0 && index < _localDraftLines.length) {
      _localDraftLines.removeAt(index);
    }
  }

  void _setLocalDraftLineQtyAt(int index, int qty) {
    if (index < 0 || index >= _localDraftLines.length || qty < 1) return;
    _localDraftLines[index] = _localDraftLines[index].copyWith(qty: qty);
  }

  List<LocalDraftLine> _buildDraftLinesForSend() {
    final current = order;
    if (current == null) return const [];

    int courseForLineIndex(int index) {
      for (final entry in current.displayEntries) {
        if (entry.type == OrderDisplayEntryType.product &&
            entry.lineIndex == index) {
          final fromEntry = entry.courseNumber;
          if (fromEntry != null && fromEntry > 0) return fromEntry;
          final section = entry.sectionIndex ?? 0;
          return section > 0 ? section + 1 : 1;
        }
      }
      return 1;
    }

    if (_localDraftLines.length == current.products.length) {
      return [
        for (var i = 0; i < _localDraftLines.length; i++)
          _localDraftLines[i].copyWith(courseNumber: courseForLineIndex(i)),
      ];
    }

    final rebuilt = <LocalDraftLine>[];
    for (var i = 0; i < current.products.length; i++) {
      final line = current.products[i];
      final catalog = catalogProductByName(line.name);
      if (catalog == null) continue;

      final qty = int.tryParse(line.quantity) ?? 1;
      final lineTotal = _parseFormattedLineTotal(line.price);
      rebuilt.add(
        LocalDraftLine(
          productId: catalog.id,
          unitPrice: qty > 0 ? lineTotal / qty : catalog.unitPrice,
          qty: qty,
          courseNumber: courseForLineIndex(i),
        ),
      );
    }
    return rebuilt;
  }
}
