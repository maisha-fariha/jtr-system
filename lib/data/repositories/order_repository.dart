import 'package:flutter/foundation.dart';

import '../../core/network/api_exception.dart';
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

  /// Last create-order debug trace (for on-screen error/success dialog).
  String? lastCreateOrderLog;

  /// Last add-item debug trace.
  String? lastAddItemLog;

  /// Last payment debug trace.
  String? lastPaymentLog;

  /// Last payment-modes fetch debug trace.
  String? lastPaymentModesLog;

  List<Map<String, dynamic>> _cachedPaymentModes = [];

  /// Returns order detail mapped to [SessionOrder], using cache when offline.
  Future<SessionOrder> getOrderDetail(
    int orderId, {
    List<OrderDisplayEntry>? previousDisplayEntries,
  }) async {
    final online = await _connectivity.isOnline;
    final splitHint = _local.readSuivreSplitHint(orderId);
    final countHint = _local.readSuivreCountHint(orderId);

    if (online) {
      final detail = await _remote.fetchOrderDetail(orderId);
      await _local.saveOrderDetail(orderId, detail);
      final order = OrderMapper.fromOrderDetail(
        detail,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: splitHint,
        suivreCountHint: countHint,
      );
      await _persistSuivreLayoutHints(orderId, order.displayEntries);
      return order;
    }

    final cached = _local.readOrderDetail(orderId);
    if (cached != null) {
      final order = OrderMapper.fromOrderDetail(
        cached,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: splitHint,
        suivreCountHint: countHint,
      );
      return order;
    }

    throw ApiException(
      message: 'Détails de commande indisponibles hors ligne.',
    );
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
      await _remote.closeOrder(orderId);
      await _local.removeOrderDetail(orderId);
      await _sessionLocal.removeOpenOrderFromList(orderId);
    }

    if (tableId != null && tableId > 0) {
      try {
        await _remote.endTableSession(tableId);
      } on ApiException catch (error) {
        if (orderId <= 0) rethrow;
        final message = error.message.toLowerCase();
        if (!message.contains('session') && !message.contains('404')) {
          rethrow;
        }
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

    if (table.hasActiveOrder) {
      throw ApiException(
        message: 'La table $tableNumber a déjà une commande active.',
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

    var orderId = await _createOrderOnTable(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      salesZoneId: resolvedSalesZoneId,
      tables: tables,
      apiLog: apiLog,
    );

    if (orderId == null || orderId <= 0) {
      apiLog.writeln(
        '── POST /api/orders échoué — commande créée au premier article ──',
      );
      final order = OrderMapper.buildSessionPlaceholderOrder(
        tableNumber: table.tableNumber,
        numberOfGuests: numberOfGuests,
      );
      lastCreateOrderLog = apiLog.toString();
      logOrderFlow(
        'createTableOrder END session-only table=$tableNumber (POST /api/orders on first item)',
      );
      return CreateTableOrderResult(order: order, apiLog: apiLog.toString());
    }

    apiLog.writeln('── GET /api/orders/$orderId (seat_orders) ──');
    final detail = await _remote.fetchOrderDetail(orderId);
    await _local.saveOrderDetail(orderId, detail);
    await _sessionLocal.upsertOpenOrderInList(detail);
    apiLog.writeln(formatApiPayload(detail));

    final displayNumber = OrderMapper.tableDisplayNumber('${table.tableNumber}');
    final order = OrderMapper.fromOrderDetail(detail).copyWith(
      number: displayNumber,
      id: orderId,
    );

    apiLog
      ..writeln()
      ..writeln('── Résultat final ──')
      ..writeln('orderId=${order.id}, affichage=${order.number}');

    lastCreateOrderLog = apiLog.toString();
    logOrderFlow('createTableOrder END orderId=$orderId table=$tableNumber');
    return CreateTableOrderResult(order: order, apiLog: apiLog.toString());
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

      final orderId = await _resolveOrderIdForTable(
        tableId: table.id,
        tableNumber: table.tableNumber,
        initialTables: tables,
      );
      if (orderId == null || orderId <= 0) return null;

      final detail = await _remote.fetchOrderDetail(orderId);
      await _local.saveOrderDetail(orderId, detail);
      await _sessionLocal.upsertOpenOrderInList(detail);

      final displayNumber =
          OrderMapper.tableDisplayNumber('${table.tableNumber}');
      final order = OrderMapper.fromOrderDetail(detail).copyWith(
        number: displayNumber,
        id: orderId,
      );

      return CreateTableOrderResult(
        order: order,
        apiLog: '── Commande récupérée après erreur POST: $orderId ──',
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> _createOrderOnTable({
    required ResolvedTable table,
    required int waiterId,
    required int numberOfGuests,
    required int? salesZoneId,
    required List<Map<String, dynamic>> tables,
    required StringBuffer apiLog,
  }) async {
    logOrderFlow(
      '_createOrderOnTable table=${table.tableNumber} id=${table.id}',
    );
    apiLog
      ..writeln('── Données table (GET /api/tables/list) ──')
      ..writeln('table_id=${table.id}')
      ..writeln('table_number=${table.tableNumber}')
      ..writeln('status=${table.status ?? '—'}')
      ..writeln('sales_zone_id=${salesZoneId ?? '—'}');

    // 1. POST /api/orders first (main API for opening a table).
    logOrderFlow('POST /api/orders FIRST (before session)');
    var orderId = await _postCreateOrderRecord(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      salesZoneId: salesZoneId,
      apiLog: apiLog,
    );
    if (orderId != null && orderId > 0) {
      logOrderFlow('POST /api/orders OK before session → orderId=$orderId');
      await _tryStartTableSession(
        table: table,
        waiterId: waiterId,
        numberOfGuests: numberOfGuests,
        apiLog: apiLog,
      );
      return orderId;
    }

    // 2. Open session, then retry POST /api/orders.
    await _tryStartTableSession(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      apiLog: apiLog,
    );

    logOrderFlow('POST /api/orders RETRY (after session)');
    orderId = await _postCreateOrderRecord(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      salesZoneId: salesZoneId,
      apiLog: apiLog,
    );
    if (orderId != null && orderId > 0) {
      logOrderFlow('POST /api/orders OK after session → orderId=$orderId');
      return orderId;
    }

    orderId = await _resolveOrderIdForTable(
      tableId: table.id,
      tableNumber: table.tableNumber,
      initialTables: tables,
      maxAttempts: 2,
    );
    if (orderId != null && orderId > 0) {
      apiLog.writeln('── Order id résolu via GET /api/tables/list: $orderId ──');
      return orderId;
    }

    return null;
  }

  Future<int?> _postCreateOrderRecord({
    required ResolvedTable table,
    required int waiterId,
    required int numberOfGuests,
    required int? salesZoneId,
    required StringBuffer apiLog,
  }) async {
    final defaultProduct = await _catalog.resolveDefaultOrderProduct();
    if (defaultProduct == null) {
      logOrderFlow(
        'POST /api/orders ABORT no default product in catalog for seat_orders.items',
      );
      apiLog.writeln(
        '── Aucun produit simple disponible pour POST /api/orders (seat_orders.items requis) ──',
      );
      return null;
    }

    logOrderFlow(
      'POST /api/orders default product id=${defaultProduct.id} '
      '${defaultProduct.name} price=${defaultProduct.unitPrice}',
    );
    apiLog.writeln(
      '── Produit par défaut: id=${defaultProduct.id}, '
      '${defaultProduct.name}, ${defaultProduct.unitPrice} ──',
    );

    final payloads = OrderMapper.createOrderPayloadCandidates(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      tableId: table.id,
      salesZoneId: salesZoneId,
      productId: defaultProduct.id,
      unitPrice: defaultProduct.unitPrice,
    );

    for (var i = 0; i < payloads.length; i++) {
      final payload = payloads[i];
      apiLog
        ..writeln()
        ..writeln('── POST /api/orders (tentative ${i + 1}/${payloads.length}) ──')
        ..writeln(formatApiPayload(payload));

      logOrderFlow(
        'POST /api/orders attempt ${i + 1}/${payloads.length} table_id=${table.id}',
      );

      _remote.lastApiLog = null;
      try {
        final created = await _remote.createOrder(payload);
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }

        final orderId = OrderMapper.extractOrderIdFromPayload(created);
        if (orderId != null && orderId > 0) {
          apiLog.writeln('── Commande créée via POST /api/orders: $orderId ──');
          logOrderFlow('POST /api/orders SUCCESS orderId=$orderId');
          return orderId;
        }
        apiLog.writeln('── Réponse POST sans order id ──');
      } on ApiException catch (orderError) {
        apiLog.writeln('── POST /api/orders échoué ──');
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
        apiLog.writeln('Raison: ${orderError.message}');
        logOrderFlow('POST /api/orders FAILED: ${orderError.message}');
      }
    }

    return null;
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

    final guests = OrderMapper.guestsForTable(tables, table.id);
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
      number: OrderMapper.tableDisplayNumber('${table.tableNumber}'),
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

    final guests = OrderMapper.guestsForTable(tables, table.id);
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
      number: OrderMapper.tableDisplayNumber('${table.tableNumber}'),
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
      throw ApiException(message: 'Aucune suite à demander pour cette table.');
    }

    await _remote.requestCourses(orderId, courseIds);
    final updated = await _remote.fetchOrderDetail(orderId);
    await _local.saveOrderDetail(orderId, updated);
    final splitHint = _local.readSuivreSplitHint(orderId);
    final countHint = _local.readSuivreCountHint(orderId);
    return OrderMapper.fromOrderDetail(
      updated,
      previousDisplayEntries: previousDisplayEntries,
      suivreSplitHints: splitHint,
      suivreCountHint: countHint,
    );
  }

  Future<SessionOrder> markOrderPrinted(int orderId) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Impression impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    await _remote.markOrderPrinted(orderId);
    final detail = await _remote.fetchOrderDetail(orderId);
    await _local.saveOrderDetail(orderId, detail);
    return OrderMapper.fromOrderDetail(detail);
  }

  Future<SessionOrder> addSimpleProductToOrder({
    required int orderId,
    required int productId,
    required double unitPrice,
    int qty = 1,
    String comment = '',
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
      final detail = await _remote.fetchOrderDetail(orderId);
      final seatNumber = OrderMapper.resolveDefaultSeatNumber(detail);
      final course = OrderMapper.resolveAppendCourse(
        detail,
        seatNumber: seatNumber,
      );

      _ensureAddItemCourse(detail, apiLog);

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
      return _fetchAndMapOrder(orderId);
    } on ApiException catch (e) {
      apiLog.writeln('POST add failed, fallback PUT: ${e.message}');

      try {
        final detail = await _remote.fetchOrderDetail(orderId);
        _ensureAddItemCourse(detail, apiLog);

        final payload = OrderMapper.addOrIncrementSimpleItem(
          orderDetail: detail,
          productId: productId,
          unitPrice: unitPrice,
          qty: qty,
          comment: comment,
        );

        final updated = await _putOrderUpdate(
          orderId: orderId,
          payload: payload,
          apiLog: apiLog,
        );
        await _local.saveOrderDetail(orderId, updated);
        lastAddItemLog = apiLog.toString();
        return _fetchAndMapOrder(orderId);
      } on ApiException catch (fallbackError) {
        apiLog.writeln('ERREUR: ${fallbackError.message}');
        if (_remote.lastApiLog != null) {
          apiLog.writeln(_remote.lastApiLog);
        }
        lastAddItemLog = apiLog.toString();
        rethrow;
      }
    }
  }

  Future<SessionOrder> addComposedProductToOrder({
    required int orderId,
    required int productId,
    required double basePrice,
    required List<Map<String, dynamic>> menuSelections,
    String comment = '',
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
      final detail = await _remote.fetchOrderDetail(orderId);
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

      _ensureAddItemCourse(detail, apiLog);

      final payload = OrderMapper.appendComposedItem(
        orderDetail: detail,
        productId: productId,
        subTotal: basePrice + supplement,
        menuSelections: menuSelections,
        comment: comment,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();
      return _fetchAndMapOrder(orderId);
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
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
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();
      return _fetchAndMapOrder(orderId);
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

      final payload = OrderMapper.setLineQuantityAtIndex(
        orderDetail: detail,
        lineIndex: lineIndex,
        qty: qty,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();
      return OrderMapper.fromOrderDetail(updated);
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
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();
      return OrderMapper.fromOrderDetail(updated);
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
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

      final payload = OrderMapper.cancelOrderLinesAtIndices(
        orderDetail: detail,
        lineIndices: lineIndices.toSet(),
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();

      final splitHint = previousDisplayEntries == null
          ? _local.readSuivreSplitHint(orderId)
          : OrderMapper.suivreSplitPositions(previousDisplayEntries);
      final countHint = previousDisplayEntries == null
          ? _local.readSuivreCountHint(orderId)
          : OrderMapper.suivreSeparatorCount(previousDisplayEntries);

      final order = OrderMapper.fromOrderDetail(
        updated,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: splitHint,
        suivreCountHint: countHint,
      );

      final displayEntries = previousDisplayEntries == null
          ? order.displayEntries
          : OrderMapper.applyTrimmedSuivreLayout(
              products: order.products,
              trimmedLayout: previousDisplayEntries,
            );

      await _persistSuivreLayoutHints(orderId, displayEntries);
      return order.copyWith(displayEntries: displayEntries);
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

      final payload = OrderMapper.cancelOrderLineAtIndex(
        orderDetail: detail,
        lineIndex: lineIndex,
      );

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();
      return OrderMapper.fromOrderDetail(updated);
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastAddItemLog = apiLog.toString();
      rethrow;
    }
  }

  void _ensureAddItemCourse(
    Map<String, dynamic> detail,
    StringBuffer apiLog,
  ) {
    final seatNumber = OrderMapper.resolveDefaultSeatNumber(detail);
    final course = OrderMapper.resolveAppendCourse(
      detail,
      seatNumber: seatNumber,
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

  Future<SessionOrder> adjustOrderLineQuantityAtIndex({
    required int orderId,
    required int lineIndex,
    required int delta,
  }) async {
    return _mutateOrderLine(
      orderId: orderId,
      logTitle: 'Ajustement quantité ligne',
      mutate: (detail) => OrderMapper.adjustLineQuantityAtIndex(
        orderDetail: detail,
        lineIndex: lineIndex,
        delta: delta,
      ),
    );
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

  Future<SessionOrder> requestAllCourses(int orderId) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Envoi impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final detail = await _remote.fetchOrderDetail(orderId);
    final courseIds = OrderMapper.extractKitchenSendCourseIds(detail);
    if (courseIds.isEmpty) {
      throw ApiException(
        message: 'Aucun article à envoyer en cuisine pour cette table.',
      );
    }

    await _remote.requestCourses(orderId, courseIds);
    final updated = await _remote.fetchOrderDetail(orderId);
    await _local.saveOrderDetail(orderId, updated);
    return OrderMapper.fromOrderDetail(updated);
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
      apiLog.writeln('── GET /api/orders/$orderId ──');
      final detail = await _remote.fetchOrderDetail(orderId);
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

      apiLog.writeln('payment_mode_id=$paymentModeId');
      apiLog.writeln('── POST /api/orders/$orderId/pay ──');
      apiLog.writeln(
        formatApiPayload({
          'amount': amount,
          'payment_mode_id': paymentModeId,
        }),
      );

      _remote.lastApiLog = null;
      await _remote.payOrder(
        orderId: orderId,
        amount: amount,
        paymentModeId: paymentModeId,
      );
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }

      final updated = await _remote.fetchOrderDetail(orderId);
      await _local.saveOrderDetail(orderId, updated);
      lastPaymentLog = apiLog.toString();
      return OrderMapper.fromOrderDetail(updated);
    } on ApiException catch (e) {
      apiLog.writeln('ERREUR: ${e.message}');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      lastPaymentLog = apiLog.toString();
      rethrow;
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
      final payload = mutate(detail);

      final updated = await _putOrderUpdate(
        orderId: orderId,
        payload: payload,
        apiLog: apiLog,
      );
      await _local.saveOrderDetail(orderId, updated);
      lastAddItemLog = apiLog.toString();
      return _fetchAndMapOrder(orderId);
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
