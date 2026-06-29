import '../../core/network/api_exception.dart';
import '../../models/session_order.dart';
import '../models/create_table_order_result.dart';
import '../../services/connectivity_service.dart';
import '../datasources/order_local_datasource.dart';
import '../datasources/order_remote_datasource.dart';
import '../datasources/session_datasource.dart';
import '../mappers/order_mapper.dart';
import '../../utils/api_log.dart';

class OrderRepository {
  OrderRepository({
    required OrderRemoteDataSource remote,
    required OrderLocalDataSource local,
    required SessionRemoteDataSource sessionRemote,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _local = local,
        _sessionRemote = sessionRemote,
        _connectivity = connectivity;

  final OrderRemoteDataSource _remote;
  final OrderLocalDataSource _local;
  final SessionRemoteDataSource _sessionRemote;
  final ConnectivityService _connectivity;

  /// Last create-order debug trace (for on-screen error/success dialog).
  String? lastCreateOrderLog;

  /// Returns order detail mapped to [SessionOrder], using cache when offline.
  Future<SessionOrder> getOrderDetail(int orderId) async {
    final online = await _connectivity.isOnline;

    if (online) {
      final detail = await _remote.fetchOrderDetail(orderId);
      await _local.saveOrderDetail(orderId, detail);
      return OrderMapper.fromOrderDetail(detail);
    }

    final cached = _local.readOrderDetail(orderId);
    if (cached != null) {
      return OrderMapper.fromOrderDetail(cached);
    }

    throw ApiException(
      message: 'Détails de commande indisponibles hors ligne.',
    );
  }

  Future<void> closeOrder(int orderId) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Annulation impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    await _remote.closeOrder(orderId);
    await _local.removeOrderDetail(orderId);
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

    final orderId = await _createOrderOnTable(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      salesZoneId: resolvedSalesZoneId,
      tables: tables,
      apiLog: apiLog,
    );

    if (orderId == null || orderId <= 0) {
      lastCreateOrderLog = apiLog.toString();
      throw ApiException(
        message:
            'Commande créée mais introuvable. Tirez pour rafraîchir la liste.',
      );
    }

    apiLog.writeln('── GET /api/orders/$orderId (seat_orders) ──');
    final detail = await _remote.fetchOrderDetail(orderId);
    await _local.saveOrderDetail(orderId, detail);
    apiLog.writeln(formatApiPayload(detail));

    final displayNumber = OrderMapper.tableDisplayNumber('${table.tableNumber}');
    final order =
        OrderMapper.fromOrderDetail(detail).copyWith(number: displayNumber);

    apiLog
      ..writeln()
      ..writeln('── Résultat final ──')
      ..writeln('orderId=${order.id}, affichage=${order.number}');

    lastCreateOrderLog = apiLog.toString();
    return CreateTableOrderResult(order: order, apiLog: apiLog.toString());
  }

  Future<int?> _createOrderOnTable({
    required ResolvedTable table,
    required int waiterId,
    required int numberOfGuests,
    required int? salesZoneId,
    required List<Map<String, dynamic>> tables,
    required StringBuffer apiLog,
  }) async {
    final orderPayload = OrderMapper.buildCreateOrderPayload(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      tableId: table.id,
      salesZoneId: salesZoneId,
    );

    apiLog
      ..writeln('── Données table (GET /api/tables/list) ──')
      ..writeln('table_id=${table.id}')
      ..writeln('table_number=${table.tableNumber}')
      ..writeln('status=${table.status ?? '—'}')
      ..writeln('sales_zone_id=${salesZoneId ?? '—'}')
      ..writeln()
      ..writeln('── POST /api/orders payload ──')
      ..writeln(formatApiPayload(orderPayload));

    Map<String, dynamic>? created;
    _remote.lastApiLog = null;
    try {
      created = await _remote.createOrder(orderPayload);
      apiLog.writeln('── Via POST /api/orders ──');
    } on ApiException catch (orderError) {
      apiLog.writeln('── POST /api/orders échoué ──');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      apiLog.writeln('Raison: ${orderError.message}');
      created = await _startTableSessionFallback(
        table: table,
        waiterId: waiterId,
        numberOfGuests: numberOfGuests,
        apiLog: apiLog,
      );
    }

    if (_remote.lastApiLog != null) {
      apiLog.writeln(_remote.lastApiLog);
    }

    var orderId = created == null
        ? null
        : OrderMapper.extractOrderIdFromPayload(_unwrapOrderResponse(created));

    if (orderId != null && orderId > 0) {
      return orderId;
    }

    apiLog.writeln('── Order id absent après POST /api/orders ──');
    created = await _startTableSessionFallback(
      table: table,
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      apiLog: apiLog,
    );

    if (_remote.lastApiLog != null) {
      apiLog.writeln(_remote.lastApiLog);
    }

    orderId = created == null
        ? null
        : OrderMapper.extractOrderIdFromPayload(_unwrapOrderResponse(created));

    if (orderId != null && orderId > 0) {
      return orderId;
    }

    orderId = await _resolveOrderIdForTable(
      tableId: table.id,
      tableNumber: table.tableNumber,
      initialTables: tables,
    );
    if (orderId != null && orderId > 0) {
      apiLog.writeln('── Order id résolu via GET /api/tables/list: $orderId ──');
      return orderId;
    }

    orderId = OrderMapper.activeOrderIdForTableId(tables, table.id);
    if (orderId != null && orderId > 0) {
      apiLog.writeln('── Order id depuis tables list: $orderId ──');
    }

    return orderId;
  }

  Future<Map<String, dynamic>?> _startTableSessionFallback({
    required ResolvedTable table,
    required int waiterId,
    required int numberOfGuests,
    required StringBuffer apiLog,
  }) async {
    final sessionPayload = OrderMapper.buildStartTableSessionPayload(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
    );

    _remote.lastApiLog = null;
    try {
      final created = await _remote.startTableSession(table.id, sessionPayload);
      apiLog.writeln('── Fallback POST /api/tables/${table.id}/session ──');
      return created;
    } on ApiException catch (sessionError) {
      apiLog.writeln('── POST /api/tables/${table.id}/session échoué ──');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      apiLog.writeln('Raison: ${sessionError.message}');
      rethrow;
    }
  }

  Map<String, dynamic> _unwrapOrderResponse(Map<String, dynamic> data) {
    final order = data['order'];
    if (order is Map<String, dynamic>) return order;

    final activeOrder = data['active_order'] ?? data['current_order'];
    if (activeOrder is Map<String, dynamic>) return activeOrder;

    final orderId = data['order_id'];
    if (orderId is num) {
      return {
        'id': orderId.toInt(),
        'table_id': data['table_id'],
        'number_of_guests': data['number_of_guests'],
      };
    }

    return data;
  }

  Future<int?> _resolveOrderIdForTable({
    required int tableId,
    int? tableNumber,
    List<Map<String, dynamic>>? initialTables,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 350 * attempt));
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

  Future<void> requestNextCourses(int orderId) async {
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
    await _local.saveOrderDetail(orderId, detail);
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
}
