import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_endpoints.dart';
import '../../models/session_order.dart';
import '../../models/order_display_entry.dart';
import '../models/create_table_order_result.dart';
import '../models/local_draft_line.dart';
import '../../services/connectivity_service.dart';
import '../datasources/order_local_datasource.dart';
import '../datasources/order_remote_datasource.dart';
import '../datasources/session_datasource.dart';
import '../../utils/api_log.dart';
import '../mappers/order_mapper.dart';
import '../models/catalog/catalog_product_model.dart';
import 'catalog_repository.dart';
import '../mappers/menu_mapper.dart';
import '../order_optimistic_sync.dart';

/// One simple product line for a batched seat-order items POST.
class SimpleProductBatchLine {
  const SimpleProductBatchLine({
    required this.productId,
    required this.unitPrice,
    this.qty = 1,
    this.comment = '',
  });

  final int productId;
  final double unitPrice;
  final int qty;
  final String comment;
}

class OrderRepository {
  OrderRepository({
    required OrderRemoteDataSource remote,
    required OrderLocalDataSource local,
    required SessionRemoteDataSource sessionRemote,
    required SessionLocalDataSource sessionLocal,
    required ConnectivityService connectivity,
    required CatalogRepository catalog,
  })  : _remote = remote,
        _local = local,
        _sessionRemote = sessionRemote,
        _sessionLocal = sessionLocal,
        _connectivity = connectivity,
        _catalog = catalog;

  final OrderRemoteDataSource _remote;
  final OrderLocalDataSource _local;
  final SessionRemoteDataSource _sessionRemote;
  final SessionLocalDataSource _sessionLocal;
  final ConnectivityService _connectivity;
  final CatalogRepository _catalog;

  /// Orders intentionally emptied in UI after delete-all.
  final Set<int> _emptyShellDisplayOrderIds = <int>{};

  /// Item ids the waiter deleted locally — background GET/enrich must not
  /// resurrect them until cancel is confirmed (or undo restores them).
  final Map<int, Set<int>> _suppressedItemIdsByOrderId = <int, Set<int>>{};

  /// Orders with a local delete still in the undo / cancel window. Blocks
  /// background enrich from adopting a fatter API snapshot.
  final Set<int> _pendingLocalDeleteOrderIds = <int>{};

  /// Monotonic local detail revision. Background enrich that started before a
  /// qty/add mutation must discard its result when this bumps mid-flight.
  final Map<int, int> _detailRevisionByOrderId = <int, int>{};

  /// Last create-order debug trace (for on-screen error/success dialog).
  String? lastCreateOrderLog;

  /// Last add-item debug trace.
  String? lastAddItemLog;

  /// Last payment debug trace.
  String? lastPaymentLog;

  /// Last payment-modes fetch debug trace.
  String? lastPaymentModesLog;

  /// Last ticket/receipt print debug trace.
  String? lastPrintLog;

  /// Last kitchen send (requestCourses) debug trace.
  String? lastKitchenSendLog;

  List<Map<String, dynamic>> _cachedPaymentModes = [];

  /// One background-sync queue per order (shared by session + table details).
  final Map<int, OrderOptimisticSync> _optimisticSyncByKey = {};

  OrderOptimisticSync optimisticSyncFor(int syncKey) {
    return _optimisticSyncByKey.putIfAbsent(syncKey, OrderOptimisticSync.new);
  }

  /// Returns order detail mapped to [SessionOrder], using cache when offline.
  Map<String, dynamic>? cachedOrderDetail(int orderId) {
    if (orderId <= 0) return null;
    return _local.readOrderDetail(orderId);
  }

  /// Builds a session order from local detail + Hive suivre hints (no network).
  SessionOrder? cachedSessionOrder(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
    bool applyKitchenDemande = false,
  }) {
    if (orderId <= 0) return null;
    final cached = _local.readOrderDetail(orderId);
    if (cached == null) return null;

    final layoutHints =
        OrderMapper.coalesceLayoutHints(previousDisplayEntries);
    final suivreHints = _resolveSuivreHints(orderId, layoutHints: layoutHints);
    return OrderMapper.fromOrderDetail(
      cached,
      previousDisplayEntries: layoutHints,
      suivreSplitHints: suivreHints.splits,
      suivreCountHint: suivreHints.count,
      demandedSectionIndices: suivreHints.demandedSections,
      applyKitchenDemande: applyKitchenDemande,
    );
  }

  /// Recovery fetch — shows API detail without stripping lines.
  Future<SessionOrder> openAsEmptyTableOrder(int orderId) async {
    final detail = await _remote.fetchOrderDetail(orderId);
    if (OrderMapper.isOrderClosedOrCancelled(detail)) {
      throw ApiException(message: 'Commande fermée ou introuvable.');
    }
    await _local.saveOrderDetail(orderId, detail);
    await _sessionLocal.upsertOpenOrderInList(detail);
    return OrderMapper.fromOrderDetail(detail).copyWith(id: orderId);
  }

  Future<SessionOrder> getOrderDetail(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
    bool applyKitchenDemande = false,
  }) async {
    final online = await _connectivity.isOnline;

    if (online) {
      final detail = await _remote.fetchOrderDetail(orderId);

      await _local.saveOrderDetail(orderId, detail);

      // Empty [] from lightweight session rows must not wipe Hive suivre hints.
      final layoutHints =
          OrderMapper.coalesceLayoutHints(previousDisplayEntries);
      final suivreHints = _resolveSuivreHints(orderId, layoutHints: layoutHints);

      final order = OrderMapper.fromOrderDetail(
        detail,
        previousDisplayEntries: layoutHints,
        suivreSplitHints: suivreHints.splits,
        suivreCountHint: suivreHints.count,
        demandedSectionIndices: suivreHints.demandedSections,
        applyKitchenDemande: applyKitchenDemande,
      );

      await _persistSuivreLayoutHints(orderId, order.displayEntries);
      return order;
    }

    final cached = _local.readOrderDetail(orderId);
    if (cached != null) {
      final layoutHints =
          OrderMapper.coalesceLayoutHints(previousDisplayEntries);
      final suivreHints = _resolveSuivreHints(orderId, layoutHints: layoutHints);
      return OrderMapper.fromOrderDetail(
        cached,
        previousDisplayEntries: layoutHints,
        suivreSplitHints: suivreHints.splits,
        suivreCountHint: suivreHints.count,
        demandedSectionIndices: suivreHints.demandedSections,
        applyKitchenDemande: applyKitchenDemande,
      );
    }

    throw ApiException(
      message: 'Détails de commande indisponibles hors ligne.',
    );
  }

  /// True while the ticket was intentionally emptied (delete-all), not create.
  bool shouldDisplayAsEmptyCreateShell(int orderId) =>
      orderId > 0 && _emptyShellDisplayOrderIds.contains(orderId);

  /// Clear empty-shell UI lock once the ticket has real lines again.
  void clearEmptyShellDisplay(int orderId) => _forgetEmptyShellDisplay(orderId);

  /// Mark ticket empty after delete-all so stale GETs do not refill lines.
  void rememberEmptyShellDisplay(int orderId) =>
      _rememberEmptyShellDisplay(orderId);

  /// Suppress deleted line ids so stale GETs cannot flash them back.
  void suppressOrderItemIds(int orderId, Iterable<int> itemIds) {
    if (orderId <= 0) return;
    _pendingLocalDeleteOrderIds.add(orderId);
    final next =
        _suppressedItemIdsByOrderId.putIfAbsent(orderId, () => <int>{});
    for (final id in itemIds) {
      if (id > 0) next.add(id);
    }
  }

  /// Mark a local delete in flight even when the line has no stable item id yet.
  void markPendingLocalDelete(int orderId) {
    if (orderId > 0) _pendingLocalDeleteOrderIds.add(orderId);
  }

  /// Clear the in-flight delete flag without dropping suppressed item ids.
  void clearPendingLocalDeleteFlag(int orderId) {
    if (orderId > 0) _pendingLocalDeleteOrderIds.remove(orderId);
  }

  /// Drop suppress for one item (undo) or all items on an order.
  void clearSuppressedOrderItemIds(int orderId, {int? itemId}) {
    if (orderId <= 0) return;
    if (itemId != null) {
      final set = _suppressedItemIdsByOrderId[orderId];
      if (set != null) {
        set.remove(itemId);
        if (set.isEmpty) {
          _suppressedItemIdsByOrderId.remove(orderId);
        }
      }
      if (!_suppressedItemIdsByOrderId.containsKey(orderId)) {
        _pendingLocalDeleteOrderIds.remove(orderId);
      }
      return;
    }
    _suppressedItemIdsByOrderId.remove(orderId);
    _pendingLocalDeleteOrderIds.remove(orderId);
  }

  /// Item ids currently suppressed for [orderId] (delete undo / cancel in flight).
  Set<int> suppressedItemIdsFor(int orderId) {
    if (orderId <= 0) return const {};
    final set = _suppressedItemIdsByOrderId[orderId];
    if (set == null || set.isEmpty) return const {};
    return Set<int>.from(set);
  }

  /// True while a local line delete has not been confirmed/undone yet.
  bool hasPendingLocalDelete(int orderId) =>
      orderId > 0 && _pendingLocalDeleteOrderIds.contains(orderId);

  /// Current local detail revision for [orderId] (0 if never bumped).
  int detailRevision(int orderId) =>
      orderId > 0 ? (_detailRevisionByOrderId[orderId] ?? 0) : 0;

  /// Call before/after local ticket mutations so stale background GETs drop.
  int bumpDetailRevision(int orderId) {
    if (orderId <= 0) return 0;
    final next = detailRevision(orderId) + 1;
    _detailRevisionByOrderId[orderId] = next;
    return next;
  }

  void _rememberEmptyShellDisplay(int orderId) {
    if (orderId > 0) _emptyShellDisplayOrderIds.add(orderId);
  }

  void _forgetEmptyShellDisplay(int orderId) {
    _emptyShellDisplayOrderIds.remove(orderId);
  }

  bool _needsEmptyShellRevive(
    Map<String, dynamic> detail, {
    required bool expectEmptyShell,
  }) {
    return expectEmptyShell ||
        OrderMapper.orderDetailHasNoVisibleItems(detail) ||
        OrderMapper.shouldRecreateOrderForAdd(detail);
  }

  Future<void> persistSuivreSplitHint(int orderId, List<int> splitPositions) async {
    if (orderId <= 0) return;
    await _local.saveSuivreSplitHint(orderId, splitPositions);
  }

  Future<void> persistSuivreLayoutHints(
    int orderId,
    List<OrderDisplayEntry> displayEntries,
  ) async {
    if (orderId <= 0) return;
    await _persistSuivreLayoutHints(orderId, displayEntries);
  }

  Future<void> _persistSuivreLayoutHints(
    int orderId,
    List<OrderDisplayEntry> displayEntries,
  ) async {
    final splits = OrderMapper.suivreSplitPositions(displayEntries);
    final count = OrderMapper.sectionDividerCount(displayEntries);
    final demanded = OrderMapper.demandedSectionIndicesFromEntries(displayEntries);
    await _local.saveSuivreSplitHint(orderId, splits);
    await _local.saveSuivreCountHint(orderId, count);
    await _local.saveDemandedSectionHint(orderId, demanded);
  }

  Future<void> closeOrder(
    int orderId, {
    String? tableNumber,
    String? cancelToWhom,
    String? cancelNote,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final tableId = await _resolveTableIdForClose(
      orderId: orderId,
      tableNumber: tableNumber,
    );

    if (orderId > 0) {
      final toWhom = cancelToWhom?.trim();
      final note = cancelNote?.trim();
      if ((toWhom != null && toWhom.isNotEmpty) ||
          (note != null && note.isNotEmpty)) {
        logOrderFlow(
          'CLOSE order=$orderId'
          '${toWhom != null && toWhom.isNotEmpty ? ' toWhom="$toWhom"' : ''}'
          '${note != null && note.isNotEmpty ? ' note="$note"' : ''}',
        );
      }
      await _remote.closeOrder(orderId);
      await _local.removeOrderDetail(orderId);
      await _sessionLocal.removeOpenOrderFromList(orderId);
    }

    // Session release is best-effort: the order is already closed. Backend may
    // return "not allowed to release this table" even when delete succeeded.
    if (tableId != null && tableId > 0) {
      try {
        await _remote.endTableSession(tableId);
      } on ApiException {
        if (orderId <= 0) rethrow;
      } catch (_) {
        if (orderId <= 0) rethrow;
      }
    }
  }

  Future<void> endTableSession(int tableId) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    await _remote.endTableSession(tableId);
  }

  /// Ends a leftover table lock/session with no active order (best-effort).
  Future<void> _clearOrphanTableSession(
    int tableId, {
    required StringBuffer apiLog,
  }) async {
    logOrderFlow('CLEAR orphan session tableId=$tableId');
    apiLog.writeln('── CLEAR orphan session /api/tables/$tableId/session ──');
    try {
      await _remote.endTableSession(tableId);
      apiLog.writeln('── Orphan session cleared ──');
    } on ApiException catch (error) {
      apiLog.writeln('── Clear orphan session: ${error.message} ──');
      if (OrderMapper.isTableOwnershipDeniedMessage(error.message)) {
        rethrow;
      }
      final message = error.message.toLowerCase();
      if (!message.contains('session') &&
          !message.contains('404') &&
          !message.contains('not found') &&
          !message.contains('disponible')) {
        rethrow;
      }
    }
  }

  Future<int?> _resolveTableIdForClose({
    required int orderId,
    String? tableNumber,
  }) async {
    if (orderId < 0) return -orderId;

    if (orderId > 0) {
      try {
        final detail = await _remote.fetchOrderDetail(orderId);
        final tableId = (detail['table_id'] as num?)?.toInt();
        if (tableId != null && tableId > 0) return tableId;
      } catch (_) {}
    }

    if (tableNumber == null || tableNumber.isEmpty) return null;

    try {
      final tables = await _sessionRemote.fetchTablesList();
      final normalized = OrderMapper.normalizeTableKey(tableNumber);
      return OrderMapper.resolveTableId(tables, normalized) ??
          OrderMapper.resolveTableId(
            tables,
            OrderMapper.tableDisplayNumber(normalized),
          );
    } catch (_) {
      return null;
    }
  }

  Future<SessionOrder> applyTableOffer(int orderId) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Offre impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final detail = await _remote.fetchOrderDetail(orderId);
    final payload = OrderMapper.applyTableOffer(detail);
    final updated = await _remote.updateOrder(orderId, payload);
    await _local.saveOrderDetail(orderId, updated);
    return OrderMapper.fromOrderDetail(updated);
  }

  /// Updates couverts via PUT /api/orders/:id and returns the mapped order.
  Future<SessionOrder> updateOrderGuestCount({
    required int orderId,
    required int numberOfGuests,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Modification impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final detail = await _remote.fetchOrderDetail(orderId);
    final payload = OrderMapper.buildUpdateGuestCountPayload(
      detail,
      numberOfGuests: numberOfGuests,
    );
    final updated = await _remote.updateOrder(orderId, payload);
    await _local.saveOrderDetail(orderId, updated);
    await _sessionLocal.upsertOpenOrderInList(updated);
    return OrderMapper.fromOrderDetail(updated);
  }

  Future<CreateTableOrderResult> createTableOrder({
    required int waiterId,
    required String tableNumber,
    required int numberOfGuests,
    int? salesZoneId,
    String? waiterName,
  }) async {
    logOrderFlow(
      'createTableOrder START table=$tableNumber guests=$numberOfGuests waiter=$waiterId',
    );
    final apiLog = StringBuffer();

    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Création impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final parsedTableNumber =
        OrderMapper.parseTableNumberForOpenByNumber(tableNumber);
    if (parsedTableNumber == null || parsedTableNumber < 1) {
      throw ApiException(message: 'Numéro de table invalide.');
    }

    final openPayload = OrderMapper.buildOpenTableByNumberPayload(
      tableNumber: parsedTableNumber,
      numberOfGuests: numberOfGuests,
      waiterId: waiterId,
      waiterName: waiterName,
      salesZoneId: salesZoneId,
    );

    apiLog
      ..writeln()
      ..writeln('── POST /api/tables/open-by-number ──')
      ..writeln(formatApiPayload(openPayload));

    ResolvedTable table;
    try {
      logOrderFlow('POST /api/tables/open-by-number START table=$parsedTableNumber');
      final tableData = await _sessionRemote.openTableByNumber(openPayload);
      table = OrderMapper.resolvedTableFromPayload(tableData);
      logOrderFlow(
        'POST /api/tables/open-by-number OK tableId=${table.id} '
        'number=${table.tableNumber}',
      );
      apiLog.writeln(
        '── open-by-number OK id=${table.id} number=${table.tableNumber} '
        'status=${table.status ?? '—'} activeOrder=${table.existingOrderId ?? '—'}',
      );
    } on ApiException catch (error) {
      logOrderFlow(
        'POST /api/tables/open-by-number FAILED: ${error.message}'
        '${error.statusCode != null ? ' (HTTP ${error.statusCode})' : ''}',
      );
      apiLog.writeln('── open-by-number failed: ${error.message} ──');
      if (error.statusCode == 409) {
        final activeOrderId =
            OrderMapper.activeOrderIdFromConflictBody(error.responseBody);
        if (activeOrderId != null && activeOrderId > 0) {
          apiLog.writeln(
            '── open-by-number 409 resume active_order=$activeOrderId ──',
          );
          final conflictTable = OrderMapper.resolvedTableFromConflictBody(
                error.responseBody,
                fallbackTableNumber: parsedTableNumber,
              ) ??
              ResolvedTable(
                id: 0,
                tableNumber: parsedTableNumber,
              );
          return _resumeExistingOrderForTableCreate(
            orderId: activeOrderId,
            table: conflictTable,
            tableNumber: tableNumber,
            apiLog: apiLog,
          );
        }
      }
      rethrow;
    }

    if (table.hasActiveOrder && table.existingOrderId != null) {
      apiLog.writeln(
        '── open-by-number returned active_order=${table.existingOrderId} ──',
      );
      return _resumeExistingOrderForTableCreate(
        orderId: table.existingOrderId!,
        table: table,
        tableNumber: tableNumber,
        apiLog: apiLog,
      );
    }

    final resolvedSalesZoneId = salesZoneId != null && salesZoneId > 0
        ? salesZoneId
        : table.salesZoneId;

    apiLog.writeln(
      'Table ouverte: id=${table.id}, numéro=${table.tableNumber}, '
      'sales_zone_id=${resolvedSalesZoneId ?? '—'}',
    );

    final seedFuture = _catalog.resolveSeedProductForEmptyOrder();

    // open-by-number already started the session — do not POST /tables/{id}/session.
    final createdPayload = await _postCreateEmptyOrderRecord(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      salesZoneId: resolvedSalesZoneId,
      apiLog: apiLog,
      seed: await seedFuture,
    );

    final orderId = createdPayload == null
        ? null
        : OrderMapper.extractOrderIdFromPayload(createdPayload);
    if (orderId == null || orderId <= 0) {
      lastCreateOrderLog = apiLog.toString();
      throw ApiException(
        message: 'Impossible de créer la commande sur la table $tableNumber.',
      );
    }

    // Persist and display full API detail (POST body may omit nested lines).
    var detail = OrderMapper.unwrapOrderDetail(createdPayload!);
    detail = <String, dynamic>{
      ...detail,
      'id': orderId,
      'table_id': table.id,
      'table_number': table.tableNumber,
    };

    try {
      detail = await _remote.fetchOrderDetail(orderId);
      apiLog.writeln('── GET /api/orders/$orderId après create ──');
    } catch (e) {
      apiLog.writeln('── GET detail après create échoué: $e — POST utilisé ──');
    }

    await _local.saveOrderDetail(orderId, detail);
    await _sessionLocal.upsertOpenOrderInList(detail);

    final displayNumber = OrderMapper.displayKey(
      orderId: orderId,
      tableNumber: table.tableNumber,
    );
    final order = OrderMapper.fromOrderDetail(detail).copyWith(
      id: orderId,
      number: displayNumber,
    );

    apiLog
      ..writeln()
      ..writeln('── Résultat final ──')
      ..writeln(
        'POST /api/orders OK id=$orderId, affichage=${order.number}, '
        'items=${order.itemCount}',
      );

    lastCreateOrderLog = apiLog.toString();
    logOrderFlow(
      'createTableOrder END orderId=$orderId table=$tableNumber '
      'items=${order.itemCount}',
    );
    return CreateTableOrderResult(order: order, apiLog: apiLog.toString());
  }

  /// Opens the table, POSTs /api/orders with draft lines (no seed), then sends.
  Future<SessionOrder> createAndSendLocalDraft({
    required String tableNumber,
    required int numberOfGuests,
    required int waiterId,
    required List<LocalDraftLine> lines,
    int? salesZoneId,
    String? waiterName,
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    if (lines.isEmpty) {
      throw ApiException(
        message: 'Ajoutez au moins un article avant l\'envoi.',
      );
    }
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Envoi impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final apiLog = StringBuffer()
      ..writeln('── Create + send local draft ──')
      ..writeln('table=$tableNumber lines=${lines.length}');
    lastCreateOrderLog = apiLog.toString();

    final table = await _openTableByNumberForCreate(
      tableNumber: tableNumber,
      numberOfGuests: numberOfGuests,
      waiterId: waiterId,
      waiterName: waiterName,
      salesZoneId: salesZoneId,
      apiLog: apiLog,
    );

    final createPayload = OrderMapper.buildCreateOrderFromDraftLines(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      tableId: table.id,
      salesZoneId: salesZoneId ?? table.salesZoneId,
      lines: lines,
    );

    apiLog.writeln('── POST /api/orders (local draft items) ──');
    apiLog.writeln(formatApiPayload(createPayload));
    logOrderFlow(
      'POST /api/orders local draft table=${table.tableNumber} '
      'items=${lines.length}',
    );

    final createdPayload = await _tryPostCreateOrder(
      payload: createPayload,
      label: 'local-draft',
      apiLog: apiLog,
    );
    if (createdPayload == null) {
      lastCreateOrderLog = apiLog.toString();
      throw ApiException(
        message: 'Impossible de créer la commande sur la table $tableNumber.',
      );
    }

    final orderId = OrderMapper.extractOrderIdFromPayload(createdPayload);
    if (orderId == null || orderId <= 0) {
      lastCreateOrderLog = apiLog.toString();
      throw ApiException(
        message: 'Impossible de créer la commande sur la table $tableNumber.',
      );
    }

    var detail = OrderMapper.unwrapOrderDetail(createdPayload);
    detail = <String, dynamic>{
      ...detail,
      'id': orderId,
      'table_id': table.id,
      'table_number': table.tableNumber,
    };

    try {
      detail = await _remote.fetchOrderDetail(orderId);
      apiLog.writeln('── GET /api/orders/$orderId après create draft ──');
    } catch (e) {
      apiLog.writeln('── GET detail après create draft échoué: $e ──');
    }

    await _local.saveOrderDetail(orderId, detail);
    await _sessionLocal.upsertOpenOrderInList(detail);
    lastCreateOrderLog = apiLog.toString();

    final sent = await requestAllCourses(
      orderId,
      previousDisplayEntries: previousDisplayEntries,
    );

    return sent.copyWith(
      id: orderId,
      number: OrderMapper.displayKey(
        orderId: orderId,
        tableNumber: table.tableNumber,
      ),
    );
  }

  Future<ResolvedTable> _openTableByNumberForCreate({
    required String tableNumber,
    required int numberOfGuests,
    required int waiterId,
    String? waiterName,
    int? salesZoneId,
    required StringBuffer apiLog,
  }) async {
    final parsedTableNumber =
        OrderMapper.parseTableNumberForOpenByNumber(tableNumber);
    if (parsedTableNumber == null || parsedTableNumber < 1) {
      throw ApiException(message: 'Numéro de table invalide.');
    }

    final openPayload = OrderMapper.buildOpenTableByNumberPayload(
      tableNumber: parsedTableNumber,
      numberOfGuests: numberOfGuests,
      waiterId: waiterId,
      waiterName: waiterName,
      salesZoneId: salesZoneId,
    );

    apiLog
      ..writeln()
      ..writeln('── POST /api/tables/open-by-number ──')
      ..writeln(formatApiPayload(openPayload));

    try {
      logOrderFlow('POST /api/tables/open-by-number START table=$parsedTableNumber');
      final tableData = await _sessionRemote.openTableByNumber(openPayload);
      final table = OrderMapper.resolvedTableFromPayload(tableData);
      logOrderFlow(
        'POST /api/tables/open-by-number OK tableId=${table.id} '
        'number=${table.tableNumber}',
      );
      return table;
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        final activeOrderId =
            OrderMapper.activeOrderIdFromConflictBody(error.responseBody);
        if (activeOrderId != null && activeOrderId > 0) {
          apiLog.writeln(
            '── open-by-number 409 resume active_order=$activeOrderId ──',
          );
          final conflictTable = OrderMapper.resolvedTableFromConflictBody(
                error.responseBody,
                fallbackTableNumber: parsedTableNumber,
              ) ??
              ResolvedTable(
                id: 0,
                tableNumber: parsedTableNumber,
              );
          return conflictTable;
        }
      }
      rethrow;
    }
  }

  Future<CreateTableOrderResult> _resumeExistingOrderForTableCreate({
    required int orderId,
    required ResolvedTable table,
    required String tableNumber,
    required StringBuffer apiLog,
  }) async {
    try {
      final detail = await _remote.fetchOrderDetail(orderId);
      if (OrderMapper.isOrderClosedOrCancelled(detail)) {
        await _local.removeOrderDetail(orderId);
        await _sessionLocal.removeOpenOrderFromList(orderId);
        lastCreateOrderLog = apiLog.toString();
        throw ApiException(
          message: 'La commande active sur la table $tableNumber est fermée.',
        );
      }

      final tableNumberForDisplay = table.tableNumber > 0
          ? table.tableNumber
          : (OrderMapper.parseTableNumberForOpenByNumber(tableNumber) ?? 0);

      await _local.saveOrderDetail(orderId, detail);
      await _sessionLocal.upsertOpenOrderInList(detail);
      final displayNumber = OrderMapper.displayKey(
        orderId: orderId,
        tableNumber: tableNumberForDisplay,
      );
      final mapped = OrderMapper.fromOrderDetail(detail).copyWith(
        id: orderId,
        number: displayNumber,
      );
      lastCreateOrderLog = apiLog.toString();
      logOrderFlow(
        'createTableOrder RESUME orderId=$orderId table=$tableNumber '
        'items=${mapped.itemCount}',
      );
      return CreateTableOrderResult(
        order: mapped,
        apiLog: apiLog.toString(),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      apiLog.writeln('── Resume active_order failed: $e ──');
      lastCreateOrderLog = apiLog.toString();
      rethrow;
    }
  }

  /// Creates a remote open order via POST /api/orders (response shown as-is in UI).
  Future<Map<String, dynamic>?> _postCreateEmptyOrderRecord({
    required ResolvedTable table,
    required int waiterId,
    required int numberOfGuests,
    required int? salesZoneId,
    required StringBuffer apiLog,
    CatalogProductModel? seed,
  }) async {
    seed ??= await _catalog.resolveSeedProductForEmptyOrder();
    if (seed == null) {
      apiLog.writeln(
        '── Aucun produit simple pour seed POST /api/orders ──',
      );
      logOrderFlow('POST /api/orders ABORT no seed product');
      return null;
    }

    apiLog.writeln(
      '── POST placeholder id=${seed.id} "${seed.name}" (API response is source of truth) ──',
    );

    final menuSelections = MenuMapper.defaultMenuSelectionsForProduct(seed);
    final lineSubTotal =
        seed.unitPrice + MenuMapper.menuSelectionsSupplement(menuSelections);

    final withItem = OrderMapper.buildCreateOrderWithItemPayload(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      productId: seed.id,
      unitPrice: lineSubTotal,
      tableId: table.id,
      salesZoneId: salesZoneId,
      qty: 1,
      status: 'to_be_continued',
      comment: '',
      menuSelections: menuSelections,
    );
    return _tryPostCreateOrder(
      payload: withItem,
      label: 'seed-item id:0',
      apiLog: apiLog,
    );
  }

  Future<Map<String, dynamic>?> _tryPostCreateOrder({
    required Map<String, dynamic> payload,
    required String label,
    required StringBuffer apiLog,
  }) async {
    apiLog
      ..writeln()
      ..writeln('── POST /api/orders ($label) ──')
      ..writeln(formatApiPayload(payload));

    logOrderFlow('POST /api/orders ($label)');
    _remote.lastApiLog = null;
    try {
      final created = await _remote.createOrder(payload);
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      final orderId = OrderMapper.extractOrderIdFromPayload(created);
      if (orderId != null && orderId > 0) {
        apiLog.writeln('── Commande créée: $orderId ──');
        logOrderFlow('POST /api/orders OK ($label) orderId=$orderId');
        return created;
      }
      apiLog.writeln('── Réponse POST sans order id ──');
    } on ApiException catch (error) {
      apiLog.writeln('── POST /api/orders ($label) échoué: ${error.message} ──');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      logOrderFlow('POST /api/orders FAILED ($label): ${error.message}');
    }
    return null;
  }

  /// When POST returned an error but the backend may have created the order.
  Future<CreateTableOrderResult?> tryRecoverCreatedOrder({
    required String tableNumber,
  }) async {
    if (!await _connectivity.isOnline) return null;

    try {
      final tables = await _sessionRemote.fetchTablesList();
      final normalized = OrderMapper.normalizeTableKey(tableNumber);
      final table = OrderMapper.resolveTable(tables, normalized) ??
          OrderMapper.resolveTable(
            tables,
            OrderMapper.tableDisplayNumber(normalized),
          );
      if (table == null) return null;

      final orderId = table.existingOrderId ??
          await _resolveOrderIdForTable(
            tableId: table.id,
            tableNumber: table.tableNumber,
            initialTables: tables,
            maxAttempts: 2,
          );
      if (orderId == null || orderId <= 0) return null;

      var detail = await _remote.fetchOrderDetail(orderId);
      if (OrderMapper.isOrderClosedOrCancelled(detail)) {
        await _local.removeOrderDetail(orderId);
        await _sessionLocal.removeOpenOrderFromList(orderId);
        return null;
      }

      await _local.saveOrderDetail(orderId, detail);
      await _sessionLocal.upsertOpenOrderInList(detail);
      return CreateTableOrderResult(
        order: OrderMapper.fromOrderDetail(detail).copyWith(id: orderId),
        apiLog: '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _tryStartTableSession({
    required ResolvedTable table,
    required int waiterId,
    required int numberOfGuests,
    required StringBuffer apiLog,
  }) async {
    logOrderFlow('POST /api/tables/${table.id}/session START');
    final sessionPayload = OrderMapper.buildStartTableSessionPayload(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
    );

    apiLog
      ..writeln()
      ..writeln('── POST /api/tables/${table.id}/session payload ──')
      ..writeln(formatApiPayload(sessionPayload));

    _remote.lastApiLog = null;
    try {
      await _remote.startTableSession(table.id, sessionPayload);
      logOrderFlow('POST /api/tables/${table.id}/session OK');
      apiLog.writeln('── Via POST /api/tables/${table.id}/session ──');
    } on ApiException catch (sessionError) {
      logOrderFlow(
        'POST /api/tables/${table.id}/session FAILED: ${sessionError.message}',
      );
      apiLog.writeln('── POST /api/tables/${table.id}/session échoué ──');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      apiLog.writeln('Raison: ${sessionError.message}');
      // Other waiter's table — surface so UI can show Skip dialog.
      if (OrderMapper.isTableOwnershipDeniedMessage(sessionError.message)) {
        rethrow;
      }
    }

    if (_remote.lastApiLog != null) {
      apiLog.writeln(_remote.lastApiLog);
    }
  }

  /// Finds the active order id for a table display key (e.g. `T5` or `5`).
  Future<int?> resolveOrderIdForTableNumber(String tableNumber) async {
    if (!await _connectivity.isOnline) return null;

    try {
      final tables = await _sessionRemote.fetchTablesList();
      final normalized = OrderMapper.normalizeTableKey(tableNumber);
      final table = OrderMapper.resolveTable(tables, normalized) ??
          OrderMapper.resolveTable(
            tables,
            OrderMapper.tableDisplayNumber(normalized),
          );
      if (table == null) return null;

      return _resolveOrderIdForTable(
        tableId: table.id,
        tableNumber: table.tableNumber,
        initialTables: tables,
        maxAttempts: 2,
      );
    } catch (_) {
      return null;
    }
  }

  /// Creates a real order with the first simple product when only a session exists.
  Future<SessionOrder> createOrderWithFirstSimpleProduct({
    required String tableNumber,
    required int waiterId,
    required int productId,
    required double unitPrice,
    int qty = 1,
    String comment = '',
    int? numberOfGuests,
  }) async {
    logOrderFlow(
      'createOrderWithFirstSimpleProduct START table=$tableNumber product=$productId waiter=$waiterId',
    );
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Création impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final tables = await _sessionRemote.fetchTablesList();
    final normalized = OrderMapper.normalizeTableKey(tableNumber);
    final table = OrderMapper.resolveTable(tables, normalized) ??
        OrderMapper.resolveTable(
          tables,
          OrderMapper.tableDisplayNumber(normalized),
        );
    if (table == null) {
      throw ApiException(message: 'Table introuvable.');
    }

    final guests = numberOfGuests != null && numberOfGuests > 0
        ? numberOfGuests
        : OrderMapper.guestsForTable(tables, table.id);
    final salesZoneId = OrderMapper.inferSalesZoneId(tables, table: table);
    final payload = OrderMapper.buildCreateOrderWithItemPayload(
      waiterId: waiterId,
      numberOfGuests: guests,
      productId: productId,
      unitPrice: unitPrice,
      tableId: table.id,
      salesZoneId: salesZoneId,
      qty: qty,
      comment: comment,
    );

    if (kDebugMode) {
      print('ORDER POST: createOrderWithFirstSimpleProduct table=$tableNumber');
    }
    logOrderFlow('createOrderWithFirstSimpleProduct → POST /api/orders');
    final created = await _remote.createOrder(payload);
    var orderId = OrderMapper.extractOrderIdFromPayload(created);
    orderId ??= await _resolveOrderIdForTable(
      tableId: table.id,
      tableNumber: table.tableNumber,
      initialTables: tables,
      maxAttempts: 2,
    );
    if (orderId == null || orderId <= 0) {
      throw ApiException(
        message: 'Impossible de créer la commande avec cet article.',
      );
    }

    final detail = OrderMapper.orderIdFromDetail(
              OrderMapper.unwrapOrderDetail(created),
            ) ==
            orderId
        ? OrderMapper.unwrapOrderDetail(created)
        : await _remote.fetchOrderDetail(orderId);

    await _local.saveOrderDetail(orderId, detail);
    await _sessionLocal.upsertOpenOrderInList(detail);

    return OrderMapper.fromOrderDetail(detail).copyWith(
      id: orderId,
    );
  }

  /// Creates a real order with the first composed product when only a session exists.
  Future<SessionOrder> createOrderWithFirstComposedProduct({
    required String tableNumber,
    required int waiterId,
    required int productId,
    required double basePrice,
    required List<Map<String, dynamic>> menuSelections,
    String comment = '',
    int? numberOfGuests,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Création impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final tables = await _sessionRemote.fetchTablesList();
    final normalized = OrderMapper.normalizeTableKey(tableNumber);
    final table = OrderMapper.resolveTable(tables, normalized) ??
        OrderMapper.resolveTable(
          tables,
          OrderMapper.tableDisplayNumber(normalized),
        );
    if (table == null) {
      throw ApiException(message: 'Table introuvable.');
    }

    final supplement = menuSelections.fold<double>(
      0,
      (sum, selection) {
        final price = selection['price'];
        if (price is num) return sum + price.toDouble();
        return sum +
            (double.tryParse(price?.toString().replaceAll(',', '.') ?? '') ??
                0);
      },
    );

    final guests = numberOfGuests != null && numberOfGuests > 0
        ? numberOfGuests
        : OrderMapper.guestsForTable(tables, table.id);
    final salesZoneId = OrderMapper.inferSalesZoneId(tables, table: table);
    final payload = OrderMapper.buildCreateOrderWithItemPayload(
      waiterId: waiterId,
      numberOfGuests: guests,
      productId: productId,
      unitPrice: basePrice + supplement,
      tableId: table.id,
      salesZoneId: salesZoneId,
      comment: comment,
      menuSelections: menuSelections,
    );

    final created = await _remote.createOrder(payload);
    var orderId = OrderMapper.extractOrderIdFromPayload(created);
    orderId ??= await _resolveOrderIdForTable(
      tableId: table.id,
      tableNumber: table.tableNumber,
      initialTables: tables,
      maxAttempts: 2,
    );
    if (orderId == null || orderId <= 0) {
      throw ApiException(
        message: 'Impossible de créer la commande avec cet article.',
      );
    }

    final detail = OrderMapper.orderIdFromDetail(
              OrderMapper.unwrapOrderDetail(created),
            ) ==
            orderId
        ? OrderMapper.unwrapOrderDetail(created)
        : await _remote.fetchOrderDetail(orderId);

    await _local.saveOrderDetail(orderId, detail);
    await _sessionLocal.upsertOpenOrderInList(detail);

    return OrderMapper.fromOrderDetail(detail).copyWith(
      id: orderId,
    );
  }

  Future<int?> _resolveOrderIdForTable({
    required int tableId,
    int? tableNumber,
    List<Map<String, dynamic>>? initialTables,
    int maxAttempts = 5,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }

      final tables = attempt == 0 && initialTables != null
          ? initialTables
          : await _sessionRemote.fetchTablesList();

      final orderId = OrderMapper.activeOrderIdForTableId(tables, tableId);
      if (orderId != null && orderId > 0) return orderId;

      if (tableNumber != null) {
        final orderId = OrderMapper.activeOrderIdForTableNumber(
          tables,
          '$tableNumber',
        );
        if (orderId != null && orderId > 0) return orderId;
      }
    }
    return null;
  }

  /// Reparent suite lines onto their API courses from waiter layout hints.
  Future<Map<String, dynamic>> _alignDetailToLayoutBeforeDemande({
    required int orderId,
    required Map<String, dynamic> detail,
    required List<OrderDisplayEntry> layout,
    StringBuffer? apiLog,
  }) async {
    if (layout.isEmpty) return detail;

    final aligned = OrderMapper.alignPendingSuivreLayoutOntoCourses(
      detail,
      layout: layout,
    );
    if (!aligned.changed) return detail;

    apiLog?.writeln('── Align suite layout onto courses (pre-Demande) ──');
    var working = await _putOrderUpdate(
      orderId: orderId,
      payload: OrderMapper.buildOrderUpdatePayload(aligned.detail),
      apiLog: apiLog ?? StringBuffer(),
    );
    await _local.saveOrderDetail(orderId, working);
    working = await _remote.fetchOrderDetail(orderId);
    await _local.saveOrderDetail(orderId, working);
    apiLog?.writeln(OrderMapper.describeCourseContents(working));
    return working;
  }

  void _assertSuivreSectionSyncedBeforeDemande({
    required Map<String, dynamic> detail,
    required List<OrderDisplayEntry> layout,
    required int sectionIndex,
    required int courseNumber,
  }) {
    final under = OrderMapper.productEntriesUnderSection(layout, sectionIndex);
    if (under.isEmpty) return;

    if (!OrderMapper.suiteItemsFullyOnCourse(
      detail,
      layout: layout,
      sectionIndex: sectionIndex,
      courseNumber: courseNumber,
    )) {
      throw ApiException(
        message:
            'Les articles de ce service ne sont pas encore enregistrés. '
            'Patientez une seconde puis réessayez.',
      );
    }
  }

  /// Align the next pending À SUIVRE onto a writable course before session Demande.
  Future<Map<String, dynamic>> _prepareDetailForSessionDemande({
    required int orderId,
    required Map<String, dynamic> detail,
    required List<OrderDisplayEntry> layout,
    required int sectionIndex,
  }) async {
    var working = await _alignDetailToLayoutBeforeDemande(
      orderId: orderId,
      detail: detail,
      layout: layout,
    );
    var preferred = sectionIndex + 1;
    for (final entry in layout) {
      if (entry.type != OrderDisplayEntryType.suivreSeparator) continue;
      if (entry.sectionIndex != sectionIndex) continue;
      final above = entry.courseNumber ?? sectionIndex;
      preferred = above > 0 ? above + 1 : sectionIndex + 1;
      break;
    }

    var targetCourse = OrderMapper.resolveWritableSuivreCourseNumber(
      working,
      preferredCourseNumber: preferred,
    );
    final under = OrderMapper.productEntriesUnderSection(layout, sectionIndex);
    final aligned = OrderMapper.suiteItemsFullyOnCourse(
      working,
      layout: layout,
      sectionIndex: sectionIndex,
      courseNumber: targetCourse,
    );
    if (under.isNotEmpty && aligned) return working;

    final catalogProducts = await _catalog.getProducts();
    CatalogProductModel? catalogByName(String name) {
      final needle = name.trim().toUpperCase();
      if (needle.isEmpty) return null;
      for (final product in catalogProducts) {
        if (product.name.trim().toUpperCase() == needle) return product;
      }
      return null;
    }

    final ensured = OrderMapper.ensureSuivreSectionOnCourse(
      working,
      layout: layout,
      sectionIndex: sectionIndex,
      targetCourseNumber: targetCourse,
      resolveProductId: (name) => catalogByName(name)?.id,
      resolveUnitPrice: (name) => catalogByName(name)?.unitPrice,
    );
    if (!ensured.changed) return working;

    final apiLog = StringBuffer();
    working = await _putOrderUpdate(
      orderId: orderId,
      payload: OrderMapper.buildOrderUpdatePayload(ensured.detail),
      apiLog: apiLog,
    );
    await _local.saveOrderDetail(orderId, working);
    working = await _remote.fetchOrderDetail(orderId);
    await _local.saveOrderDetail(orderId, working);
    return working;
  }

  Future<SessionOrder> requestNextCourses(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Demande impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final layoutHints = OrderMapper.coalesceLayoutHints(previousDisplayEntries);
    final demandSectionIndex = layoutHints == null
        ? null
        : OrderMapper.firstPendingSuivreSectionIndex(layoutHints);

    var detail = await _remote.fetchOrderDetail(orderId);
    if (layoutHints != null &&
        demandSectionIndex != null &&
        demandSectionIndex > 0) {
      detail = await _prepareDetailForSessionDemande(
        orderId: orderId,
        detail: detail,
        layout: layoutHints,
        sectionIndex: demandSectionIndex,
      );
    }

    final courseIds = OrderMapper.extractSingleNextCourseIdForDemande(
      detail,
      layout: layoutHints,
    );
    if (courseIds.isEmpty) {
      throw ApiException(message: 'Aucun service à demander pour cette table.');
    }

    if (layoutHints != null &&
        demandSectionIndex != null &&
        demandSectionIndex > 0) {
      var preferred = demandSectionIndex + 1;
      for (final entry in layoutHints) {
        if (entry.type != OrderDisplayEntryType.suivreSeparator) continue;
        if (entry.sectionIndex != demandSectionIndex) continue;
        final above = entry.courseNumber ?? demandSectionIndex;
        preferred = above > 0 ? above + 1 : demandSectionIndex + 1;
        break;
      }
      final targetCourse = OrderMapper.resolveWritableSuivreCourseNumber(
        detail,
        preferredCourseNumber: preferred,
      );
      _assertSuivreSectionSyncedBeforeDemande(
        detail: detail,
        layout: layoutHints,
        sectionIndex: demandSectionIndex,
        courseNumber: targetCourse,
      );
    }

    await _remote.requestCourses(orderId, courseIds);

    var order = await getOrderDetail(
      orderId,
      previousDisplayEntries: layoutHints,
      applyKitchenDemande: true,
    );

    // Flip only the one section the waiter demanded — not every À SUIVRE row.
    if (layoutHints != null &&
        demandSectionIndex != null &&
        demandSectionIndex > 0) {
      final timeLabel = OrderMapper.formatDemandeTime(
            DateTime.now().toUtc().toIso8601String(),
          ) ??
          '--:--:--';
      order = OrderMapper.rebuildOrderAfterSuivreDemande(
        serverOrder: order,
        liveLayout: layoutHints,
        suivreSectionIndex: demandSectionIndex,
        demandeTimeLabel: timeLabel,
      );
      await _persistSuivreLayoutHints(orderId, order.displayEntries);
    }

    return order;
  }

  Future<SessionOrder> requestCourseForSuivreSection(
    int orderId, {
    required int courseNumber,
    List<OrderDisplayEntry>? previousDisplayEntries,
    int? suivreSectionIndex,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Demande impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final apiLog = StringBuffer('── Demande À SUIVRE course=$courseNumber ──\n');
    var detail = await _remote.fetchOrderDetail(orderId);
    if (previousDisplayEntries != null &&
        previousDisplayEntries.isNotEmpty) {
      detail = await _alignDetailToLayoutBeforeDemande(
        orderId: orderId,
        detail: detail,
        layout: previousDisplayEntries,
        apiLog: apiLog,
      );
    }
    apiLog.writeln('API courses before:');
    apiLog.writeln(OrderMapper.describeCourseContents(detail));
    var courseIds = <int>[];

    // Suite lines already alone on a real course → fire that id.
    if (previousDisplayEntries != null &&
        suivreSectionIndex != null &&
        suivreSectionIndex > 0) {
      courseIds = OrderMapper.extractRequestableCourseIdsForSuivreLayout(
        detail,
        layout: previousDisplayEntries,
        sectionIndex: suivreSectionIndex,
      );
      if (courseIds.isNotEmpty) {
        apiLog.writeln('suite already on course_ids=${courseIds.join(',')}');
      }
    }

    // After delete-suite / layout-only À SUIVRE: preferred course is often an
    // empty shell while items still sit on course 1. Ensure suite lines live
    // on a writable follow-up course before Demande.
    var targetCourseNumber = OrderMapper.resolveWritableSuivreCourseNumber(
      detail,
      preferredCourseNumber: courseNumber,
    );
    if (targetCourseNumber != courseNumber) {
      apiLog.writeln(
        'preferred course $courseNumber not writable → $targetCourseNumber',
      );
    }

    bool targetCourseEmpty() {
      final course =
          OrderMapper.findCourseInOrderDetail(detail, targetCourseNumber);
      if (course == null) return true;
      final items = course['items'];
      if (items is! List || items.isEmpty) return true;
      for (final item in items) {
        if (item is! Map) continue;
        if (item['status'] == 'cancelled') continue;
        return false;
      }
      return true;
    }

    final layoutHasSuiteItems = previousDisplayEntries != null &&
        suivreSectionIndex != null &&
        OrderMapper.productEntriesUnderSection(
          previousDisplayEntries,
          suivreSectionIndex,
        ).isNotEmpty;

    bool suiteNeedsEnsure() {
      if (!layoutHasSuiteItems ||
          previousDisplayEntries == null ||
          suivreSectionIndex == null) {
        return false;
      }
      return !OrderMapper.suiteItemsFullyOnCourse(
        detail,
        layout: previousDisplayEntries,
        sectionIndex: suivreSectionIndex,
        courseNumber: targetCourseNumber,
      );
    }

    // Move/create suite lines onto the target remote course before Demande.
    if (layoutHasSuiteItems &&
        (courseIds.isEmpty || suiteNeedsEnsure() || targetCourseEmpty())) {
      final catalogProducts = await _catalog.getProducts();
      CatalogProductModel? catalogByName(String name) {
        final needle = name.trim().toUpperCase();
        if (needle.isEmpty) return null;
        for (final product in catalogProducts) {
          if (product.name.trim().toUpperCase() == needle) return product;
        }
        return null;
      }

      final ensured = OrderMapper.ensureSuivreSectionOnCourse(
        detail,
        layout: previousDisplayEntries!,
        sectionIndex: suivreSectionIndex!,
        targetCourseNumber: targetCourseNumber,
        resolveProductId: (name) => catalogByName(name)?.id,
        resolveUnitPrice: (name) => catalogByName(name)?.unitPrice,
      );
      if (ensured.changed) {
        apiLog.writeln(
          '── Ensure suite items on course $targetCourseNumber ──',
        );
        detail = await _putOrderUpdate(
          orderId: orderId,
          payload: OrderMapper.buildOrderUpdatePayload(ensured.detail),
          apiLog: apiLog,
        );
        await _local.saveOrderDetail(orderId, detail);
        apiLog.writeln('after ensure PUT:');
        apiLog.writeln(OrderMapper.describeCourseContents(detail));

        detail = await _remote.fetchOrderDetail(orderId);
        await _local.saveOrderDetail(orderId, detail);
        apiLog.writeln('after ensure GET:');
        apiLog.writeln(OrderMapper.describeCourseContents(detail));

        targetCourseNumber = OrderMapper.resolveWritableSuivreCourseNumber(
          detail,
          preferredCourseNumber: targetCourseNumber,
        );
        courseIds = OrderMapper.extractRequestableCourseIdsForSuivreSection(
          detail,
          courseNumber: targetCourseNumber,
        );
        if (courseIds.isEmpty) {
          courseIds = OrderMapper.extractRequestableCourseIdsForSuivreLayout(
            detail,
            layout: previousDisplayEntries,
            sectionIndex: suivreSectionIndex,
          );
        }
        apiLog.writeln(
          'after ensure course=$targetCourseNumber '
          'ids=${courseIds.isEmpty ? '—' : courseIds.join(',')}',
        );
      } else {
        apiLog.writeln('── Ensure made no changes ──');
      }
    }

    if (courseIds.isEmpty) {
      courseIds = OrderMapper.extractRequestableCourseIdsForSuivreSection(
        detail,
        courseNumber: targetCourseNumber,
      );
    }
    if (courseIds.isEmpty &&
        previousDisplayEntries != null &&
        suivreSectionIndex != null) {
      courseIds = OrderMapper.extractRequestableCourseIdsForSuivreLayout(
        detail,
        layout: previousDisplayEntries,
        sectionIndex: suivreSectionIndex,
      );
    }
    if (courseIds.isEmpty) {
      detail = await _remote.fetchOrderDetail(orderId);
      await _local.saveOrderDetail(orderId, detail);
      courseIds = OrderMapper.extractRequestableCourseIdsForSuivreSection(
        detail,
        courseNumber: targetCourseNumber,
      );
      if (courseIds.isEmpty &&
          previousDisplayEntries != null &&
          suivreSectionIndex != null) {
        courseIds = OrderMapper.extractRequestableCourseIdsForSuivreLayout(
          detail,
          layout: previousDisplayEntries,
          sectionIndex: suivreSectionIndex,
        );
      }
    }
    // Prefer course id from the target course shell / its item.course_id.
    if (courseIds.isEmpty) {
      final shellId = OrderMapper.courseRecordIdForNumber(
        detail,
        targetCourseNumber,
      );
      if (shellId != null && !targetCourseEmpty()) {
        courseIds = [shellId];
        apiLog.writeln('shell/item course_id fallback ids=$shellId');
      }
    }
    if (courseIds.isEmpty) {
      apiLog.writeln('FINAL courses:');
      apiLog.writeln(OrderMapper.describeCourseContents(detail));
      lastKitchenSendLog = apiLog.toString();
      throw ApiException(
        message: OrderMapper.describeWhySuivreSectionNotRequestable(
          detail,
          courseNumber: targetCourseNumber,
        ),
      );
    }

    if (layoutHasSuiteItems &&
        previousDisplayEntries != null &&
        suivreSectionIndex != null) {
      _assertSuivreSectionSyncedBeforeDemande(
        detail: detail,
        layout: previousDisplayEntries,
        sectionIndex: suivreSectionIndex,
        courseNumber: targetCourseNumber,
      );
    }

    apiLog.writeln('course_ids=${courseIds.join(',')}');
    await _remote.requestCourses(orderId, courseIds);
    if (_remote.lastApiLog != null) {
      apiLog.writeln(_remote.lastApiLog);
    }
    lastKitchenSendLog = apiLog.toString();

    // Prefer pre-demande layout for product order, but kitchen mapping must win
    // for À SUIVRE → DEMANDÉE (rebake may fire course N+2 while divider says N).
    var order = await getOrderDetail(
      orderId,
      previousDisplayEntries: previousDisplayEntries,
      applyKitchenDemande: true,
    );

    // Always rebuild from the waiter suite layout after Demande. API extract/pin
    // can leave an empty DEMANDÉE while products[] / total still include the
    // suite lines (matches "In order" badges with a blank section).
    if (previousDisplayEntries != null &&
        suivreSectionIndex != null &&
        suivreSectionIndex > 0) {
      final timeLabel = OrderMapper.formatDemandeTime(
            DateTime.now().toUtc().toIso8601String(),
          ) ??
          '--:--:--';
      order = OrderMapper.rebuildOrderAfterSuivreDemande(
        serverOrder: order,
        liveLayout: previousDisplayEntries,
        suivreSectionIndex: suivreSectionIndex,
        demandeTimeLabel: timeLabel,
      );
      await _persistSuivreLayoutHints(orderId, order.displayEntries);
    } else if (OrderMapper.productEntryCount(order.displayEntries) <
        order.products.length) {
      apiLog.writeln(
        'display lost products '
        '(${OrderMapper.productEntryCount(order.displayEntries)}'
        '/${order.products.length}) — reload from API',
      );
      order = await getOrderDetail(
        orderId,
        applyKitchenDemande: true,
      );
    }

    lastKitchenSendLog = apiLog.toString();
    return order;
  }

  Future<SessionOrder> markOrderPrinted(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    final apiLog = StringBuffer();
    lastPrintLog = null;

    if (!await _connectivity.isOnline) {
      lastPrintLog = 'Hors ligne — impression ticket impossible.';
      throw ApiException(
        message: 'Impression impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Impression ticket ──');
    apiLog.writeln('order_id=$orderId');

    try {
      final requestBody = {
        'order_id': orderId,
        'type': 'preview',
        'mark_printed': true,
      };
      apiLog.writeln('── POST ${ApiEndpoints.generateReceipt} ──');
      apiLog.writeln(formatApiPayload(requestBody));
      final response = await _remote.generateReceipt(orderId);
      apiLog.writeln('STATUS: OK');
      apiLog.writeln('RESPONSE:');
      apiLog.writeln(formatApiPayload(response));
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      logTicketPrint(
        phase: 'generate',
        request: requestBody,
        response: response,
        statusCode: 200,
      );

      final order = await getOrderDetail(
        orderId,
        previousDisplayEntries: previousDisplayEntries,
      );
      apiLog.writeln('receipt_print_count=${order.impressionCount}');
      lastPrintLog = apiLog.toString();
      return order;
    } on ApiException catch (e) {
      apiLog.writeln('STATUS: ERREUR (generate)');
      apiLog.writeln('MESSAGE: ${e.message}');
      lastPrintLog = apiLog.toString();
      logTicketPrint(
        phase: 'generate',
        request: {
          'order_id': orderId,
          'type': 'preview',
          'mark_printed': true,
        },
        statusCode: e.statusCode,
        error: e.message,
      );
      apiLog.writeln('generate failed, fallback mark-printed: ${e.message}');
      try {
        final fallbackBody = {'order_id': orderId};
        apiLog.writeln('── POST ${ApiEndpoints.markOrderPrinted} ──');
        apiLog.writeln(formatApiPayload(fallbackBody));
        final response = await _remote.markOrderPrinted(orderId);
        apiLog.writeln('STATUS: OK (fallback mark-printed)');
        apiLog.writeln('RESPONSE:');
        apiLog.writeln(formatApiPayload(response));
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
        logTicketPrint(
          phase: 'mark-printed',
          request: fallbackBody,
          response: response,
          statusCode: 200,
        );

        final order = await getOrderDetail(
          orderId,
          previousDisplayEntries: previousDisplayEntries,
        );
        apiLog.writeln('receipt_print_count=${order.impressionCount}');
        lastPrintLog = apiLog.toString();
        return order;
      } on ApiException catch (fallbackError) {
        apiLog.writeln('STATUS: ERREUR (fallback)');
        apiLog.writeln('ERREUR: ${fallbackError.message}');
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
        logTicketPrint(
          phase: 'mark-printed',
          request: {'order_id': orderId},
          statusCode: fallbackError.statusCode,
          error: fallbackError.message,
        );
        lastPrintLog = apiLog.toString();
        rethrow;
      }
    } catch (e) {
      apiLog.writeln('STATUS: ERREUR (inattendue)');
      apiLog.writeln('$e');
      lastPrintLog = apiLog.toString();
      logTicketPrint(
        phase: 'ticket',
        request: {'order_id': orderId},
        error: e.toString(),
      );
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Erreur ticket: $e');
    }
  }

  Future<SessionOrder> addSimpleProductToOrder({
    required int orderId,
    required int productId,
    required double unitPrice,
    int qty = 1,
    String comment = '',
    List<OrderDisplayEntry>? layoutHints,
    String? tableNumber,
    int? waiterId,
    /// When the UI is intentionally empty (delete-all), revive before adding.
    bool expectEmptyShell = false,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — ajout article impossible.';
      throw ApiException(
        message: 'Ajout impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Ajout article simple ──');
    apiLog.writeln('order_id=$orderId product_id=$productId qty=$qty');

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      Map<String, dynamic> detail;
      try {
        detail = await _remote.fetchOrderDetail(orderId);
      } on ApiException catch (e) {
        if (_isOrderNotFoundError(e)) {
          apiLog.writeln(
            '── Order $orderId missing on add — recreate with product ──',
          );
          final cached = cachedOrderDetail(orderId) ??
              <String, dynamic>{
                'id': orderId,
                'status': 'cancelled',
                'seat_orders': [
                  {
                    'seat_number': 1,
                    'courses': [
                      {'id': 0, 'course_number': 1, 'items': <dynamic>[]},
                    ],
                  },
                ],
              };
          return _recreateOrderWithSimpleProduct(
            oldOrderId: orderId,
            detail: cached,
            productId: productId,
            unitPrice: unitPrice,
            qty: qty,
            comment: comment,
            tableNumber: tableNumber,
            waiterId: waiterId,
            apiLog: apiLog,
          );
        }
        rethrow;
      }

      if (_needsEmptyShellRevive(detail, expectEmptyShell: expectEmptyShell)) {
        apiLog.writeln(
          '── Empty shell → revive + add (expectEmpty=$expectEmptyShell) ──',
        );
        return _reviveOrRecreateWithSimpleProduct(
          orderId: orderId,
          detail: detail,
          productId: productId,
          unitPrice: unitPrice,
          qty: qty,
          comment: comment,
          layoutHints: layoutHints,
          tableNumber: tableNumber,
          waiterId: waiterId,
          apiLog: apiLog,
        );
      }

      // Always add via PUT /api/orders/:id (full seat_orders state).
      // POST …/seat-orders/:id/items is unreliable on emptied/recreated orders.
      final suivreHints = _resolveSuivreHints(
        orderId,
        layoutHints: layoutHints,
      );
      _ensureAddItemCourse(
        detail,
        apiLog,
        orderId: orderId,
        layoutHints: layoutHints,
      );

      final payload = OrderMapper.addOrIncrementSimpleItem(
        orderDetail: detail,
        productId: productId,
        unitPrice: unitPrice,
        qty: qty,
        comment: comment,
        suivreSectionCount: suivreHints.count,
        suivreSplitHints: suivreHints.splits,
        layoutHints: layoutHints,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      _forgetEmptyShellDisplay(orderId);
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();
      return _fetchAndMapOrder(
        orderId,
        previousDisplayEntries: layoutHints,
      );
    } on ApiException catch (e) {
      apiLog.writeln('PUT add failed: ${e.message}');

      try {
        final detail = await _remote.fetchOrderDetail(orderId);

        if (OrderMapper.shouldRecreateOrderForAdd(detail) ||
            OrderMapper.orderDetailHasNoVisibleItems(detail) ||
            _shouldRecreateAfterAddFailure(e, detail)) {
          apiLog.writeln('── Add failed on empty shell → revive/recreate PUT ──');
          return _reviveOrRecreateWithSimpleProduct(
            orderId: orderId,
            detail: detail,
            productId: productId,
            unitPrice: unitPrice,
            qty: qty,
            comment: comment,
            layoutHints: layoutHints,
            tableNumber: tableNumber,
            waiterId: waiterId,
            apiLog: apiLog,
          );
        }

        final suivreHints = _resolveSuivreHints(
          orderId,
          layoutHints: layoutHints,
        );
        _ensureAddItemCourse(
          detail,
          apiLog,
          orderId: orderId,
          layoutHints: layoutHints,
        );

        final payload = OrderMapper.addOrIncrementSimpleItem(
          orderDetail: detail,
          productId: productId,
          unitPrice: unitPrice,
          qty: qty,
          comment: comment,
          suivreSectionCount: suivreHints.count,
          suivreSplitHints: suivreHints.splits,
          layoutHints: layoutHints,
        );

        final updated = await _putOrderUpdate(
          orderId: orderId,
          payload: payload,
          apiLog: apiLog,
        );
        await _local.saveOrderDetail(orderId, updated);
        lastAddItemLog = apiLog.toString();
        return _fetchAndMapOrder(
          orderId,
          previousDisplayEntries: layoutHints,
        );
      } on ApiException catch (fallbackError) {
        try {
          final detail = _local.readOrderDetail(orderId) ??
              await _remote.fetchOrderDetail(orderId);
          if (_shouldRecreateAfterAddFailure(fallbackError, detail) ||
              OrderMapper.orderDetailHasNoVisibleItems(detail)) {
            apiLog.writeln(
              '── PUT retry failed on empty shell → revive/recreate ──',
            );
            return _reviveOrRecreateWithSimpleProduct(
              orderId: orderId,
              detail: detail,
              productId: productId,
              unitPrice: unitPrice,
              qty: qty,
              comment: comment,
              layoutHints: layoutHints,
              tableNumber: tableNumber,
              waiterId: waiterId,
              apiLog: apiLog,
            );
          }
        } catch (_) {}

        apiLog.writeln('ERREUR: ${fallbackError.message}');
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
        lastAddItemLog = apiLog.toString();
        rethrow;
      }
    }
  }

  /// Adds many simple products with **one** `PUT /api/orders/:id`.
  ///
  /// Rapid catalog taps must call this once with the full queue — never one
  /// PUT per tap (sequential fallback was removed for that reason).
  Future<SessionOrder> addSimpleProductsBatchToOrder({
    required int orderId,
    required List<SimpleProductBatchLine> items,
    List<OrderDisplayEntry>? layoutHints,
    int? selectedSuivreSectionIndex,
    String? tableNumber,
    int? waiterId,
    bool expectEmptyShell = false,
  }) async {
    if (items.isEmpty) {
      return getOrderDetail(
        orderId,
        previousDisplayEntries: layoutHints,
      );
    }

    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — ajout articles impossible.';
      throw ApiException(
        message: 'Ajout impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Ajout articles (batch, 1 PUT) ──');
    apiLog.writeln('order_id=$orderId count=${items.length}');
    for (final line in items) {
      apiLog.writeln(
        '  product_id=${line.productId} qty=${line.qty} '
        'unit=${line.unitPrice}',
      );
    }

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      var detail = OrderMapper.copyOrderDetail(
        await _remote.fetchOrderDetail(orderId),
      );

      // Delete-then-quick-add race: never PUT locally-deleted lines back.
      _cancelSuppressedItemsInDetail(orderId, detail, apiLog);

      if (_needsEmptyShellRevive(detail, expectEmptyShell: expectEmptyShell)) {
        apiLog.writeln(
          '── Batch on empty shell → revive first line, then rest ──',
        );
        await _persistSuivreLayoutHints(orderId, const []);
        final first = items.first;
        final rest = items.sublist(1);
        final revived = await _reviveOrRecreateWithSimpleProduct(
          orderId: orderId,
          detail: detail,
          productId: first.productId,
          unitPrice: first.unitPrice,
          qty: first.qty,
          comment: first.comment,
          layoutHints: null,
          tableNumber: tableNumber,
          waiterId: waiterId,
          apiLog: apiLog,
        );
        lastAddItemLog = apiLog.toString();
        if (rest.isEmpty) return revived;
        final activeId = revived.id > 0 ? revived.id : orderId;
        return addSimpleProductsBatchToOrder(
          orderId: activeId,
          items: rest,
          layoutHints: revived.displayEntries,
          tableNumber: tableNumber,
          waiterId: waiterId,
        );
      }

      final working = OrderMapper.copyOrderDetail(detail);
      final suivreHints = _resolveSuivreHints(
        orderId,
        layoutHints: layoutHints,
      );
      _ensureAddItemCourse(
        working,
        apiLog,
        orderId: orderId,
        layoutHints: layoutHints,
      );

      final payload = Map<String, dynamic>.from(
        OrderMapper.appendSimpleItems(
          orderDetail: working,
          items: [
            for (final line in items)
              (
                productId: line.productId,
                unitPrice: line.unitPrice,
                qty: line.qty,
                comment: line.comment,
              ),
          ],
          suivreSectionCount: suivreHints.count,
          suivreSplitHints: suivreHints.splits,
          layoutHints: layoutHints,
          selectedSuivreSectionIndex: selectedSuivreSectionIndex,
        ),
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      _forgetEmptyShellDisplay(orderId);
      // Persist off the critical path — don't block the UI isolate on Hive JSON.
      unawaited(_local.saveOrderDetail(orderId, updated));
      unawaited(_sessionLocal.upsertOpenOrderInList(updated));
      lastAddItemLog = apiLog.toString();
      // Map PUT body directly — avoid a second GET that stalls rapid taps.
      return _mapDetailToSessionOrder(
        orderId,
        updated,
        previousDisplayEntries: layoutHints,
      );
    } on ApiException catch (e) {
      apiLog.writeln('Batch PUT failed: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();

      // Never fall back to POST …/seat-orders/…/items — use PUT revive/recreate.
      apiLog.writeln('── Batch fallback: revive/recreate via PUT ──');
      try {
        final detail = OrderMapper.copyOrderDetail(
          await _remote.fetchOrderDetail(orderId),
        );
        _cancelSuppressedItemsInDetail(orderId, detail, apiLog);
        await _persistSuivreLayoutHints(orderId, const []);
        final first = items.first;
        final rest = items.sublist(1);
        final revived = await _reviveOrRecreateWithSimpleProduct(
          orderId: orderId,
          detail: detail,
          productId: first.productId,
          unitPrice: first.unitPrice,
          qty: first.qty,
          comment: first.comment,
          layoutHints: null,
          tableNumber: tableNumber,
          waiterId: waiterId,
          apiLog: apiLog,
        );
        lastAddItemLog = apiLog.toString();
        if (rest.isEmpty) return revived;
        final activeId = revived.id > 0 ? revived.id : orderId;
        return addSimpleProductsBatchToOrder(
          orderId: activeId,
          items: rest,
          layoutHints: revived.displayEntries,
          tableNumber: tableNumber,
          waiterId: waiterId,
        );
      } on ApiException catch (fallbackError) {
        apiLog.writeln('Batch PUT revive failed: ${fallbackError.message}');
        lastAddItemLog = apiLog.toString();
        rethrow;
      }
    }
  }

  bool _shouldRecreateAfterAddFailure(
    ApiException error,
    Map<String, dynamic> detail,
  ) {
    if (!OrderMapper.orderDetailHasNoVisibleItems(detail)) return false;
    if (OrderMapper.shouldRecreateOrderForAdd(detail)) return true;

    final message = error.message.toLowerCase();
    final code = error.statusCode;
    return code == 404 ||
        code == 422 ||
        code == 500 ||
        message.contains('not found') ||
        message.contains('adding items to seat') ||
        message.contains('introuvable');
  }

  bool _isTableHasActiveOrderError(ApiException error) {
    final message = error.message.toLowerCase();
    return message.contains('active order') ||
        message.contains('commande active') ||
        message.contains('already has');
  }

  /// Revive the emptied shell via PUT (reopen + item). Only create a new order
  /// when the shell is truly gone; if create hits "table has active order",
  /// add into that active order instead.
  Future<SessionOrder> _reviveOrRecreateWithSimpleProduct({
    required int orderId,
    required Map<String, dynamic> detail,
    required int productId,
    required double unitPrice,
    required int qty,
    required String comment,
    required StringBuffer apiLog,
    List<OrderDisplayEntry>? layoutHints,
    String? tableNumber,
    int? waiterId,
  }) async {
    try {
      final revived = await _reviveEmptyOrderWithSimpleProduct(
        orderId: orderId,
        detail: detail,
        productId: productId,
        unitPrice: unitPrice,
        qty: qty,
        comment: comment,
        layoutHints: layoutHints,
        apiLog: apiLog,
      );
      lastAddItemLog = apiLog.toString();
      return revived;
    } on ApiException catch (reviveError) {
      apiLog.writeln('── Revive PUT failed: ${reviveError.message} ──');
    }

    return _recreateOrderWithSimpleProduct(
      oldOrderId: orderId,
      detail: detail,
      productId: productId,
      unitPrice: unitPrice,
      qty: qty,
      comment: comment,
      tableNumber: tableNumber,
      waiterId: waiterId,
      apiLog: apiLog,
    );
  }

  Future<SessionOrder> _reviveEmptyOrderWithSimpleProduct({
    required int orderId,
    required Map<String, dynamic> detail,
    required int productId,
    required double unitPrice,
    required int qty,
    required String comment,
    required StringBuffer apiLog,
    List<OrderDisplayEntry>? layoutHints,
  }) async {
    // Truly empty ticket (delete-all): clear courses then add the new line.
    final cleaned = OrderMapper.withAllCourseItemsCleared(detail);
    final working = OrderMapper.asOpenEmptyOrderShell(cleaned);
    // Empty revive always targets course 1 — never stale À SUIVRE hints.
    await _persistSuivreLayoutHints(orderId, const []);

    _ensureAddItemCourse(
      working,
      apiLog,
      orderId: orderId,
      layoutHints: null,
    );

    final payload = Map<String, dynamic>.from(
      OrderMapper.addOrIncrementSimpleItem(
        orderDetail: working,
        productId: productId,
        unitPrice: unitPrice,
        qty: qty,
        comment: comment,
        suivreSectionCount: 0,
        suivreSplitHints: const [],
        layoutHints: null,
      ),
    );
    // Force the shell back to an open/unpaid state so the API accepts lines.
    payload['status'] = 'open';
    payload['payment_status'] = 'not_paid';
    payload['payment_status_detailed'] = 'not_paid';

    apiLog.writeln(
      '── PUT revive empty order $orderId (add item) ──',
    );
    final updated = await _putOrderUpdate(
      orderId: orderId,
      payload: payload,
      apiLog: apiLog,
    );
    _forgetEmptyShellDisplay(orderId);
    await _local.saveOrderDetail(orderId, updated);
    await _sessionLocal.upsertOpenOrderInList(updated);
    return _fetchAndMapOrder(
      orderId,
      previousDisplayEntries: layoutHints,
    );
  }

  Future<SessionOrder> _recreateOrderWithSimpleProduct({
    required int oldOrderId,
    required Map<String, dynamic> detail,
    required int productId,
    required double unitPrice,
    required int qty,
    required String comment,
    required StringBuffer apiLog,
    String? tableNumber,
    int? waiterId,
  }) async {
    final resolvedTable = tableNumber ??
        OrderMapper.displayKey(
          orderId: oldOrderId,
          tableNumber: OrderMapper.tableNumberFromDetail(detail),
        );
    final resolvedWaiter =
        waiterId ?? OrderMapper.waiterIdFromOrderMap(detail) ?? 0;
    final guests = (detail['number_of_guests'] as num?)?.toInt();

    apiLog.writeln(
      '── Recreate order for $resolvedTable (old_id=$oldOrderId) ──',
    );

    if (resolvedWaiter <= 0) {
      throw ApiException(
        message: 'Impossible de recréer la commande (serveur inconnu).',
      );
    }

    // Do NOT retire the old shell before create — that leaves the table with
    // no usable order id (ORDER ID not found). Retire only after success.
    try {
      final created = await createOrderWithFirstSimpleProduct(
        tableNumber: resolvedTable,
        waiterId: resolvedWaiter,
        productId: productId,
        unitPrice: unitPrice,
        qty: qty,
        comment: comment,
        numberOfGuests: guests,
      );
      apiLog.writeln('── New order id=${created.id} ──');
      if (created.id > 0 && created.id != oldOrderId) {
        unawaited(_retireDeadOrderShell(oldOrderId, apiLog: apiLog));
      }
      lastAddItemLog = apiLog.toString();
      return created;
    } on ApiException catch (createError) {
      apiLog.writeln('── Create failed: ${createError.message} ──');

      // Table still locked to an active order (often the same emptied shell).
      if (_isTableHasActiveOrderError(createError)) {
        final activeId =
            await resolveOrderIdForTableNumber(resolvedTable) ?? oldOrderId;
        apiLog.writeln(
          '── Active-order conflict → add into order $activeId ──',
        );
        final activeDetail = await _remote.fetchOrderDetail(activeId);
        final revived = await _reviveEmptyOrderWithSimpleProduct(
          orderId: activeId,
          detail: activeDetail,
          productId: productId,
          unitPrice: unitPrice,
          qty: qty,
          comment: comment,
          apiLog: apiLog,
        );
        if (activeId != oldOrderId) {
          unawaited(_retireDeadOrderShell(oldOrderId, apiLog: apiLog));
        }
        lastAddItemLog = apiLog.toString();
        return revived;
      }

      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  Future<void> _retireDeadOrderShell(
    int oldOrderId, {
    required StringBuffer apiLog,
  }) async {
    try {
      await _local.removeOrderDetail(oldOrderId);
    } catch (_) {}
    try {
      await _sessionLocal.removeOpenOrderFromList(oldOrderId);
    } catch (_) {}

    // Best-effort: free the table if the backend still holds the paid shell.
    try {
      apiLog.writeln('── POST /api/orders/$oldOrderId/close (retire shell) ──');
      await _remote.closeOrder(oldOrderId);
    } catch (e) {
      apiLog.writeln('── close old shell ignored: $e ──');
    }
  }

  Future<SessionOrder> addComposedProductToOrder({
    required int orderId,
    required int productId,
    required double basePrice,
    required List<Map<String, dynamic>> menuSelections,
    String comment = '',
    List<OrderDisplayEntry>? layoutHints,
    int? selectedSuivreSectionIndex,
    String? tableNumber,
    int? waiterId,
    bool expectEmptyShell = false,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — ajout menu impossible.';
      throw ApiException(
        message: 'Ajout impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Ajout produit composé ──');
    apiLog.writeln('order_id=$orderId product_id=$productId');

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      var detail = await _remote.fetchOrderDetail(orderId);

      if (_needsEmptyShellRevive(detail, expectEmptyShell: expectEmptyShell)) {
        apiLog.writeln(
          '── Empty shell → revive + add composed (expectEmpty=$expectEmptyShell) ──',
        );
        try {
          final revived = await _reviveEmptyOrderWithComposedProduct(
            orderId: orderId,
            detail: detail,
            productId: productId,
            basePrice: basePrice,
            menuSelections: menuSelections,
            comment: comment,
            layoutHints: layoutHints,
            apiLog: apiLog,
          );
          lastAddItemLog = apiLog.toString();
          return revived;
        } on ApiException catch (reviveError) {
          apiLog.writeln('── Revive composed failed: ${reviveError.message} ──');
          return _recreateOrderWithComposedProduct(
            oldOrderId: orderId,
            detail: detail,
            productId: productId,
            basePrice: basePrice,
            menuSelections: menuSelections,
            comment: comment,
            tableNumber: tableNumber,
            waiterId: waiterId,
            apiLog: apiLog,
          );
        }
      }

      final supplement = menuSelections.fold<double>(
        0,
        (sum, selection) {
          final price = selection['price'];
          if (price is num) return sum + price.toDouble();
          return sum +
              (double.tryParse(price?.toString().replaceAll(',', '.') ?? '') ??
                  0);
        },
      );

      _ensureAddItemCourse(
        detail,
        apiLog,
        orderId: orderId,
        layoutHints: layoutHints,
      );

      final suivreHints = _resolveSuivreHints(
        orderId,
        layoutHints: layoutHints,
      );
      final payload = OrderMapper.appendComposedItem(
        orderDetail: detail,
        productId: productId,
        subTotal: basePrice + supplement,
        menuSelections: menuSelections,
        comment: comment,
        suivreSectionCount: suivreHints.count,
        suivreSplitHints: suivreHints.splits,
        layoutHints: layoutHints,
        selectedSuivreSectionIndex: selectedSuivreSectionIndex,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();
      return _fetchAndMapOrder(
        orderId,
        previousDisplayEntries: layoutHints,
      );
    } on ApiException catch (e) {
      try {
        final detail = _local.readOrderDetail(orderId) ??
            await _remote.fetchOrderDetail(orderId);
        if (_shouldRecreateAfterAddFailure(e, detail) ||
            OrderMapper.shouldRecreateOrderForAdd(detail)) {
          apiLog.writeln('── Composed add failed on empty shell → recreate ──');
          lastAddItemLog = apiLog.toString();
          return _recreateOrderWithComposedProduct(
            oldOrderId: orderId,
            detail: detail,
            productId: productId,
            basePrice: basePrice,
            menuSelections: menuSelections,
            comment: comment,
            tableNumber: tableNumber,
            waiterId: waiterId,
            apiLog: apiLog,
          );
        }
      } catch (_) {}

      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  Future<SessionOrder> _reviveEmptyOrderWithComposedProduct({
    required int orderId,
    required Map<String, dynamic> detail,
    required int productId,
    required double basePrice,
    required List<Map<String, dynamic>> menuSelections,
    required String comment,
    required StringBuffer apiLog,
    List<OrderDisplayEntry>? layoutHints,
  }) async {
    final cleaned = OrderMapper.withAllCourseItemsCleared(detail);
    final working = OrderMapper.asOpenEmptyOrderShell(cleaned);
    final supplement = menuSelections.fold<double>(
      0,
      (sum, selection) {
        final price = selection['price'];
        if (price is num) return sum + price.toDouble();
        return sum +
            (double.tryParse(price?.toString().replaceAll(',', '.') ?? '') ?? 0);
      },
    );
    final suivreHints = _resolveSuivreHints(
      orderId,
      layoutHints: layoutHints,
    );

    _ensureAddItemCourse(
      working,
      apiLog,
      orderId: orderId,
      layoutHints: layoutHints,
    );

    final payload = Map<String, dynamic>.from(
      OrderMapper.appendComposedItem(
        orderDetail: working,
        productId: productId,
        subTotal: basePrice + supplement,
        menuSelections: menuSelections,
        comment: comment,
        suivreSectionCount: suivreHints.count,
        suivreSplitHints: suivreHints.splits,
        layoutHints: layoutHints,
      ),
    );
    payload['status'] = 'open';
    payload['payment_status'] = 'not_paid';
    payload['payment_status_detailed'] = 'not_paid';

    apiLog.writeln(
      '── PUT revive empty order $orderId (add composed) ──',
    );
    final updated = await _putOrderUpdate(
      orderId: orderId,
      payload: payload,
      apiLog: apiLog,
    );
    _forgetEmptyShellDisplay(orderId);
    await _local.saveOrderDetail(orderId, updated);
    await _sessionLocal.upsertOpenOrderInList(updated);
    return _fetchAndMapOrder(
      orderId,
      previousDisplayEntries: layoutHints,
    );
  }

  Future<SessionOrder> _recreateOrderWithComposedProduct({
    required int oldOrderId,
    required Map<String, dynamic> detail,
    required int productId,
    required double basePrice,
    required List<Map<String, dynamic>> menuSelections,
    required String comment,
    required StringBuffer apiLog,
    String? tableNumber,
    int? waiterId,
  }) async {
    final resolvedTable = tableNumber ??
        OrderMapper.displayKey(
          orderId: oldOrderId,
          tableNumber: OrderMapper.tableNumberFromDetail(detail),
        );
    final resolvedWaiter =
        waiterId ?? OrderMapper.waiterIdFromOrderMap(detail) ?? 0;
    final guests = (detail['number_of_guests'] as num?)?.toInt();

    apiLog.writeln(
      '── Recreate composed order for $resolvedTable (old_id=$oldOrderId) ──',
    );

    if (resolvedWaiter <= 0) {
      throw ApiException(
        message: 'Impossible de recréer la commande (serveur inconnu).',
      );
    }

    // Do NOT retire before create — keep a usable table order until replacement
    // succeeds (same race as simple-product recreate).
    try {
      final created = await createOrderWithFirstComposedProduct(
        tableNumber: resolvedTable,
        waiterId: resolvedWaiter,
        productId: productId,
        basePrice: basePrice,
        menuSelections: menuSelections,
        comment: comment,
        numberOfGuests: guests,
      );
      apiLog.writeln('── New order id=${created.id} ──');
      if (created.id > 0 && created.id != oldOrderId) {
        unawaited(_retireDeadOrderShell(oldOrderId, apiLog: apiLog));
      }
      lastAddItemLog = apiLog.toString();
      return created;
    } on ApiException catch (createError) {
      apiLog.writeln('── Create composed failed: ${createError.message} ──');
      if (_isTableHasActiveOrderError(createError)) {
        final activeId =
            await resolveOrderIdForTableNumber(resolvedTable) ?? oldOrderId;
        apiLog.writeln(
          '── Active-order conflict → add composed into order $activeId ──',
        );
        final activeDetail = await _remote.fetchOrderDetail(activeId);
        final revived = await _reviveEmptyOrderWithComposedProduct(
          orderId: activeId,
          detail: activeDetail,
          productId: productId,
          basePrice: basePrice,
          menuSelections: menuSelections,
          comment: comment,
          apiLog: apiLog,
        );
        if (activeId != oldOrderId) {
          unawaited(_retireDeadOrderShell(oldOrderId, apiLog: apiLog));
        }
        lastAddItemLog = apiLog.toString();
        return revived;
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  Future<SessionOrder> setProductQuantityInOrder({
    required int orderId,
    required int productId,
    required int qty,
    required double unitPrice,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — mise à jour quantité impossible.';
      throw ApiException(
        message: 'Modification impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Mise à jour quantité ──');
    apiLog.writeln('order_id=$orderId product_id=$productId qty=$qty');

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);

      final payload = OrderMapper.setSimpleProductQuantity(
        orderDetail: detail,
        productId: productId,
        qty: qty,
        unitPrice: unitPrice,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      lastAddItemLog = apiLog.toString();
      return _persistOrderAfterItemMutation(
        orderId: orderId,
        detail: updated,
      );
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  Future<SessionOrder> setOrderLineQuantityAtIndex({
    required int orderId,
    required int lineIndex,
    required int qty,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — mise à jour quantité impossible.';
      throw ApiException(
        message: 'Modification impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Mise à jour quantité ligne ──');
    apiLog.writeln('order_id=$orderId line_index=$lineIndex qty=$qty');

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);
      final beforeCount = OrderMapper.countVisibleLineItems(detail);
      final localMutated = OrderMapper.copyOrderDetail(detail);

      final payload = OrderMapper.setLineQuantityAtIndex(
        orderDetail: localMutated,
        lineIndex: lineIndex,
        qty: qty,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      lastAddItemLog = apiLog.toString();
      return _persistOrderAfterLineEdit(
        orderId: orderId,
        putResponse: updated,
        localMutated: localMutated,
        beforeVisibleCount: beforeCount,
      );
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  Future<SessionOrder> adjustProductQuantityInOrder({
    required int orderId,
    required int productId,
    required int delta,
    required double unitPrice,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — mise à jour quantité impossible.';
      throw ApiException(
        message: 'Modification impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Ajustement quantité ──');
    apiLog.writeln(
      'order_id=$orderId product_id=$productId delta=$delta',
    );

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);

      final payload = OrderMapper.adjustSimpleProductQuantity(
        orderDetail: detail,
        productId: productId,
        delta: delta,
        unitPrice: unitPrice,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      lastAddItemLog = apiLog.toString();
      return _persistOrderAfterItemMutation(
        orderId: orderId,
        detail: updated,
      );
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  Future<SessionOrder> syncDisplayFromTrimmedLayout(
    int orderId, {
    required List<OrderDisplayEntry> trimmedDisplay,
  }) async {
    if (orderId <= 0) {
      throw ApiException(message: 'Commande introuvable pour cette table.');
    }

    Map<String, dynamic>? detail = _local.readOrderDetail(orderId);
    if (detail == null) {
      if (!await _connectivity.isOnline) {
        throw ApiException(
          message: 'Détails de commande indisponibles hors ligne.',
        );
      }
      detail = await _remote.fetchOrderDetail(orderId);
      await _local.saveOrderDetail(orderId, detail);
    }

    // Keep the waiter-trimmed layout (À SUIVRE already removed).
    final base = OrderMapper.fromOrderDetail(detail);
    final displayEntries = OrderMapper.applyTrimmedSuivreLayout(
      products: base.products,
      trimmedLayout: trimmedDisplay,
    );
    final order = base.copyWith(displayEntries: displayEntries);

    await _persistSuivreLayoutHints(orderId, displayEntries);
    return order;
  }

  Future<SessionOrder> cancelOrderLinesAtIndices({
    required int orderId,
    required List<int> lineIndices,
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      apiLog.writeln('Hors ligne — annulation article impossible.');
      _logDeleteTrace(
        apiLog,
        phase: 'api_error',
        orderId: orderId,
        error: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
      throw ApiException(
        message: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Annulation articles (section) ──');
    apiLog.writeln('order_id=$orderId lines=$lineIndices');

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);
      final localMutated = OrderMapper.copyOrderDetail(detail);

      final payload = OrderMapper.cancelOrderLinesAtIndices(
        orderDetail: localMutated,
        lineIndices: lineIndices.toSet(),
      );
      if (OrderMapper.orderDetailHasNoVisibleItems(localMutated)) {
        payload['status'] = 'open';
        payload['payment_status'] = 'not_paid';
        payload['payment_status_detailed'] = 'not_paid';
      }

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      _logDeleteTrace(apiLog, phase: 'api_ok', orderId: orderId);

      return _persistOrderAfterItemMutation(
        orderId: orderId,
        detail: updated,
        previousDisplayEntries: previousDisplayEntries,
        keepLinesIfApiEmpty: OrderMapper.orderDetailHasNoVisibleItems(localMutated)
            ? null
            : localMutated,
      );
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      _logDeleteTrace(
        apiLog,
        phase: 'api_error',
        orderId: orderId,
        error: e.message,
      );
      rethrow;
    }
  }

  /// One PUT that empties the ticket while keeping the order **open**.
  ///
  /// Critical: do **not** cancel every line — on this API that auto-cancels the
  /// whole order and later calls fail with "ORDER ID not found". Strip items
  /// (same path as empty-seed clear), then **verify the real API status**
  /// (local `asOpenEmptyOrderShell` lies by forcing status=open). If the order
  /// is cancelled/gone, reopen or recreate and return the live id.
  Future<SessionOrder> cancelAllVisibleLines({
    required int orderId,
    List<OrderDisplayEntry>? previousDisplayEntries,
    String? tableNumber,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      apiLog.writeln('Hors ligne — annulation article impossible.');
      _logDeleteTrace(
        apiLog,
        phase: 'api_error',
        orderId: orderId,
        tableNumber: tableNumber,
        error: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
      throw ApiException(
        message: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Vider ticket (strip keep-open, not cancel-all) ──');
    apiLog.writeln('order_id=$orderId table=${tableNumber ?? '—'}');

    Future<SessionOrder> finishRecreated(SessionOrder kept) async {
      _rememberEmptyShellDisplay(kept.id);
      clearPendingLocalDeleteFlag(kept.id);
      if (kept.id != orderId) {
        clearPendingLocalDeleteFlag(orderId);
        clearSuppressedOrderItemIds(orderId);
        _forgetEmptyShellDisplay(orderId);
      }
      await _persistSuivreLayoutHints(kept.id, const []);
      apiLog.writeln('── Empty open order ready id=${kept.id} ──');
      _logDeleteTrace(
        apiLog,
        phase: 'api_ok',
        orderId: kept.id > 0 ? kept.id : orderId,
        tableNumber: tableNumber,
      );
      return kept;
    }

    Map<String, dynamic>? detail;
    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      detail = await _remote.fetchOrderDetail(orderId);
    } on ApiException catch (e) {
      apiLog.writeln('GET failed: ${e.message}');
      if (_isOrderNotFoundError(e)) {
        final kept = await _recreateEmptyOpenOrderForTable(
          oldOrderId: orderId,
          detail: cachedOrderDetail(orderId),
          tableNumberHint: tableNumber,
          apiLog: apiLog,
        );
        return finishRecreated(kept);
      }
      _logDeleteTrace(
        apiLog,
        phase: 'api_error',
        orderId: orderId,
        tableNumber: tableNumber,
        error: e.message,
      );
      rethrow;
    }

    final sourceDetail = detail!;
    try {
      await _clearVisibleItemsKeepOpen(orderId, sourceDetail, apiLog);
    } on ApiException catch (e) {
      apiLog.writeln('Strip failed: ${e.message}');
      if (_isOrderNotFoundError(e)) {
        final kept = await _recreateEmptyOpenOrderForTable(
          oldOrderId: orderId,
          detail: sourceDetail,
          tableNumberHint: tableNumber,
          apiLog: apiLog,
        );
        return finishRecreated(kept);
      }
      _logDeleteTrace(
        apiLog,
        phase: 'api_error',
        orderId: orderId,
        tableNumber: tableNumber,
        error: e.message,
      );
      rethrow;
    }

    // Always re-GET the *raw* API status. Strip helpers force status=open
    // locally, which previously skipped recreate while the order was cancelled.
    Map<String, dynamic> verified;
    try {
      apiLog.writeln('── GET verify after strip /api/orders/$orderId ──');
      verified = await _remote.fetchOrderDetail(orderId);
    } on ApiException catch (e) {
      apiLog.writeln('Verify GET failed: ${e.message}');
      if (_isOrderNotFoundError(e)) {
        final kept = await _recreateEmptyOpenOrderForTable(
          oldOrderId: orderId,
          detail: sourceDetail,
          tableNumberHint: tableNumber,
          apiLog: apiLog,
        );
        return finishRecreated(kept);
      }
      // Network blip — still try reopen/recreate from last known detail.
      verified = sourceDetail;
    }

    final needsRecreate = OrderMapper.isOrderClosedOrCancelled(verified) ||
        OrderMapper.isOrderFullyPaid(verified) ||
        !OrderMapper.isActiveDayOpenOrder(verified) ||
        OrderMapper.shouldRecreateOrderForAdd(verified);

    if (needsRecreate) {
      apiLog.writeln(
        '── Order status=${verified['status']} after empty — '
        'reopen / recreate (must not keep cancelled id) ──',
      );
      final kept = await _reopenOrRecreateEmptyOrder(
        orderId: orderId,
        detail: verified,
        apiLog: apiLog,
        tableNumberHint: tableNumber,
      );
      return finishRecreated(kept);
    }

    final shell = OrderMapper.asOpenEmptyOrderShell(verified);
    shell['status'] = 'open';
    shell['payment_status'] = 'not_paid';
    shell['payment_status_detailed'] = 'not_paid';
    await _local.saveOrderDetail(orderId, shell);
    await _sessionLocal.upsertOpenOrderInList(shell);
    _rememberEmptyShellDisplay(orderId);
    clearPendingLocalDeleteFlag(orderId);
    await _persistSuivreLayoutHints(orderId, const []);
    _logDeleteTrace(
      apiLog,
      phase: 'api_ok',
      orderId: orderId,
      tableNumber: tableNumber,
    );

    return OrderMapper.fromOrderDetail(shell).copyWith(
      id: orderId,
      products: const [],
      displayEntries: const [],
      itemCount: 0,
      total: OrderMapper.formatPrice('0'),
    );
  }

  /// Reopen the emptied shell; if the API still considers it cancelled/closed,
  /// create a new empty open order for the same table.
  Future<SessionOrder> _reopenOrRecreateEmptyOrder({
    required int orderId,
    required Map<String, dynamic> detail,
    required StringBuffer apiLog,
    String? tableNumberHint,
  }) async {
    // 1) Reopen same id (preferred — keeps order id stable).
    try {
      var shell = OrderMapper.asOpenEmptyOrderShell(detail);
      final reopenPayload = OrderMapper.buildOrderUpdatePayload(
        shell,
        keepOpenWhenEmpty: true,
      );
      reopenPayload['status'] = 'open';
      reopenPayload['payment_status'] = 'not_paid';
      reopenPayload['payment_status_detailed'] = 'not_paid';
      apiLog.writeln('── PUT reopen empty order $orderId ──');
      await _remote.updateOrder(orderId, reopenPayload);
      // Trust only a fresh GET — PUT body may echo our forced status=open.
      Map<String, dynamic> updated;
      try {
        updated = await _remote.fetchOrderDetail(orderId);
      } on ApiException catch (e) {
        if (_isOrderNotFoundError(e)) {
          apiLog.writeln('── Reopen GET 404 — will recreate ──');
          return _recreateEmptyOpenOrderForTable(
            oldOrderId: orderId,
            detail: detail,
            tableNumberHint: tableNumberHint,
            apiLog: apiLog,
          );
        }
        rethrow;
      }
      if (!OrderMapper.isOrderClosedOrCancelled(updated) &&
          !OrderMapper.isOrderFullyPaid(updated) &&
          OrderMapper.isActiveDayOpenOrder(updated)) {
        shell = OrderMapper.asOpenEmptyOrderShell(updated);
        shell['status'] = 'open';
        await _local.saveOrderDetail(orderId, shell);
        await _sessionLocal.upsertOpenOrderInList(shell);
        return OrderMapper.fromOrderDetail(shell).copyWith(
          id: orderId,
          products: const [],
          displayEntries: const [],
          itemCount: 0,
          total: OrderMapper.formatPrice('0'),
        );
      }
      apiLog.writeln(
        '── Reopen left status=${updated['status']} — will recreate ──',
      );
    } catch (e) {
      apiLog.writeln('── Reopen failed: $e ──');
    }

    // 2) Recreate / adopt a live open order for this table.
    return _recreateEmptyOpenOrderForTable(
      oldOrderId: orderId,
      detail: detail,
      tableNumberHint: tableNumberHint,
      apiLog: apiLog,
    );
  }

  Future<SessionOrder> _recreateEmptyOpenOrderForTable({
    required int oldOrderId,
    required Map<String, dynamic>? detail,
    required StringBuffer apiLog,
    String? tableNumberHint,
  }) async {
    final source = detail ?? cachedOrderDetail(oldOrderId);
    if (source != null) {
      final replacement = await _ensureRemoteEmptyOpenOrder(
        oldOrderId: oldOrderId,
        detail: source,
        tableNumberHint: tableNumberHint,
      );
      if (replacement != null && replacement.id > 0) {
        // Refuse a cancelled id disguised as open.
        if (replacement.id != oldOrderId ||
            await _remoteOrderIsUsableOpen(replacement.id)) {
          return replacement;
        }
        apiLog.writeln(
          '── Recreate returned unusable id=${replacement.id} — retry hard ──',
        );
      }
    }

    // Hard path: free the table then create a brand-new empty order.
    final tableKey = tableNumberHint ??
        (source == null
            ? null
            : OrderMapper.displayKey(
                orderId: oldOrderId,
                tableNumber: OrderMapper.tableNumberFromDetail(source),
              ));
    final waiterId = source == null
        ? null
        : OrderMapper.waiterIdFromOrderMap(source);
    if (tableKey != null &&
        tableKey.isNotEmpty &&
        waiterId != null &&
        waiterId > 0) {
      apiLog.writeln(
        '── Hard recreate: retire $oldOrderId then createTableOrder $tableKey ──',
      );
      await _retireDeadOrderShell(oldOrderId, apiLog: apiLog);
      try {
        final guests =
            (source?['number_of_guests'] as num?)?.toInt() ?? 1;
        final created = await createTableOrder(
          tableNumber: tableKey,
          waiterId: waiterId,
          numberOfGuests: guests < 1 ? 1 : guests,
          salesZoneId: (source?['sales_zone_id'] as num?)?.toInt(),
        );
        final order = created.order;
        if (order.id > 0) {
          _rememberEmptyShellDisplay(order.id);
          clearPendingLocalDeleteFlag(order.id);
          return order.copyWith(
            products: const [],
            displayEntries: const [],
            itemCount: 0,
            total: OrderMapper.formatPrice('0'),
          );
        }
      } on ApiException catch (e) {
        apiLog.writeln('── Hard createTableOrder failed: ${e.message} ──');
        if (_isTableHasActiveOrderError(e)) {
          final activeId = await resolveOrderIdForTableNumber(tableKey);
          if (activeId != null && activeId > 0 && activeId != oldOrderId) {
            final adopted = await _adoptActiveOrderAsEmptyShell(
              orderId: activeId,
              apiLog: apiLog,
            );
            if (adopted != null) return adopted;
          }
        }
      } catch (e) {
        apiLog.writeln('── Hard recreate failed: $e ──');
      }
    }

    // Last adopt attempt for any other active id on the table.
    if (tableKey != null && tableKey.isNotEmpty) {
      final activeId = await resolveOrderIdForTableNumber(tableKey);
      if (activeId != null && activeId > 0 && activeId != oldOrderId) {
        final adopted = await _adoptActiveOrderAsEmptyShell(
          orderId: activeId,
          apiLog: apiLog,
        );
        if (adopted != null) return adopted;
      }
    }

    // Local placeholder only — must not pretend the cancelled remote id works.
    // Mark empty-shell so the next add takes revive/recreate path.
    final local = OrderMapper.asOpenEmptyOrderShell(
      source ??
          <String, dynamic>{
            'id': oldOrderId,
            'status': 'open',
            'payment_status': 'not_paid',
            'seat_orders': [
              {
                'seat_number': 1,
                'courses': [
                  {
                    'id': 0,
                    'course_number': 1,
                    'items': <dynamic>[],
                  },
                ],
              },
            ],
          },
    );
    local['status'] = 'open';
    await _local.saveOrderDetail(oldOrderId, local);
    await _sessionLocal.upsertOpenOrderInList(local);
    _rememberEmptyShellDisplay(oldOrderId);
    apiLog.writeln(
      '── WARNING: local empty shell only for id=$oldOrderId '
      '(next add must recreate) ──',
    );
    lastAddItemLog = apiLog.toString();
    return OrderMapper.fromOrderDetail(local).copyWith(
      id: oldOrderId,
      products: const [],
      displayEntries: const [],
      itemCount: 0,
      total: OrderMapper.formatPrice('0'),
    );
  }

  Future<bool> _remoteOrderIsUsableOpen(int orderId) async {
    try {
      final detail = await _remote.fetchOrderDetail(orderId);
      return !OrderMapper.isOrderClosedOrCancelled(detail) &&
          !OrderMapper.isOrderFullyPaid(detail) &&
          OrderMapper.isActiveDayOpenOrder(detail);
    } catch (_) {
      return false;
    }
  }

  Future<SessionOrder> cancelOrderLineAtIndex({
    required int orderId,
    required int lineIndex,
    int? itemId,
    List<OrderDisplayEntry>? previousDisplayEntries,
    String? tableNumber,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      apiLog.writeln('Hors ligne — annulation article impossible.');
      _logDeleteTrace(
        apiLog,
        phase: 'api_error',
        orderId: orderId,
        tableNumber: tableNumber,
        lineIndex: lineIndex,
        itemId: itemId,
        error: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
      throw ApiException(
        message: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Annulation article ──');
    apiLog.writeln(
      'order_id=$orderId line_index=$lineIndex item_id=${itemId ?? '—'}',
    );

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);
      final localMutated = OrderMapper.copyOrderDetail(detail);

      // Prefer stable item id — line indexes shift while deletes/adds race.
      // Never fall back to line_index when item_id was provided: that can
      // cancel the wrong (newly added) line after a quick add.
      var cancelled = false;
      if (itemId != null && itemId > 0) {
        cancelled = OrderMapper.cancelOrderLineByItemId(localMutated, itemId);
        apiLog.writeln(
          cancelled
              ? '── Cancel by item_id=$itemId ──'
              : '── item_id=$itemId already absent ──',
        );
      } else {
        final before = OrderMapper.countVisibleLineItems(localMutated);
        OrderMapper.cancelOrderLineAtIndex(
          orderDetail: localMutated,
          lineIndex: lineIndex,
        );
        cancelled =
            OrderMapper.countVisibleLineItems(localMutated) < before;
        apiLog.writeln(
          cancelled
              ? '── Cancel by line_index=$lineIndex ──'
              : '── line_index=$lineIndex already absent (noop) ──',
        );
      }

      // Last visible line: strip keep-open (never cancel-all lines — that
      // auto-cancels the order on this API → ORDER ID not found).
      if (OrderMapper.orderDetailHasNoVisibleItems(localMutated)) {
        apiLog.writeln(
          '── Last line → strip keep-open / recreate (not cancel) ──',
        );
        _logDeleteTrace(
          apiLog,
          phase: 'last_line',
          orderId: orderId,
          tableNumber: tableNumber,
          lineIndex: lineIndex,
          itemId: itemId,
        );
        return cancelAllVisibleLines(
          orderId: orderId,
          previousDisplayEntries: const [],
          tableNumber: tableNumber ??
              OrderMapper.displayKey(
                orderId: orderId,
                tableNumber: OrderMapper.tableNumberFromDetail(detail),
              ),
        );
      }

      if (!cancelled) {
        // Already gone on server — do not PUT / error; return mapped empty/current.
        _logDeleteTrace(
          apiLog,
          phase: 'api_ok',
          orderId: orderId,
          tableNumber: tableNumber,
          lineIndex: lineIndex,
          itemId: itemId,
        );
        return _persistOrderAfterItemMutation(
          orderId: orderId,
          detail: localMutated,
          previousDisplayEntries: previousDisplayEntries,
        );
      }

      final payload = OrderMapper.buildOrderUpdatePayload(
        localMutated,
        keepOpenWhenEmpty: true,
      );
      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      _logDeleteTrace(
        apiLog,
        phase: 'api_ok',
        orderId: orderId,
        tableNumber: tableNumber,
        lineIndex: lineIndex,
        itemId: itemId,
      );

      final persisted = await _persistOrderAfterItemMutation(
        orderId: orderId,
        detail: updated,
        previousDisplayEntries: previousDisplayEntries,
        keepLinesIfApiEmpty: localMutated,
      );
      return persisted;
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      if (_isOrderNotFoundError(e)) {
        final kept = await _recreateEmptyOpenOrderForTable(
          oldOrderId: orderId,
          detail: cachedOrderDetail(orderId),
          tableNumberHint: tableNumber,
          apiLog: apiLog,
        );
        _logDeleteTrace(
          apiLog,
          phase: 'api_ok',
          orderId: kept.id > 0 ? kept.id : orderId,
          tableNumber: tableNumber,
          lineIndex: lineIndex,
          itemId: itemId,
        );
        _rememberEmptyShellDisplay(kept.id);
        clearPendingLocalDeleteFlag(kept.id);
        return kept;
      }
      _logDeleteTrace(
        apiLog,
        phase: 'api_error',
        orderId: orderId,
        tableNumber: tableNumber,
        lineIndex: lineIndex,
        itemId: itemId,
        error: e.message,
      );
      rethrow;
    }
  }

  /// Marks locally-deleted item ids as cancelled on a detail copy (in place).
  int _cancelSuppressedItemsInDetail(
    int orderId,
    Map<String, dynamic> detail,
    StringBuffer apiLog,
  ) {
    final suppressed = suppressedItemIdsFor(orderId);
    if (suppressed.isEmpty) return 0;
    var count = 0;
    for (final itemId in suppressed) {
      if (OrderMapper.cancelOrderLineByItemId(detail, itemId)) {
        count++;
      }
    }
    if (count > 0) {
      apiLog.writeln(
        '── Stripped $count suppressed deleted item(s) before add PUT ──',
      );
    }
    return count;
  }

  ({List<int> splits, int count, Set<int> demandedSections})
      _resolveSuivreHints(
    int orderId, {
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final fromHive = (
      splits: _local.readSuivreSplitHint(orderId),
      count: _local.readSuivreCountHint(orderId),
      demandedSections: _local.readDemandedSectionHint(orderId),
    );

    // When the UI passes layout hints, trust them when they still carry suites.
    if (layoutHints != null) {
      final fromLayout = (
        splits: OrderMapper.suivreSplitPositions(layoutHints),
        count: OrderMapper.sectionDividerCount(layoutHints),
        demandedSections:
            OrderMapper.demandedSectionIndicesFromEntries(layoutHints),
      );

      final layoutHasSuites = fromLayout.count > 0 || fromLayout.splits.isNotEmpty;
      final hiveHasSuites = fromHive.count > 0 || fromHive.splits.isNotEmpty;

      // Session list rows are often flat — keep Hive waiter layout when richer.
      if (hiveHasSuites &&
          (!layoutHasSuites || fromLayout.count < fromHive.count)) {
        return (
          splits: fromHive.splits,
          count: fromHive.count,
          demandedSections: {
            ...fromHive.demandedSections,
            ...fromLayout.demandedSections,
          },
        );
      }

      return (
        splits: fromLayout.splits,
        count: fromLayout.count,
        demandedSections: {
          ...fromLayout.demandedSections,
          ...fromHive.demandedSections,
        },
      );
    }

    return fromHive;
  }

  void _ensureAddItemCourse(
    Map<String, dynamic> detail,
    StringBuffer apiLog, {
    required int orderId,
    List<OrderDisplayEntry>? layoutHints,
  }) {
    // No visible lines → ignore stale À SUIVRE hints (always restart course 1).
    final emptyTicket = OrderMapper.orderDetailHasNoVisibleItems(detail);
    final effectiveLayout =
        emptyTicket ? null : OrderMapper.coalesceLayoutHints(layoutHints);
    final suivreHints = emptyTicket
        ? (splits: const <int>[], count: 0, demandedSections: const <int>{})
        : _resolveSuivreHints(orderId, layoutHints: effectiveLayout);

    OrderMapper.ensureMinimalSeatCourseStructure(detail);

    final seatNumber = OrderMapper.resolveDefaultSeatNumber(detail);
    final course = OrderMapper.resolveAppendCourse(
      detail,
      seatNumber: seatNumber,
      suivreSectionCount: suivreHints.count,
      suivreSplitHints: suivreHints.splits,
      layoutHints: effectiveLayout,
    );

    final courseNumber = course.number > 0 ? course.number : 1;
    if (course.number <= 0) {
      apiLog.writeln(
        'WARN: course_number<=0 after empty ticket — forcing course 1',
      );
    }

    apiLog.writeln(
      'seat_number=$seatNumber course_id=${course.id ?? '—'} '
      'course_number=$courseNumber',
    );
  }

  Future<SessionOrder> _fetchAndMapOrder(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    return getOrderDetail(
      orderId,
      previousDisplayEntries: previousDisplayEntries,
    );
  }

  /// Maps an in-memory order detail without an extra network round-trip.
  SessionOrder _mapDetailToSessionOrder(
    int orderId,
    Map<String, dynamic> detail, {
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) {
    final suivreHints = _resolveSuivreHints(
      orderId,
      layoutHints: previousDisplayEntries,
    );
    final order = OrderMapper.fromOrderDetail(
      detail,
      previousDisplayEntries: previousDisplayEntries,
      suivreSplitHints: suivreHints.splits,
      suivreCountHint: suivreHints.count,
      demandedSectionIndices: suivreHints.demandedSections,
    );
    unawaited(_persistSuivreLayoutHints(orderId, order.displayEntries));
    return order.copyWith(id: orderId);
  }

  Future<Map<String, dynamic>> _putOrderUpdate({
    required int orderId,
    required Map<String, dynamic> payload,
    required StringBuffer apiLog,
  }) async {
    apiLog.writeln('── PUT /api/orders/$orderId ──');
    apiLog.writeln(formatApiPayload(payload));

    final updated = await _remote.updateOrder(orderId, payload);
    if (_remote.lastApiLog != null) {
      apiLog.writeln(_remote.lastApiLog);
    }
    return updated;
  }

  void _logDeleteTrace(
    StringBuffer apiLog, {
    required String phase,
    int? orderId,
    String? tableNumber,
    int? lineIndex,
    int? itemId,
    String? error,
  }) {
    lastAddItemLog = apiLog.toString();
    logOrderDelete(
      phase: phase,
      orderId: orderId,
      tableNumber: tableNumber,
      lineIndex: lineIndex,
      itemId: itemId,
      apiTrace: apiLog.toString(),
      error: error,
    );
  }

  /// Persists a post-mutation order. Empty shells stay open in the session list;
  /// only [closeOrder] (delete icon) removes them.
  ///
  /// When the backend auto-closes / fully-pays an emptied order, we keep a
  /// local session placeholder (API rejects empty POST /api/orders).
  Future<SessionOrder> _persistOrderAfterItemMutation({
    required int orderId,
    required Map<String, dynamic> detail,
    List<OrderDisplayEntry>? previousDisplayEntries,
    Map<String, dynamic>? keepLinesIfApiEmpty,
  }) async {
    var working = detail;

    // Prefer a fresh GET so cancelled lines are authoritative.
    try {
      working = await _remote.fetchOrderDetail(orderId);
    } catch (_) {}

    // Incomplete PUT/GET (or offered lock) can look empty while lines still exist.
    // Keep the locally mutated detail so the ticket does not flash blank.
    if (OrderMapper.orderDetailHasNoVisibleItems(working) &&
        keepLinesIfApiEmpty != null &&
        !OrderMapper.orderDetailHasNoVisibleItems(keepLinesIfApiEmpty)) {
      working = keepLinesIfApiEmpty;
    } else if (OrderMapper.orderDetailHasNoVisibleItems(working)) {
      // Backend often marks emptied orders cancelled/closed. Reopen same id,
      // or recreate / adopt the table's active order so re-add keeps working.
      if (OrderMapper.shouldRecreateOrderForAdd(working) ||
          !OrderMapper.isActiveDayOpenOrder(working) ||
          OrderMapper.isOrderClosedOrCancelled(working) ||
          OrderMapper.isOrderFullyPaid(working)) {
        final apiLog = StringBuffer('── Persist empty shell reopen/recreate ──\n');
        final kept = await _reopenOrRecreateEmptyOrder(
          orderId: orderId,
          detail: working,
          apiLog: apiLog,
          tableNumberHint: OrderMapper.displayKey(
            orderId: orderId,
            tableNumber: OrderMapper.tableNumberFromDetail(working),
          ),
        );
        lastAddItemLog = '${lastAddItemLog ?? ''}\n$apiLog';
        return kept;
      }

      working = OrderMapper.asOpenEmptyOrderShell(working);
    }

    await _local.saveOrderDetail(orderId, working);
    await _sessionLocal.upsertOpenOrderInList(working);

    final layoutHints =
        OrderMapper.coalesceLayoutHints(previousDisplayEntries);
    final suivreHints = _resolveSuivreHints(orderId, layoutHints: layoutHints);

    final order = OrderMapper.fromOrderDetail(
      working,
      previousDisplayEntries: layoutHints,
      suivreSplitHints: suivreHints.splits,
      suivreCountHint: suivreHints.count,
      demandedSectionIndices: suivreHints.demandedSections,
    );

    // Empty shell: clear À SUIVRE hints so the next add targets course 1 / seat
    // again (stale suite hints caused "seat" / "aucune suite" errors on re-add).
    if (OrderMapper.orderDetailHasNoVisibleItems(working)) {
      final empty = order.copyWith(
        products: const [],
        displayEntries: const [],
        total: OrderMapper.formatPrice('0'),
      );
      await _persistSuivreLayoutHints(orderId, empty.displayEntries);
      return empty;
    }

    await _persistSuivreLayoutHints(orderId, order.displayEntries);
    return order;
  }

  /// After the backend auto-closes/pays an emptied order, open a fresh empty
  /// remote order so it stays in GET /api/orders / the session list.
  ///
  /// Never retire [oldOrderId] until a usable replacement exists — closing
  /// first leaves the table with no order id and causes "ORDER ID not found".
  Future<SessionOrder?> _ensureRemoteEmptyOpenOrder({
    required int oldOrderId,
    required Map<String, dynamic> detail,
    String? tableNumberHint,
  }) async {
    final apiLog = StringBuffer();
    apiLog.writeln(
      '── Ensure remote empty open order (old_id=$oldOrderId) ──',
    );

    final tableId = (detail['table_id'] as num?)?.toInt();
    final tableNumber = OrderMapper.tableNumberFromDetail(detail) ??
        int.tryParse(
          (tableNumberHint ?? '').replaceFirst(RegExp(r'^T'), '').trim(),
        );
    final waiterId = OrderMapper.waiterIdFromOrderMap(detail);
    final guests = (detail['number_of_guests'] as num?)?.toInt() ?? 1;
    final salesZoneId = (detail['sales_zone_id'] as num?)?.toInt() ??
        (detail['sales_zone'] is Map<String, dynamic>
            ? ((detail['sales_zone'] as Map<String, dynamic>)['id'] as num?)
                ?.toInt()
            : null);

    if (tableNumber == null || tableNumber <= 0) {
      apiLog.writeln('── Missing table number — cannot recreate empty order ──');
      lastAddItemLog = apiLog.toString();
      return null;
    }

    // 1) Prefer adopting whatever the table already considers active.
    final existingActive =
        await resolveOrderIdForTableNumber('$tableNumber');
    if (existingActive != null &&
        existingActive > 0 &&
        existingActive != oldOrderId) {
      apiLog.writeln(
        '── Table already has active order $existingActive — adopt ──',
      );
      final adopted = await _adoptActiveOrderAsEmptyShell(
        orderId: existingActive,
        apiLog: apiLog,
      );
      if (adopted != null) {
        unawaited(_retireDeadOrderShell(oldOrderId, apiLog: apiLog));
        lastAddItemLog = apiLog.toString();
        return adopted;
      }
    }

    if (tableId == null ||
        tableId <= 0 ||
        waiterId == null ||
        waiterId <= 0) {
      // Still try adopt the same id (reopen) if create metadata is missing.
      if (existingActive != null && existingActive > 0) {
        final adopted = await _adoptActiveOrderAsEmptyShell(
          orderId: existingActive,
          apiLog: apiLog,
        );
        if (adopted != null) {
          lastAddItemLog = apiLog.toString();
          return adopted;
        }
      }
      apiLog.writeln('── Missing table/waiter — cannot recreate empty order ──');
      lastAddItemLog = apiLog.toString();
      return null;
    }

    final table = ResolvedTable(
      id: tableId,
      tableNumber: tableNumber,
      salesZoneId: salesZoneId,
    );

    await _tryStartTableSession(
      table: table,
      waiterId: waiterId,
      numberOfGuests: guests < 1 ? 1 : guests,
      apiLog: apiLog,
    );

    // 2) Create a new empty open order WITHOUT retiring the old shell first.
    Map<String, dynamic>? createdPayload =
        await _postCreateEmptyOrderRecord(
      table: table,
      waiterId: waiterId,
      numberOfGuests: guests < 1 ? 1 : guests,
      salesZoneId: salesZoneId,
      apiLog: apiLog,
    );

    Future<SessionOrder?> adoptOrNull(int? activeId) async {
      if (activeId == null || activeId <= 0) return null;
      final adopted = await _adoptActiveOrderAsEmptyShell(
        orderId: activeId,
        apiLog: apiLog,
      );
      if (adopted == null) return null;
      if (adopted.id != oldOrderId) {
        unawaited(_retireDeadOrderShell(oldOrderId, apiLog: apiLog));
      }
      lastAddItemLog = apiLog.toString();
      return adopted;
    }

    if (createdPayload == null) {
      apiLog.writeln(
        '── Create empty returned null — try adopt / retire+retry ──',
      );
      final activeId = await resolveOrderIdForTableNumber('$tableNumber');
      final adopted = await adoptOrNull(
        (activeId != null && activeId != oldOrderId) ? activeId : null,
      );
      if (adopted != null) return adopted;

      // Table still locked to the cancelled shell — free it and create again.
      await _retireDeadOrderShell(oldOrderId, apiLog: apiLog);
      createdPayload = await _postCreateEmptyOrderRecord(
        table: table,
        waiterId: waiterId,
        numberOfGuests: guests < 1 ? 1 : guests,
        salesZoneId: salesZoneId,
        apiLog: apiLog,
      );
      if (createdPayload == null) {
        final retryActive =
            await resolveOrderIdForTableNumber('$tableNumber');
        final retryAdopted = await adoptOrNull(retryActive);
        if (retryAdopted != null) return retryAdopted;
        lastAddItemLog = apiLog.toString();
        return null;
      }
    }

    final newId = OrderMapper.extractOrderIdFromPayload(createdPayload!);
    if (newId == null || newId <= 0) {
      final activeId = await resolveOrderIdForTableNumber('$tableNumber');
      final adopted = await adoptOrNull(
        (activeId != null && activeId != oldOrderId) ? activeId : null,
      );
      if (adopted != null) return adopted;
      lastAddItemLog = apiLog.toString();
      return null;
    }

    var fresh = OrderMapper.unwrapOrderDetail(createdPayload!);
    if (OrderMapper.orderIdFromDetail(fresh) != newId) {
      fresh = await _remote.fetchOrderDetail(newId);
    }
    if (!OrderMapper.orderDetailHasNoVisibleItems(fresh)) {
      fresh = await _clearVisibleItemsKeepOpen(newId, fresh, apiLog);
    }

    final shell = OrderMapper.asOpenEmptyOrderShell(fresh);
    shell['status'] = 'open';
    shell['payment_status'] = 'not_paid';
    shell['payment_status_detailed'] = 'not_paid';
    await _local.saveOrderDetail(newId, shell);
    await _sessionLocal.upsertOpenOrderInList(shell);

    // 3) Only now drop the dead shell — replacement is already usable.
    if (newId != oldOrderId) {
      unawaited(_retireDeadOrderShell(oldOrderId, apiLog: apiLog));
    }

    final order = OrderMapper.fromOrderDetail(shell).copyWith(
      id: newId,
      products: const [],
      displayEntries: const [],
      total: OrderMapper.formatPrice('0'),
    );
    apiLog.writeln('── Empty remote order ready id=$newId ──');
    lastAddItemLog = apiLog.toString();
    return order;
  }

  /// Reopen [orderId] as an empty open shell (no recreate — avoids loops).
  ///
  /// Returns null when the API still reports cancelled/closed/missing — callers
  /// must recreate instead of trusting a locally forced status=open.
  Future<SessionOrder?> _adoptActiveOrderAsEmptyShell({
    required int orderId,
    required StringBuffer apiLog,
  }) async {
    try {
      var detail = await _remote.fetchOrderDetail(orderId);
      var shell = OrderMapper.asOpenEmptyOrderShell(detail);
      final reopenPayload = OrderMapper.buildOrderUpdatePayload(
        shell,
        keepOpenWhenEmpty: true,
      );
      reopenPayload['status'] = 'open';
      reopenPayload['payment_status'] = 'not_paid';
      reopenPayload['payment_status_detailed'] = 'not_paid';
      apiLog.writeln('── PUT adopt/reopen active order $orderId ──');
      await _remote.updateOrder(orderId, reopenPayload);
      Map<String, dynamic> updated;
      try {
        updated = await _remote.fetchOrderDetail(orderId);
      } on ApiException catch (e) {
        apiLog.writeln('── Adopt GET failed: ${e.message} ──');
        return null;
      }
      if (OrderMapper.isOrderClosedOrCancelled(updated) ||
          OrderMapper.isOrderFullyPaid(updated) ||
          !OrderMapper.isActiveDayOpenOrder(updated)) {
        apiLog.writeln(
          '── Adopt left status=${updated['status']} — refuse cancelled id ──',
        );
        return null;
      }
      shell = OrderMapper.asOpenEmptyOrderShell(updated);
      shell['status'] = 'open';
      shell['payment_status'] = 'not_paid';
      shell['payment_status_detailed'] = 'not_paid';
      await _local.saveOrderDetail(orderId, shell);
      await _sessionLocal.upsertOpenOrderInList(shell);
      return OrderMapper.fromOrderDetail(shell).copyWith(
        id: orderId,
        products: const [],
        displayEntries: const [],
        itemCount: 0,
        total: OrderMapper.formatPrice('0'),
      );
    } catch (e) {
      apiLog.writeln('── Adopt active order failed: $e ──');
      return null;
    }
  }

  Future<Map<String, dynamic>> _clearVisibleItemsKeepOpen(
    int orderId,
    Map<String, dynamic> detail,
    StringBuffer apiLog,
  ) async {
    // Prefer strip items:[] + force open. Do NOT cancel items — cancelling
    // the seed auto-cancels the whole order on this API.
    var working = detail;
    for (var attempt = 1; attempt <= 3; attempt++) {
      if (OrderMapper.orderDetailHasNoVisibleItems(working)) {
        return OrderMapper.asOpenEmptyOrderShell(working);
      }

      final stripPayload = OrderMapper.stripAllVisibleItems(working);
      apiLog.writeln(
        '── PUT /api/orders/$orderId '
        '(strip seed items:[], keep open, attempt $attempt) ──',
      );
      apiLog.writeln(formatApiPayload(stripPayload));

      try {
        working = await _remote.updateOrder(orderId, stripPayload);
        // Skip extra GET when PUT already returned an empty open shell.
        if (!OrderMapper.orderDetailHasNoVisibleItems(working)) {
          try {
            working = await _remote.fetchOrderDetail(orderId);
          } on ApiException catch (e) {
            if (_isOrderNotFoundError(e)) rethrow;
          } catch (_) {}
        }
      } on ApiException catch (e) {
        apiLog.writeln('── strip attempt $attempt failed: $e ──');
        if (_isOrderNotFoundError(e)) rethrow;
        try {
          working = await _remote.fetchOrderDetail(orderId);
        } on ApiException catch (fetchError) {
          if (_isOrderNotFoundError(fetchError)) rethrow;
        } catch (_) {}
      } catch (e) {
        apiLog.writeln('── strip attempt $attempt failed: $e ──');
        try {
          working = await _remote.fetchOrderDetail(orderId);
        } on ApiException catch (fetchError) {
          if (_isOrderNotFoundError(fetchError)) rethrow;
        } catch (_) {}
      }

      if (OrderMapper.orderDetailHasNoVisibleItems(working)) {
        // Force open/unpaid if backend drifted.
        if (OrderMapper.isOrderClosedOrCancelled(working) ||
            OrderMapper.isOrderFullyPaid(working)) {
          try {
            final reopen = OrderMapper.buildOrderUpdatePayload(
              OrderMapper.asOpenEmptyOrderShell(working),
              keepOpenWhenEmpty: true,
            );
            reopen['status'] = 'open';
            reopen['payment_status'] = 'not_paid';
            reopen['payment_status_detailed'] = 'not_paid';
            working = await _remote.updateOrder(orderId, reopen);
            if (!OrderMapper.orderDetailHasNoVisibleItems(working) ||
                OrderMapper.isOrderClosedOrCancelled(working) ||
                OrderMapper.isOrderFullyPaid(working)) {
              try {
                working = await _remote.fetchOrderDetail(orderId);
              } on ApiException catch (e) {
                if (_isOrderNotFoundError(e)) rethrow;
              } catch (_) {}
            }
          } on ApiException catch (e) {
            if (_isOrderNotFoundError(e)) rethrow;
          } catch (_) {}
        }
        return OrderMapper.asOpenEmptyOrderShell(working);
      }
    }

    if (!OrderMapper.orderDetailHasNoVisibleItems(working)) {
      apiLog.writeln(
        '── WARNING: visible items remain after clear '
        '(count=${OrderMapper.countVisibleLineItems(working)}) ──',
      );
    }
    return OrderMapper.asOpenEmptyOrderShell(working);
  }

  bool _isOrderNotFoundError(ApiException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == 404 ||
        message.contains('not found') ||
        message.contains('introuvable') ||
        message.contains('order id');
  }

  /// After qty/offer-style mutations: refresh from API but never empty-shell /
  /// recreate the order when lines were only adjusted.
  Future<SessionOrder> _persistOrderAfterLineEdit({
    required int orderId,
    required Map<String, dynamic> putResponse,
    required Map<String, dynamic> localMutated,
    required int beforeVisibleCount,
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    var working = putResponse;
    try {
      working = await _remote.fetchOrderDetail(orderId);
    } catch (_) {}

    final localCount = OrderMapper.countVisibleLineItems(localMutated);
    final apiCount = OrderMapper.countVisibleLineItems(working);

    // Qty edits must not wipe the ticket. If API looks empty/partial vs local,
    // keep the locally mutated detail (items still exist — reopen proves it).
    if (beforeVisibleCount > 0 &&
        localCount > 0 &&
        (apiCount == 0 || apiCount < localCount)) {
      working = localMutated;
    }

    bumpDetailRevision(orderId);
    _forgetEmptyShellDisplay(orderId);
    await _local.saveOrderDetail(orderId, working);
    await _sessionLocal.upsertOpenOrderInList(working);

    final suivreHints = _resolveSuivreHints(
      orderId,
      layoutHints: previousDisplayEntries,
    );

    final order = OrderMapper.fromOrderDetail(
      working,
      previousDisplayEntries: previousDisplayEntries,
      suivreSplitHints: suivreHints.splits,
      suivreCountHint: suivreHints.count,
      demandedSectionIndices: suivreHints.demandedSections,
    );

    // Last resort: never return an empty SessionOrder when we still have lines.
    if (order.products.isEmpty && localCount > 0) {
      final fallback = OrderMapper.fromOrderDetail(
        localMutated,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: suivreHints.splits,
        suivreCountHint: suivreHints.count,
        demandedSectionIndices: suivreHints.demandedSections,
      );
      await _persistSuivreLayoutHints(orderId, fallback.displayEntries);
      return fallback;
    }

    await _persistSuivreLayoutHints(orderId, order.displayEntries);
    return order;
  }

  Future<SessionOrder> adjustOrderLineQuantityAtIndex({
    required int orderId,
    required int lineIndex,
    required int delta,
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — mise à jour quantité impossible.';
      throw ApiException(
        message: 'Modification impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Ajustement quantité ligne ──');
    apiLog.writeln('order_id=$orderId line_index=$lineIndex delta=$delta');

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);
      final beforeCount = OrderMapper.countVisibleLineItems(detail);
      final localMutated = OrderMapper.copyOrderDetail(detail);
      final payload = OrderMapper.adjustLineQuantityAtIndex(
        orderDetail: localMutated,
        lineIndex: lineIndex,
        delta: delta,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      lastAddItemLog = apiLog.toString();

      return _persistOrderAfterLineEdit(
        orderId: orderId,
        putResponse: updated,
        localMutated: localMutated,
        beforeVisibleCount: beforeCount,
        previousDisplayEntries: previousDisplayEntries,
      );
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  Future<SessionOrder> applyOfferAtLineIndex({
    required int orderId,
    required int lineIndex,
  }) async {
    return _mutateOrderLine(
      orderId: orderId,
      logTitle: 'Offre article',
      mutate: (detail) => OrderMapper.applyOfferAtLineIndex(
        orderDetail: detail,
        lineIndex: lineIndex,
      ),
    );
  }

  Future<SessionOrder> updateOrderLineCommentAtIndex({
    required int orderId,
    required int lineIndex,
    required String comment,
  }) async {
    return _mutateOrderLine(
      orderId: orderId,
      logTitle: 'Message article',
      mutate: (detail) => OrderMapper.updateLineCommentAtIndex(
        orderDetail: detail,
        lineIndex: lineIndex,
        comment: comment,
      ),
    );
  }

  Future<SessionOrder> requestAllCourses(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Envoi impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final apiLog = StringBuffer();
    lastKitchenSendLog = null;

    apiLog.writeln('── Envoyer en cuisine ──');
    apiLog.writeln('order_id=$orderId');

    try {
      apiLog.writeln('── GET /api/orders/$orderId (current) ──');
      var detail = await _remote.fetchOrderDetail(orderId);
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }

      if (previousDisplayEntries != null &&
          previousDisplayEntries.isNotEmpty &&
          (OrderMapper.layoutHasProductsUnderPendingSuivre(
                previousDisplayEntries,
              ) ||
              OrderMapper.suivreSeparatorCount(previousDisplayEntries) > 0 ||
              OrderMapper.sectionDividerCount(previousDisplayEntries) > 0)) {
        final aligned = OrderMapper.alignPendingSuivreLayoutOntoCourses(
          detail,
          layout: previousDisplayEntries,
        );
        if (aligned.changed) {
          apiLog.writeln('── Align local suite layout onto courses (PUT) ──');
          detail = await _putOrderUpdate(
            orderId: orderId,
            payload: OrderMapper.buildOrderUpdatePayload(aligned.detail),
            apiLog: apiLog,
          );
          await _local.saveOrderDetail(orderId, detail);
          detail = await _remote.fetchOrderDetail(orderId);
          await _local.saveOrderDetail(orderId, detail);
        }
      }

      if (OrderMapper.orderDetailHasNoVisibleItems(detail)) {
        throw ApiException(
          message: 'Aucun article à envoyer en cuisine pour cette table.',
        );
      }

      apiLog.writeln(
        '── Envoyer: alignement local uniquement (pas de request-courses) ──',
      );
      lastKitchenSendLog = apiLog.toString();
      print(lastKitchenSendLog);
      debugPrint(lastKitchenSendLog!);

      // Envoyer does not fire request-courses — only manual Demande does.
      final demandedHint = OrderMapper.demandedSectionIndicesFromEntries(
        previousDisplayEntries ?? const [],
      );
      final suivreHints = _resolveSuivreHints(
        orderId,
        layoutHints: previousDisplayEntries,
      );
      final order = OrderMapper.fromOrderDetail(
        detail,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: suivreHints.splits,
        suivreCountHint: suivreHints.count,
        demandedSectionIndices: {
          ...suivreHints.demandedSections,
          ...demandedHint,
        },
        applyKitchenDemande: false,
      );
      await _persistSuivreLayoutHints(orderId, order.displayEntries);
      await _sessionLocal.upsertOpenOrderInList(detail);
      return order;
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastKitchenSendLog = apiLog.toString();
      print(lastKitchenSendLog);
      debugPrint(lastKitchenSendLog!);
      rethrow;
    } catch (e) {
      apiLog.writeln('ERREUR: $e');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastKitchenSendLog = apiLog.toString();
      print(lastKitchenSendLog);
      debugPrint(lastKitchenSendLog!);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentModes({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedPaymentModes.isNotEmpty) {
      return _cachedPaymentModes;
    }

    if (!await _connectivity.isOnline) {
      if (_cachedPaymentModes.isNotEmpty) return _cachedPaymentModes;
      throw ApiException(
        message: 'Modes de paiement indisponibles hors ligne.',
      );
    }

    try {
      final modes = await _remote.fetchPaymentModes();
      final active = OrderMapper.activePaymentModes(modes);
      final resolved = active.isEmpty ? modes : active;
      if (resolved.isEmpty) {
        throw ApiException(
          message: 'Aucun mode de paiement actif configuré.',
        );
      }

      _cachedPaymentModes = resolved;
      lastPaymentModesLog = _remote.lastApiLog;
      return resolved;
    } on ApiException {
      lastPaymentModesLog = _remote.lastApiLog;
      rethrow;
    }
  }

  Future<SessionOrder> payOrder({
    required int orderId,
    required bool isCash,
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    final apiLog = StringBuffer();
    lastPaymentLog = null;

    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Paiement impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Paiement commande ──');
    apiLog.writeln('order_id=$orderId isCash=$isCash');

    try {
      var detail = await _fetchOrderDetailForPayment(orderId, apiLog);

      // Align local suite layout before payment (no request-courses here).
      try {
        apiLog.writeln('── Alignement layout (requestAllCourses) avant paiement ──');
        await requestAllCourses(orderId);
        if (lastKitchenSendLog != null) {
          apiLog.writeln(lastKitchenSendLog);
        }
        detail = await _remote.fetchOrderDetail(orderId);
      } on ApiException catch (e) {
        apiLog.writeln('── requestAllCourses avant paiement: ${e.message} ──');
      }

      detail = await _ensureKitchenSentBeforePayment(
        orderId,
        detail,
        apiLog,
        forceAllVisibleCourses: true,
      );

      final amount = OrderMapper.formatPaymentAmount(
        OrderMapper.parseOrderPayableAmount(detail),
      );
      if (amount <= 0) {
        throw ApiException(message: 'Montant à encaisser invalide.');
      }

      apiLog.writeln('amount=$amount');

      final modes = await getPaymentModes();
      final paymentModeId =
          OrderMapper.resolvePaymentModeId(modes, isCash: isCash);
      if (paymentModeId == null) {
        throw ApiException(
          message: isCash
              ? 'Mode espèces introuvable. Vérifiez la configuration caisse.'
              : 'Mode carte introuvable. Vérifiez la configuration caisse.',
        );
      }

      detail = await _postOrderPayment(
        orderId: orderId,
        amount: amount,
        paymentModeId: paymentModeId,
        apiLog: apiLog,
        detail: detail,
      );

      apiLog.writeln('── GET /api/orders/$orderId (after pay) ──');
      Map<String, dynamic> updated;
      try {
        updated = await _remote.fetchOrderDetail(orderId);
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
      } catch (e) {
        // Payment already succeeded — don't fail the UI if refresh is denied
        // (some backends hide paid/closed orders from waiter GET).
        apiLog.writeln('── GET after pay skipped: $e ──');
        updated = Map<String, dynamic>.from(detail);
        updated['payment_status'] = 'paid';
        updated['payment_status_detailed'] = 'fully_paid';
        updated['remaining_amount'] = 0;
        updated['status'] = updated['status'] ?? 'closed';
      }

      await _local.saveOrderDetail(orderId, updated);
      lastPaymentLog = apiLog.toString();
      print(lastPaymentLog);
      debugPrint(lastPaymentLog!);

      final suivreHints = _resolveSuivreHints(
        orderId,
        layoutHints: previousDisplayEntries,
      );

      return OrderMapper.fromOrderDetail(
        updated,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: suivreHints.splits,
        suivreCountHint: suivreHints.count,
        demandedSectionIndices: suivreHints.demandedSections,
      );
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastPaymentLog = apiLog.toString();
      print(lastPaymentLog);
      debugPrint(lastPaymentLog!);
      rethrow;
    } catch (e) {
      apiLog.writeln('ERREUR: $e');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastPaymentLog = apiLog.toString();
      print(lastPaymentLog);
      debugPrint(lastPaymentLog!);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchOrderDetailForPayment(
    int orderId,
    StringBuffer apiLog,
  ) async {
    apiLog.writeln('── GET /api/orders/$orderId ──');
    final detail = await _remote.fetchOrderDetail(orderId);
    if (_remote.lastApiLog != null) {
      apiLog.writeln(_remote.lastApiLog);
    }
    return detail;
  }

  Future<Map<String, dynamic>> _ensureKitchenSentBeforePayment(
    int orderId,
    Map<String, dynamic> detail,
    StringBuffer apiLog, {
    bool forceAllVisibleCourses = false,
  }) async {
    var courseIds = forceAllVisibleCourses
        ? OrderMapper.extractAllVisibleCourseIds(detail)
        : OrderMapper.extractCourseIdsPendingKitchenSendBeforePayment(detail);

    if (courseIds.isEmpty && !forceAllVisibleCourses) {
      // Soft miss — still try every visible course (API may require re-fire).
      courseIds = OrderMapper.extractAllVisibleCourseIds(detail);
    }
    if (courseIds.isEmpty) return detail;

    apiLog.writeln(
      forceAllVisibleCourses
          ? '── Envoi cuisine FORCE (tous services) avant paiement ──'
          : '── Envoi cuisine avant paiement ──',
    );
    apiLog.writeln('course_ids=${courseIds.join(',')}');

    await _requestCoursesForPayment(
      orderId: orderId,
      courseIds: courseIds,
      apiLog: apiLog,
    );

    final updated = await _remote.fetchOrderDetail(orderId);
    if (_remote.lastApiLog != null) {
      apiLog.writeln(_remote.lastApiLog);
    }
    await _local.saveOrderDetail(orderId, updated);
    return updated;
  }

  Future<void> _requestCoursesForPayment({
    required int orderId,
    required List<int> courseIds,
    required StringBuffer apiLog,
  }) async {
    apiLog.writeln('── POST ${ApiEndpoints.requestCourses(orderId)} ──');
    apiLog.writeln(formatApiPayload({'course_ids': courseIds}));

    _remote.lastApiLog = null;
    try {
      await _remote.requestCourses(orderId, courseIds);
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      return;
    } on ApiException catch (e) {
      apiLog.writeln('── request-courses batch: ${e.message} ──');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
    }

    // Some tenants reject multi-id batches — fire each course alone.
    for (final courseId in courseIds) {
      apiLog.writeln(
        '── POST ${ApiEndpoints.requestCourses(orderId)} (course=$courseId) ──',
      );
      _remote.lastApiLog = null;
      try {
        await _remote.requestCourses(orderId, [courseId]);
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
      } on ApiException catch (e) {
        apiLog.writeln('── request-courses $courseId: ${e.message} ──');
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
      }
    }
  }

  Future<Map<String, dynamic>> _postOrderPayment({
    required int orderId,
    required double amount,
    required int paymentModeId,
    required StringBuffer apiLog,
    required Map<String, dynamic> detail,
  }) async {
    final requestBody = {
      'amount': amount,
      'payment_mode_id': paymentModeId,
    };

    apiLog.writeln('payment_mode_id=$paymentModeId');
    apiLog.writeln('── POST /api/orders/$orderId/pay ──');
    apiLog.writeln(formatApiPayload(requestBody));

    _remote.lastApiLog = null;
    try {
      await _remote.payOrder(
        orderId: orderId,
        amount: amount,
        paymentModeId: paymentModeId,
      );
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      return detail;
    } on ApiException catch (error) {
      if (!OrderMapper.isSendBeforePaymentError(error)) rethrow;

      apiLog.writeln(
        'Paiement refusé — envoi FORCE de tous les services puis nouvel essai.',
      );
      final refreshed = await _ensureKitchenSentBeforePayment(
        orderId,
        await _fetchOrderDetailForPayment(orderId, apiLog),
        apiLog,
        forceAllVisibleCourses: true,
      );

      final retryAmount = OrderMapper.formatPaymentAmount(
        OrderMapper.parseOrderPayableAmount(refreshed),
      );
      if (retryAmount <= 0) {
        throw ApiException(message: 'Montant à encaisser invalide.');
      }

      final retryBody = {
        'amount': retryAmount,
        'payment_mode_id': paymentModeId,
      };
      apiLog.writeln('── POST /api/orders/$orderId/pay (retry) ──');
      apiLog.writeln(formatApiPayload(retryBody));

      _remote.lastApiLog = null;
      try {
        await _remote.payOrder(
          orderId: orderId,
          amount: retryAmount,
          paymentModeId: paymentModeId,
        );
      } on ApiException catch (retryError) {
        if (!OrderMapper.isSendBeforePaymentError(retryError)) rethrow;

        // Last attempt: request each course again after a short beat, then pay.
        apiLog.writeln('── Dernier essai envoi + paiement ──');
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final again = await _ensureKitchenSentBeforePayment(
          orderId,
          await _fetchOrderDetailForPayment(orderId, apiLog),
          apiLog,
          forceAllVisibleCourses: true,
        );
        final lastAmount = OrderMapper.formatPaymentAmount(
          OrderMapper.parseOrderPayableAmount(again),
        );
        if (lastAmount <= 0) {
          throw ApiException(message: 'Montant à encaisser invalide.');
        }
        apiLog.writeln('── POST /api/orders/$orderId/pay (retry 2) ──');
        await _remote.payOrder(
          orderId: orderId,
          amount: lastAmount,
          paymentModeId: paymentModeId,
        );
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
        return again;
      }
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      return refreshed;
    }
  }

  Future<SessionOrder> _mutateOrderLine({
    required int orderId,
    required String logTitle,
    required Map<String, dynamic> Function(Map<String, dynamic> detail) mutate,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — modification impossible.';
      throw ApiException(
        message: 'Modification impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── $logTitle ──');
    apiLog.writeln('order_id=$orderId');

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);
      final beforeCount = OrderMapper.countVisibleLineItems(detail);
      final localMutated = OrderMapper.copyOrderDetail(detail);
      final payload = mutate(localMutated);

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      lastAddItemLog = apiLog.toString();
      // Offer / comment must not use the empty-shell recreate path — a free
      // offered line looks empty to that flow and wipes the ticket on reopen.
      return _persistOrderAfterLineEdit(
        orderId: orderId,
        putResponse: updated,
        localMutated: localMutated,
        beforeVisibleCount: beforeCount,
      );
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }
}
