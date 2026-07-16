import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_endpoints.dart';
import '../../models/session_order.dart';
import '../../models/order_display_entry.dart';
import '../models/create_table_order_result.dart';
import '../../services/connectivity_service.dart';
import '../datasources/order_local_datasource.dart';
import '../datasources/order_remote_datasource.dart';
import '../datasources/session_datasource.dart';
import '../../utils/api_log.dart';
import '../mappers/order_mapper.dart';
import 'catalog_repository.dart';

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

  /// Last empty-create seed product id (stripped on first real add if leftover).
  int? lastEmptyOrderSeedProductId;

  /// Orders opened as empty tables — UI must not flash API create-seed lines.
  final Set<int> _emptyShellDisplayOrderIds = <int>{};

  /// Monotonic local detail revision. Background enrich that started before a
  /// qty/add mutation must discard its result when this bumps mid-flight.
  final Map<int, int> _detailRevisionByOrderId = <int, int>{};

  /// In-flight seed strips after create — first add must wait so PUT strip
  /// does not race with PUT revive/add and wipe the waiter's item.
  final Map<int, Future<void>> _pendingCreateSeedStrips = <int, Future<void>>{};

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

  /// Returns order detail mapped to [SessionOrder], using cache when offline.
  Map<String, dynamic>? cachedOrderDetail(int orderId) {
    if (orderId <= 0) return null;
    return _local.readOrderDetail(orderId);
  }

  /// Forces a newly opened table order to show with zero visible lines.
  Future<SessionOrder> openAsEmptyTableOrder(int orderId) async {
    final apiLog = StringBuffer('── openAsEmptyTableOrder id=$orderId ──');
    var detail = await _remote.fetchOrderDetail(orderId);
    if (!OrderMapper.orderDetailHasNoVisibleItems(detail)) {
      detail = await _clearVisibleItemsKeepOpen(orderId, detail, apiLog);
    }
    _rememberEmptyShellDisplay(orderId);
    final shell = OrderMapper.asOpenEmptyOrderShell(detail);
    await _local.saveOrderDetail(orderId, shell);
    await _sessionLocal.upsertOpenOrderInList(shell);
    lastCreateOrderLog = apiLog.toString();
    return OrderMapper.fromOrderDetail(shell).copyWith(
      id: orderId,
      products: const [],
      displayEntries: const [],
      itemCount: 0,
      total: OrderMapper.formatPrice('0'),
    );
  }

  Future<SessionOrder> getOrderDetail(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    final online = await _connectivity.isOnline;
    final seedId = await _resolveSeedProductIdForDisplay();

    if (online) {
      var detail = await _remote.fetchOrderDetail(orderId);

      // Create-seed only: keep ticket empty in UI/cache; strip on API best-effort.
      final onlySeed =
          OrderMapper.hasOnlyEmptyCreateSeed(detail, seedProductId: seedId);
      final markedEmptyShell = _emptyShellDisplayOrderIds.contains(orderId);
      final hasRealItems = OrderMapper.hasRealNonSeedVisibleItems(
        detail,
        seedProductId: seedId,
      );
      final cachedDetail = _local.readOrderDetail(orderId);
      final cachedHasRealItems = cachedDetail != null &&
          OrderMapper.hasRealNonSeedVisibleItems(
            cachedDetail,
            seedProductId: seedId,
          );

      if (markedEmptyShell && !hasRealItems) {
        // Background GET can briefly look seed-only after qty edits. Never
        // demote a ticket that already has real lines in local cache.
        final keepCached = cachedHasRealItems ? cachedDetail : null;
        if (keepCached != null) {
          detail = keepCached;
          _forgetEmptyShellDisplay(orderId);
        } else {
          // Stay empty until the waiter adds a real product — never flash seed
          // when background strip has not cleared the API yet.
          _rememberEmptyShellDisplay(orderId);
          if (!OrderMapper.orderDetailHasNoVisibleItems(detail)) {
            final stripLog = StringBuffer(
              '── getOrderDetail: empty-shell hide+strip order=$orderId ──',
            );
            unawaited(_stripCreateSeedInBackground(orderId, detail, stripLog));
          }
          detail = OrderMapper.asOpenEmptyOrderShell(detail);
        }
      } else if (onlySeed) {
        final keepCached = cachedHasRealItems ? cachedDetail : null;
        if (keepCached != null) {
          detail = keepCached;
          _forgetEmptyShellDisplay(orderId);
        } else {
          _rememberEmptyShellDisplay(orderId);
          final stripLog = StringBuffer(
            '── getOrderDetail: hide+strip create seed order=$orderId ──',
          );
          unawaited(_stripCreateSeedInBackground(orderId, detail, stripLog));
          detail = OrderMapper.asOpenEmptyOrderShell(detail);
        }
      } else {
        if (markedEmptyShell) {
          _forgetEmptyShellDisplay(orderId);
        }
        if (lastEmptyOrderSeedProductId != null &&
            !OrderMapper.containsVisibleProductId(
              detail,
              lastEmptyOrderSeedProductId!,
            )) {
          lastEmptyOrderSeedProductId = null;
        }
      }

      await _local.saveOrderDetail(orderId, detail);

      final splitHint = previousDisplayEntries == null
          ? _local.readSuivreSplitHint(orderId)
          : OrderMapper.suivreSplitPositions(previousDisplayEntries);
      final countHint = previousDisplayEntries == null
          ? _local.readSuivreCountHint(orderId)
          : OrderMapper.suivreSeparatorCount(previousDisplayEntries);

      final order = OrderMapper.sessionOrderHidingCreateSeed(
        detail,
        seedProductId: seedId,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: splitHint,
        suivreCountHint: countHint,
      );

      await _persistSuivreLayoutHints(orderId, order.displayEntries);
      return order;
    }

    final cached = _local.readOrderDetail(orderId);
    if (cached != null) {
      return OrderMapper.sessionOrderHidingCreateSeed(
        cached,
        seedProductId: seedId,
      );
    }

    throw ApiException(
      message: 'Détails de commande indisponibles hors ligne.',
    );
  }

  /// Fresh creates stay empty in UI until a real (non-seed) line is added.
  bool shouldDisplayAsEmptyCreateShell(int orderId) =>
      orderId > 0 && _emptyShellDisplayOrderIds.contains(orderId);

  /// Clear empty-shell UI lock once the ticket has real lines again.
  void clearEmptyShellDisplay(int orderId) => _forgetEmptyShellDisplay(orderId);

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

  Future<int?> _resolveSeedProductIdForDisplay() async {
    if (lastEmptyOrderSeedProductId != null &&
        lastEmptyOrderSeedProductId! > 0) {
      return lastEmptyOrderSeedProductId;
    }
    try {
      return (await _catalog.resolveSeedProductForEmptyOrder())?.id;
    } catch (_) {
      return null;
    }
  }

  void _rememberEmptyShellDisplay(int orderId) {
    if (orderId > 0) _emptyShellDisplayOrderIds.add(orderId);
  }

  void _forgetEmptyShellDisplay(int orderId) {
    _emptyShellDisplayOrderIds.remove(orderId);
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
    final count = OrderMapper.suivreSeparatorCount(displayEntries);
    await _local.saveSuivreSplitHint(orderId, splits);
    await _local.saveSuivreCountHint(orderId, count);
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
    required List<Map<String, dynamic>> tables,
    int? salesZoneId,
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

    final table = OrderMapper.resolveTableForNewOrder(tables, tableNumber);
    if (table == null) {
      throw ApiException(message: 'Table $tableNumber introuvable.');
    }

    if (OrderMapper.isAssignedToOtherWaiter(
      tables,
      tableNumber,
      waiterId: waiterId,
    )) {
      throw ApiException(
        message: 'You are not allowed to release this table.',
      );
    }

    final resolvedSalesZoneId = OrderMapper.inferSalesZoneId(
      tables,
      preferred: salesZoneId,
      table: table,
    );

    apiLog.writeln(
      'Table résolue: id=${table.id}, numéro=${table.tableNumber}, '
      'status=${table.status ?? '—'}, '
      'activeOrder=${table.existingOrderId ?? '—'}, '
      'sales_zone_id=${resolvedSalesZoneId ?? '—'}',
    );

    // After cancel, tables/list can still list our active_order briefly.
    // Reopen that order when still open; if already closed, clear session and
    // continue with a fresh POST.
    final ownActiveId = OrderMapper.ownReusableActiveOrderId(
      tables,
      tableNumber,
      waiterId: waiterId,
    );
    if (ownActiveId != null) {
      apiLog.writeln('── Reclaim own active_order=$ownActiveId ──');
      try {
        final detail = await _remote.fetchOrderDetail(ownActiveId);
        if (!OrderMapper.isOrderClosedOrCancelled(detail)) {
          final seedId = await _resolveSeedProductIdForDisplay();
          final onlySeed = OrderMapper.hasOnlyEmptyCreateSeed(
            detail,
            seedProductId: seedId,
          );
          // Seed-only leftover after cancel/recreate → show empty + strip.
          if (onlySeed || OrderMapper.orderDetailHasNoVisibleItems(detail)) {
            _rememberEmptyShellDisplay(ownActiveId);
            if (onlySeed) {
              unawaited(
                _stripCreateSeedInBackground(
                  ownActiveId,
                  detail,
                  apiLog,
                ),
              );
            }
            final shell = OrderMapper.asOpenEmptyOrderShell(detail);
            await _local.saveOrderDetail(ownActiveId, shell);
            await _sessionLocal.upsertOpenOrderInList(shell);
            final displayNumber = OrderMapper.displayKey(
              orderId: ownActiveId,
              tableNumber: table.tableNumber,
            );
            final mapped = OrderMapper.fromOrderDetail(shell).copyWith(
              id: ownActiveId,
              number: displayNumber,
              products: const [],
              displayEntries: const [],
              itemCount: 0,
              total: OrderMapper.formatPrice('0'),
            );
            lastCreateOrderLog = apiLog.toString();
            logOrderFlow(
              'createTableOrder RECLAIM empty shell orderId=$ownActiveId '
              'table=$tableNumber',
            );
            return CreateTableOrderResult(
              order: mapped,
              apiLog: apiLog.toString(),
            );
          }

          // Still open with real articles — reopen as-is.
          await _local.saveOrderDetail(ownActiveId, detail);
          await _sessionLocal.upsertOpenOrderInList(detail);
          final displayNumber = OrderMapper.displayKey(
            orderId: ownActiveId,
            tableNumber: table.tableNumber,
          );
          final mapped = OrderMapper.fromOrderDetail(detail).copyWith(
            id: ownActiveId,
            number: displayNumber,
          );
          lastCreateOrderLog = apiLog.toString();
          logOrderFlow(
            'createTableOrder RECLAIM own orderId=$ownActiveId table=$tableNumber',
          );
          return CreateTableOrderResult(
            order: mapped,
            apiLog: apiLog.toString(),
          );
        }
        await _local.removeOrderDetail(ownActiveId);
        await _sessionLocal.removeOpenOrderFromList(ownActiveId);
      } catch (e) {
        apiLog.writeln('── Reclaim active_order failed: $e ──');
      }
      await _clearOrphanTableSession(table.id, apiLog: apiLog);
    } else if (OrderMapper.canReclaimOrphanTableSession(
      tables,
      tableNumber,
      waiterId: waiterId,
    )) {
      // Session-only create can leave a lock with no active_order. Clear our
      // own orphan session before starting a fresh one.
      await _clearOrphanTableSession(table.id, apiLog: apiLog);
    } else if (table.hasActiveOrder) {
      throw ApiException(
        message: 'La table $tableNumber a déjà une commande active.',
      );
    }

    await _tryStartTableSession(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      apiLog: apiLog,
    );

    // Recommended: POST /api/orders (all nested id:0 + uid) → save ids from response.
    final createdPayload = await _postCreateEmptyOrderRecord(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      salesZoneId: resolvedSalesZoneId,
      apiLog: apiLog,
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

    // Open fast: use POST response as an empty shell and strip the required
    // seed item in the background (API often requires a seed line on create).
    var detail = OrderMapper.unwrapOrderDetail(createdPayload!);
    detail = <String, dynamic>{
      ...detail,
      'id': orderId,
      'table_id': table.id,
      'table_number': table.tableNumber,
    };

    final shell = OrderMapper.asOpenEmptyOrderShell(detail);
    _rememberEmptyShellDisplay(orderId);
    await _local.saveOrderDetail(orderId, shell);
    await _sessionLocal.upsertOpenOrderInList(shell);

    final displayNumber = OrderMapper.displayKey(
      orderId: orderId,
      tableNumber: table.tableNumber,
    );
    final order = OrderMapper.fromOrderDetail(shell).copyWith(
      id: orderId,
      number: displayNumber,
      products: const [],
      displayEntries: const [],
      itemCount: 0,
      total: OrderMapper.formatPrice('0'),
    );

    final stripFuture = _stripCreateSeedInBackground(orderId, detail, apiLog);
    _pendingCreateSeedStrips[orderId] = stripFuture;
    unawaited(
      stripFuture.whenComplete(() {
        _pendingCreateSeedStrips.remove(orderId);
      }),
    );

    apiLog
      ..writeln()
      ..writeln('── Résultat final (ouverture rapide) ──')
      ..writeln(
        'POST /api/orders OK id=$orderId, affichage=${order.number}, '
        'items=0 (seed strip en arrière-plan)',
      );

    lastCreateOrderLog = apiLog.toString();
    logOrderFlow(
      'createTableOrder END remote empty orderId=$orderId table=$tableNumber '
      '(fast open, seed strip background)',
    );
    return CreateTableOrderResult(order: order, apiLog: apiLog.toString());
  }

  Future<void> _stripCreateSeedInBackground(
    int orderId,
    Map<String, dynamic> detail,
    StringBuffer apiLog,
  ) async {
    _rememberEmptyShellDisplay(orderId);
    try {
      var working = detail;
      if (OrderMapper.orderDetailHasNoVisibleItems(working)) {
        lastEmptyOrderSeedProductId = null;
        final shell = OrderMapper.asOpenEmptyOrderShell(working);
        await _local.saveOrderDetail(orderId, shell);
        await _sessionLocal.upsertOpenOrderInList(shell);
        return;
      }

      // 1) Prefer emptying course items via PUT (no cancel — cancel can close order).
      working = await _clearVisibleItemsKeepOpen(orderId, working, apiLog);

      // 2) If API still has the seed, keep going UI-side only (no side effects).
      if (!OrderMapper.orderDetailHasNoVisibleItems(working)) {
        apiLog.writeln(
          '── Seed still on API after strip; UI stays empty (no cancel) ──',
        );
      } else {
        lastEmptyOrderSeedProductId = null;
      }

      if (OrderMapper.isOrderClosedOrCancelled(working)) {
        // Do not reopen here — would surprise the floor. Keep display empty mark.
        apiLog.writeln('── WARNING: order closed during seed strip ──');
        return;
      }

      final shell = OrderMapper.asOpenEmptyOrderShell(working);
      await _local.saveOrderDetail(orderId, shell);
      await _sessionLocal.upsertOpenOrderInList(shell);
      lastCreateOrderLog = apiLog.toString();
    } catch (e) {
      apiLog.writeln('── Background seed strip failed: $e ──');
      // Still persist an empty local shell so enrich / reopen never flash the seed.
      try {
        final shell = OrderMapper.asOpenEmptyOrderShell(detail);
        await _local.saveOrderDetail(orderId, shell);
        await _sessionLocal.upsertOpenOrderInList(shell);
      } catch (_) {}
      lastCreateOrderLog = apiLog.toString();
    }
  }

  /// Creates a remote open order with no visible products.
  ///
  /// POST shape (docs): all nested `id: 0` + item `uid`, status
  /// `to_be_continued`. Then PUT strips seed lines (not cancel).
  Future<Map<String, dynamic>?> _postCreateEmptyOrderRecord({
    required ResolvedTable table,
    required int waiterId,
    required int numberOfGuests,
    required int? salesZoneId,
    required StringBuffer apiLog,
  }) async {
    final seed = await _catalog.resolveSeedProductForEmptyOrder();
    if (seed == null) {
      apiLog.writeln(
        '── Aucun produit simple pour seed POST /api/orders ──',
      );
      logOrderFlow('POST /api/orders ABORT no seed product');
      return null;
    }

    apiLog.writeln(
      '── Seed produit id=${seed.id} "${seed.name}" '
      '(sera retiré via PUT items:[], pas annulé) ──',
    );

    lastEmptyOrderSeedProductId = seed.id;

    final withItem = OrderMapper.buildCreateOrderWithItemPayload(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      productId: seed.id,
      unitPrice: seed.unitPrice,
      tableId: table.id,
      salesZoneId: salesZoneId,
      qty: 1,
      status: 'to_be_continued',
      comment: '',
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
      if (!OrderMapper.orderDetailHasNoVisibleItems(detail)) {
        detail = await _clearVisibleItemsKeepOpen(
          orderId,
          detail,
          StringBuffer(),
        );
      }
      if (OrderMapper.isOrderClosedOrCancelled(detail)) {
        await _local.removeOrderDetail(orderId);
        await _sessionLocal.removeOpenOrderFromList(orderId);
        return null;
      }

      final shell = OrderMapper.asOpenEmptyOrderShell(detail);
      await _local.saveOrderDetail(orderId, shell);
      await _sessionLocal.upsertOpenOrderInList(shell);
      return CreateTableOrderResult(
        order: OrderMapper.fromOrderDetail(shell).copyWith(
          id: orderId,
          products: const [],
          displayEntries: const [],
          total: OrderMapper.formatPrice('0'),
        ),
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

  Future<SessionOrder> requestNextCourses(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Demande impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final detail = await _remote.fetchOrderDetail(orderId);
    final courseIds = OrderMapper.extractRequestableCourseIds(detail);
    if (courseIds.isEmpty) {
      throw ApiException(message: 'Aucun service à demander pour cette table.');
    }

    await _remote.requestCourses(orderId, courseIds);
    return getOrderDetail(
      orderId,
      previousDisplayEntries: previousDisplayEntries,
    );
  }

  Future<SessionOrder> requestCourseForSuivreSection(
    int orderId, {
    required int courseNumber,
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Demande impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final detail = await _remote.fetchOrderDetail(orderId);
    final courseIds = OrderMapper.extractRequestableCourseIdsForSuivreSection(
      detail,
      courseNumber: courseNumber,
    );
    if (courseIds.isEmpty) {
      throw ApiException(
        message: OrderMapper.describeWhySuivreSectionNotRequestable(
          detail,
          courseNumber: courseNumber,
        ),
      );
    }

    await _remote.requestCourses(orderId, courseIds);
    return getOrderDetail(
      orderId,
      previousDisplayEntries: previousDisplayEntries,
    );
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
    /// When the UI shell is empty, cancel any leftover create-seed lines
    /// before adding so only the waiter-selected item remains.
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
      final pendingStrip = _pendingCreateSeedStrips[orderId];
      if (pendingStrip != null) {
        apiLog.writeln('── Attente fin strip seed create ──');
        await pendingStrip;
      }

      apiLog.writeln('── GET /api/orders/$orderId ──');
      var detail = await _remote.fetchOrderDetail(orderId);

      // Prefer the seed we planted on empty create; else detect lone free seed line.
      final plantedSeedId = lastEmptyOrderSeedProductId;
      final catalogSeedId = plantedSeedId ??
          (await _catalog.resolveSeedProductForEmptyOrder())?.id;

      final onlySeed = OrderMapper.hasOnlyEmptyCreateSeed(
        detail,
        seedProductId: catalogSeedId,
      );

      if (expectEmptyShell || onlySeed) {
        apiLog.writeln(
          '── Replace shell '
          '(expectEmpty=$expectEmptyShell onlySeed=$onlySeed '
          'seedId=$catalogSeedId) ──',
        );
        if (catalogSeedId != null) {
          lastEmptyOrderSeedProductId = catalogSeedId;
        }
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

      // Only drop a seed we planted this session (never strip waiter-chosen lines).
      final leftoverSeed = plantedSeedId != null &&
          OrderMapper.containsVisibleProductId(detail, plantedSeedId) &&
          productId != plantedSeedId;
      if (leftoverSeed) {
        apiLog.writeln(
          '── Drop leftover seed product=$plantedSeedId before add ──',
        );
        detail = OrderMapper.withoutVisibleProduct(detail, plantedSeedId);
      }

      // Emptied shells are often marked paid/closed while the table still holds
      // them as the active order. Revive in place — do not POST a second order.
      if (OrderMapper.shouldRecreateOrderForAdd(detail) ||
          OrderMapper.orderDetailHasNoVisibleItems(detail)) {
        apiLog.writeln(
          '── Empty shell → revive + add (avoid active-order conflict) ──',
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

      // After dropping planted seed, PUT full state so removal persists with add.
      if (leftoverSeed) {
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
        lastEmptyOrderSeedProductId = null;
        _forgetEmptyShellDisplay(orderId);
        await _local.saveOrderDetail(orderId, updated);
        lastAddItemLog = apiLog.toString();
        return _fetchAndMapOrder(
          orderId,
          previousDisplayEntries: layoutHints,
        );
      }

      final seatNumber = OrderMapper.resolveDefaultSeatNumber(detail);
      final suivreHints = _resolveSuivreHints(
        orderId,
        layoutHints: layoutHints,
      );
      final course = OrderMapper.resolveAppendCourse(
        detail,
        seatNumber: seatNumber,
        suivreSectionCount: suivreHints.count,
        suivreSplitHints: suivreHints.splits,
        layoutHints: layoutHints,
      );

      _ensureAddItemCourse(
        detail,
        apiLog,
        orderId: orderId,
        layoutHints: layoutHints,
      );

      final body = OrderMapper.buildSeatOrderItemsPostPayload(
        courseNumber: course.number,
        productId: productId,
        qty: qty,
        subTotal: unitPrice * qty,
        comment: comment,
      );

      await _postSeatOrderItems(
        orderId: orderId,
        detail: detail,
        seatNumber: seatNumber,
        body: body,
        apiLog: apiLog,
      );

      lastAddItemLog = apiLog.toString();
      return _fetchAndMapOrder(
        orderId,
        previousDisplayEntries: layoutHints,
      );
    } on ApiException catch (e) {
      apiLog.writeln('POST add failed, fallback PUT: ${e.message}');

      try {
        final detail = await _remote.fetchOrderDetail(orderId);

        if (OrderMapper.shouldRecreateOrderForAdd(detail) ||
            OrderMapper.orderDetailHasNoVisibleItems(detail) ||
            _shouldRecreateAfterAddFailure(e, detail)) {
          apiLog.writeln('── Add failed on empty shell → revive/recreate ──');
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
              '── PUT fallback failed on empty shell → revive/recreate ──',
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
    // Drop create-seed / ghost lines so PUT only keeps the waiter-selected item.
    var cleaned = OrderMapper.withAllCourseItemsCleared(detail);
    if (lastEmptyOrderSeedProductId != null &&
        lastEmptyOrderSeedProductId! > 0 &&
        productId != lastEmptyOrderSeedProductId) {
      cleaned = OrderMapper.withoutVisibleProduct(
        cleaned,
        lastEmptyOrderSeedProductId!,
      );
    }

    final working = OrderMapper.asOpenEmptyOrderShell(cleaned);
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
      OrderMapper.addOrIncrementSimpleItem(
        orderDetail: working,
        productId: productId,
        unitPrice: unitPrice,
        qty: qty,
        comment: comment,
        suivreSectionCount: suivreHints.count,
        suivreSplitHints: suivreHints.splits,
        layoutHints: layoutHints,
      ),
    );
    // Force the shell back to an open/unpaid state so the API accepts lines.
    payload['status'] = 'open';
    payload['payment_status'] = 'not_paid';
    payload['payment_status_detailed'] = 'not_paid';

    apiLog.writeln(
      '── PUT revive empty order $orderId '
      '(cleared seed + add item) ──',
    );
    final updated = await _putOrderUpdate(
      orderId: orderId,
      payload: payload,
      apiLog: apiLog,
    );
    lastEmptyOrderSeedProductId = null;
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

    // Close best-effort, but keep going even if close is rejected.
    await _retireDeadOrderShell(oldOrderId, apiLog: apiLog);

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
      final pendingStrip = _pendingCreateSeedStrips[orderId];
      if (pendingStrip != null) {
        apiLog.writeln('── Attente fin strip seed create ──');
        await pendingStrip;
      }

      apiLog.writeln('── GET /api/orders/$orderId ──');
      var detail = await _remote.fetchOrderDetail(orderId);

      final plantedSeedId = lastEmptyOrderSeedProductId;
      final catalogSeedId = plantedSeedId ??
          (await _catalog.resolveSeedProductForEmptyOrder())?.id;
      final onlySeed = OrderMapper.hasOnlyEmptyCreateSeed(
        detail,
        seedProductId: catalogSeedId,
      );
      if (expectEmptyShell || onlySeed) {
        apiLog.writeln(
          '── Replace shell composed '
          '(expectEmpty=$expectEmptyShell onlySeed=$onlySeed) ──',
        );
        if (catalogSeedId != null) {
          lastEmptyOrderSeedProductId = catalogSeedId;
        }
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

      if (plantedSeedId != null &&
          OrderMapper.containsVisibleProductId(detail, plantedSeedId) &&
          productId != plantedSeedId) {
        apiLog.writeln(
          '── Drop leftover seed product=$plantedSeedId before composed add ──',
        );
        detail = OrderMapper.withoutVisibleProduct(detail, plantedSeedId);
      }

      if (OrderMapper.shouldRecreateOrderForAdd(detail) ||
          OrderMapper.orderDetailHasNoVisibleItems(detail)) {
        apiLog.writeln(
          '── Empty shell → revive + add composed (avoid active-order conflict) ──',
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
      '── PUT revive empty order $orderId '
      '(cleared seed + add composed) ──',
    );
    final updated = await _putOrderUpdate(
      orderId: orderId,
      payload: payload,
      apiLog: apiLog,
    );
    lastEmptyOrderSeedProductId = null;
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

    await _retireDeadOrderShell(oldOrderId, apiLog: apiLog);

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

    final displayEntries = OrderMapper.applyDemandeSeparatorsFromApi(
      detail,
      trimmedDisplay,
    );
    final order = OrderMapper.fromOrderDetail(detail).copyWith(
      displayEntries: displayEntries,
    );

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
      lastAddItemLog = 'Hors ligne — annulation article impossible.';
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

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      lastAddItemLog = apiLog.toString();

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
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  Future<SessionOrder> cancelOrderLineAtIndex({
    required int orderId,
    required int lineIndex,
  }) async {
    final apiLog = StringBuffer();
    lastAddItemLog = null;

    if (!await _connectivity.isOnline) {
      lastAddItemLog = 'Hors ligne — annulation article impossible.';
      throw ApiException(
        message: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    apiLog.writeln('── Annulation article ──');
    apiLog.writeln('order_id=$orderId line_index=$lineIndex');

    try {
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);
      final localMutated = OrderMapper.copyOrderDetail(detail);

      final payload = OrderMapper.cancelOrderLineAtIndex(
        orderDetail: localMutated,
        lineIndex: lineIndex,
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
        keepLinesIfApiEmpty: OrderMapper.orderDetailHasNoVisibleItems(localMutated)
            ? null
            : localMutated,
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

  ({List<int> splits, int count}) _resolveSuivreHints(
    int orderId, {
    List<OrderDisplayEntry>? layoutHints,
  }) {
    // When the UI passes layout hints, trust them even if count is 0 — otherwise
    // a stale local suivre_count hint resurrects a fake À SUIVRE after menu add.
    if (layoutHints != null) {
      return (
        splits: OrderMapper.suivreSplitPositions(layoutHints),
        count: OrderMapper.suivreSeparatorCount(layoutHints),
      );
    }

    final count = _local.readSuivreCountHint(orderId);
    return (
      splits: _local.readSuivreSplitHint(orderId),
      count: count,
    );
  }

  void _ensureAddItemCourse(
    Map<String, dynamic> detail,
    StringBuffer apiLog, {
    required int orderId,
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final seatNumber = OrderMapper.resolveDefaultSeatNumber(detail);
    final suivreHints = _resolveSuivreHints(
      orderId,
      layoutHints: layoutHints,
    );
    final course = OrderMapper.resolveAppendCourse(
      detail,
      seatNumber: seatNumber,
      suivreSectionCount: suivreHints.count,
      suivreSplitHints: suivreHints.splits,
      layoutHints: layoutHints,
    );

    if (course.number <= 0) {
      apiLog.writeln(
        'ERREUR: aucune suite (course) sur la commande. '
        'La commande doit avoir au moins un seat_order/course.',
      );
      throw ApiException(
        message:
            'Impossible d\'ajouter: aucune suite active sur cette commande.',
      );
    }

    apiLog.writeln(
      'seat_number=$seatNumber course_id=${course.id ?? '—'} '
      'course_number=${course.number}',
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

  Future<void> _postSeatOrderItems({
    required int orderId,
    required Map<String, dynamic> detail,
    required int seatNumber,
    required Map<String, dynamic> body,
    required StringBuffer apiLog,
  }) async {
    apiLog.writeln(
      '── POST /api/orders/$orderId/seat-orders/$seatNumber/items ──',
    );
    apiLog.writeln(formatApiPayload(body));

    try {
      await _remote.addSeatOrderItems(
        orderId: orderId,
        seatNumber: seatNumber,
        body: body,
      );
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      return;
    } on ApiException {
      final seatRecordId = OrderMapper.resolveSeatOrderRecordId(
        detail,
        seatNumber: seatNumber,
      );
      if (seatRecordId == null || seatRecordId == seatNumber) {
        rethrow;
      }

      apiLog.writeln(
        'RETRY seat_number=$seatNumber → seat_record_id=$seatRecordId',
      );
      apiLog.writeln(
        '── POST /api/orders/$orderId/seat-orders/$seatRecordId/items ──',
      );
      await _remote.addSeatOrderItems(
        orderId: orderId,
        seatNumber: seatRecordId,
        body: body,
      );
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
    }
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
      // Backend often marks emptied orders closed/fully_paid — that removes
      // them from the remote list. Replace with a real empty open order.
      if (OrderMapper.shouldRecreateOrderForAdd(working) ||
          !OrderMapper.isActiveDayOpenOrder(working)) {
        final replacement = await _ensureRemoteEmptyOpenOrder(
          oldOrderId: orderId,
          detail: working,
        );
        if (replacement != null) {
          return replacement;
        }
      }

      working = OrderMapper.asOpenEmptyOrderShell(working);

      // If the API still auto-closed despite keep-open status, try one reopen PUT.
      if (OrderMapper.isOrderClosedOrCancelled(detail) ||
          OrderMapper.isOrderClosedOrCancelled(working) ||
          OrderMapper.isOrderFullyPaid(working)) {
        try {
          final reopenPayload = OrderMapper.buildOrderUpdatePayload(
            working,
            keepOpenWhenEmpty: true,
          );
          working = await _remote.updateOrder(orderId, reopenPayload);
          working = OrderMapper.asOpenEmptyOrderShell(working);

          // Reopen failed to keep it listable — create a new empty remote order.
          if (OrderMapper.shouldRecreateOrderForAdd(working) ||
              !OrderMapper.isActiveDayOpenOrder(working)) {
            final replacement = await _ensureRemoteEmptyOpenOrder(
              oldOrderId: orderId,
              detail: working,
            );
            if (replacement != null) return replacement;
          }
        } catch (_) {
          final replacement = await _ensureRemoteEmptyOpenOrder(
            oldOrderId: orderId,
            detail: working,
          );
          if (replacement != null) return replacement;
          working = OrderMapper.asOpenEmptyOrderShell(working);
        }
      }
    }

    await _local.saveOrderDetail(orderId, working);
    await _sessionLocal.upsertOpenOrderInList(working);

    final splitHint = previousDisplayEntries == null
        ? _local.readSuivreSplitHint(orderId)
        : OrderMapper.suivreSplitPositions(previousDisplayEntries);
    final countHint = previousDisplayEntries == null
        ? _local.readSuivreCountHint(orderId)
        : OrderMapper.suivreSeparatorCount(previousDisplayEntries);

    final order = OrderMapper.fromOrderDetail(
      working,
      previousDisplayEntries: previousDisplayEntries,
      suivreSplitHints: splitHint,
      suivreCountHint: countHint,
    );

    // Empty display for emptied shells (cancelled lines stay on the server).
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
  Future<SessionOrder?> _ensureRemoteEmptyOpenOrder({
    required int oldOrderId,
    required Map<String, dynamic> detail,
  }) async {
    final apiLog = StringBuffer();
    apiLog.writeln(
      '── Ensure remote empty open order (old_id=$oldOrderId) ──',
    );

    final tableId = (detail['table_id'] as num?)?.toInt();
    final tableNumber = OrderMapper.tableNumberFromDetail(detail);
    final waiterId = OrderMapper.waiterIdFromOrderMap(detail);
    final guests = (detail['number_of_guests'] as num?)?.toInt() ?? 1;
    final salesZoneId = (detail['sales_zone_id'] as num?)?.toInt() ??
        (detail['sales_zone'] is Map<String, dynamic>
            ? ((detail['sales_zone'] as Map<String, dynamic>)['id'] as num?)
                ?.toInt()
            : null);

    if (tableId == null ||
        tableId <= 0 ||
        waiterId == null ||
        waiterId <= 0 ||
        tableNumber == null ||
        tableNumber <= 0) {
      apiLog.writeln('── Missing table/waiter — cannot recreate empty order ──');
      lastAddItemLog = apiLog.toString();
      return null;
    }

    await _retireDeadOrderShell(oldOrderId, apiLog: apiLog);

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

    final createdPayload = await _postCreateEmptyOrderRecord(
      table: table,
      waiterId: waiterId,
      numberOfGuests: guests < 1 ? 1 : guests,
      salesZoneId: salesZoneId,
      apiLog: apiLog,
    );
    final newId = createdPayload == null
        ? null
        : OrderMapper.extractOrderIdFromPayload(createdPayload);
    if (newId == null || newId <= 0) {
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
    await _local.saveOrderDetail(newId, shell);
    await _sessionLocal.upsertOpenOrderInList(shell);

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
          } catch (_) {}
        }
      } catch (e) {
        apiLog.writeln('── strip attempt $attempt failed: $e ──');
        try {
          working = await _remote.fetchOrderDetail(orderId);
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
            working = await _remote.updateOrder(orderId, reopen);
            if (!OrderMapper.orderDetailHasNoVisibleItems(working) ||
                OrderMapper.isOrderClosedOrCancelled(working) ||
                OrderMapper.isOrderFullyPaid(working)) {
              try {
                working = await _remote.fetchOrderDetail(orderId);
              } catch (_) {}
            }
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

    final splitHint = previousDisplayEntries == null
        ? _local.readSuivreSplitHint(orderId)
        : OrderMapper.suivreSplitPositions(previousDisplayEntries);
    final countHint = previousDisplayEntries == null
        ? _local.readSuivreCountHint(orderId)
        : OrderMapper.suivreSeparatorCount(previousDisplayEntries);

    final order = OrderMapper.fromOrderDetail(
      working,
      previousDisplayEntries: previousDisplayEntries,
      suivreSplitHints: splitHint,
      suivreCountHint: countHint,
    );

    // Last resort: never return an empty SessionOrder when we still have lines.
    if (order.products.isEmpty && localCount > 0) {
      final fallback = OrderMapper.fromOrderDetail(
        localMutated,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: splitHint,
        suivreCountHint: countHint,
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

  Future<SessionOrder> requestAllCourses(int orderId) async {
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
      final detail = await _remote.fetchOrderDetail(orderId);
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }

      final courseIds = OrderMapper.extractKitchenSendCourseIds(detail);
      apiLog.writeln('course_ids=${courseIds.join(',')}');
      if (courseIds.isEmpty) {
        throw ApiException(
          message: 'Aucun article à envoyer en cuisine pour cette table.',
        );
      }

      apiLog.writeln('── POST /api/orders/$orderId/courses ──');
      await _remote.requestCourses(orderId, courseIds);
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }

      apiLog.writeln('── GET /api/orders/$orderId (updated) ──');
      final updated = await _remote.fetchOrderDetail(orderId);
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }

      await _local.saveOrderDetail(orderId, updated);
      lastKitchenSendLog = apiLog.toString();
      print(lastKitchenSendLog);
      debugPrint(lastKitchenSendLog!);

      return OrderMapper.fromOrderDetail(updated);
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

      // Same path as the red paper-plane "Envoyer" action, then a forced
      // pass over every visible course id (covers items added after DEMANDÉE).
      try {
        apiLog.writeln('── Envoi cuisine (requestAllCourses) avant paiement ──');
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

      final splitHint = previousDisplayEntries == null
          ? _local.readSuivreSplitHint(orderId)
          : OrderMapper.suivreSplitPositions(previousDisplayEntries);
      final countHint = previousDisplayEntries == null
          ? _local.readSuivreCountHint(orderId)
          : OrderMapper.suivreSeparatorCount(previousDisplayEntries);

      return OrderMapper.fromOrderDetail(
        updated,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: splitHint,
        suivreCountHint: countHint,
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
      final localMutated = OrderMapper.copyOrderDetail(detail);
      final payload = mutate(localMutated);

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      lastAddItemLog = apiLog.toString();
      return _persistOrderAfterItemMutation(
        orderId: orderId,
        detail: updated,
        keepLinesIfApiEmpty: OrderMapper.orderDetailHasNoVisibleItems(localMutated)
            ? null
            : localMutated,
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
