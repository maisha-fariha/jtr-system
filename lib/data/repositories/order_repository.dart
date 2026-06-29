import '../../core/network/api_exception.dart';
import '../../models/session_order.dart';
import '../models/create_table_order_result.dart';
import '../../services/connectivity_service.dart';
import '../datasources/order_local_datasource.dart';
import '../datasources/order_remote_datasource.dart';
import '../mappers/order_mapper.dart';
import '../models/open_order_summary.dart';
import '../../utils/api_log.dart';

class OrderRepository {
  OrderRepository({
    required OrderRemoteDataSource remote,
    required OrderLocalDataSource local,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _local = local,
        _connectivity = connectivity;

  final OrderRemoteDataSource _remote;
  final OrderLocalDataSource _local;
  final ConnectivityService _connectivity;

  /// Last create-order debug trace (for on-screen error/success dialog).
  String? lastCreateOrderLog;

  List<SessionOrder> get cachedOpenOrders => mergeCachedDetails(
        _local.readOpenOrders().map(OrderMapper.fromOpenOrder).toList(),
      );

  /// Applies cached [GET /api/orders/:id] data onto a summary row.
  SessionOrder mergeCachedDetail(SessionOrder summary) {
    if (summary.isLocalOnly) return summary;

    final cached = _local.readOrderDetail(summary.id);
    if (cached == null) return summary;

    return OrderMapper.fromOrderDetail(cached).copyWith(number: summary.number);
  }

  List<SessionOrder> mergeCachedDetails(List<SessionOrder> summaries) =>
      summaries.map(mergeCachedDetail).toList();

  /// Loads open orders from cache first, then refreshes when online.
  Future<List<SessionOrder>> getOpenOrders({bool forceRefresh = false}) async {
    if (!forceRefresh && _local.readOpenOrders().isNotEmpty) {
      _refreshOpenOrdersInBackground();
      return cachedOpenOrders;
    }

    final online = await _connectivity.isOnline;
    if (online) {
      final data = await _remote.fetchOpenOrders();
      await _local.saveOpenOrders(data.openOrders);
      return mergeCachedDetails(
        data.openOrders.map(OrderMapper.fromOpenOrder).toList(),
      );
    }

    if (_local.readOpenOrders().isNotEmpty) {
      return cachedOpenOrders;
    }

    throw ApiException(message: 'Aucune commande disponible hors ligne.');
  }

  /// Fetches order details for rows missing cached detail (list column metadata).
  Future<void> enrichMissingOrderDetails(
    void Function(SessionOrder updated) onUpdated,
  ) async {
    if (!await _connectivity.isOnline) return;

    final summaries = _local.readOpenOrders().where(
      (summary) => _local.readOrderDetail(summary.id) == null,
    );

    await Future.wait(
      summaries.map((summary) async {
        final base = OrderMapper.fromOpenOrder(summary);
        final enriched = await _fetchAndCacheDetail(base);
        if (enriched != null) {
          onUpdated(enriched);
        }
      }),
    );
  }

  Future<SessionOrder?> _fetchAndCacheDetail(SessionOrder summary) async {
    if (summary.isLocalOnly) return null;

    try {
      final detail = await _remote.fetchOrderDetail(summary.id);
      await _local.saveOrderDetail(summary.id, detail);
      return OrderMapper.fromOrderDetail(detail).copyWith(number: summary.number);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshOpenOrdersInBackground() async {
    try {
      if (!await _connectivity.isOnline) return;
      final data = await _remote.fetchOpenOrders();
      await _local.saveOpenOrders(data.openOrders);
    } catch (_) {
      // Keep cached list when background refresh fails.
    }
  }

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
    await _local.removeFromOpenOrders(orderId);
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

  Future<List<SessionOrder>> refreshOpenOrders() =>
      getOpenOrders(forceRefresh: true);

  /// Refreshes open orders from the API and keeps [ensureOrderId] visible when
  /// the list endpoint lags behind [POST /api/orders] (detail still from API).
  Future<List<SessionOrder>> refreshOpenOrdersEnsuring(
    int ensureOrderId, {
    int? fallbackTableNumber,
  }) async {
    if (!await _connectivity.isOnline) {
      return cachedOpenOrders;
    }

    final data = await _remote.fetchOpenOrders();
    var summaries = List<OpenOrderSummary>.from(data.openOrders);

    if (!summaries.any((order) => order.id == ensureOrderId)) {
      final detail = _local.readOrderDetail(ensureOrderId) ??
          await _remote.fetchOrderDetail(ensureOrderId);
      await _local.saveOrderDetail(ensureOrderId, detail);
      summaries = [
        OrderMapper.summaryFromDetail(
          detail,
          fallbackTableNumber: fallbackTableNumber,
        ),
        ...summaries,
      ];
    }

    await _local.saveOpenOrders(summaries);
    return mergeCachedDetails(
      summaries.map(OrderMapper.fromOpenOrder).toList(),
    );
  }

  OpenOrderSummary? findCachedSummary(int orderId) {
    for (final order in _local.readOpenOrders()) {
      if (order.id == orderId) return order;
    }
    return null;
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

    final table = OrderMapper.resolveTable(tables, tableNumber);
    if (table == null) {
      throw ApiException(message: 'Table $tableNumber introuvable.');
    }

    apiLog.writeln('Table résolue: id=${table.id}, numéro=$tableNumber');

    final orderPayload = OrderMapper.buildCreateOrderPayload(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
      tableId: table.id,
      salesZoneId: salesZoneId ?? table.salesZoneId,
    );

    Map<String, dynamic> created;
    _remote.lastApiLog = null;
    try {
      created = await _remote.createOrder(orderPayload);
    } on ApiException catch (orderError) {
      apiLog.writeln('── POST /api/orders échoué ──');
      if (_remote.lastApiLog != null) {
        apiLog.writeln(_remote.lastApiLog);
      }
      apiLog.writeln('Raison: ${orderError.message}');
      lastCreateOrderLog = apiLog.toString();
      rethrow;
    }

    apiLog.writeln('── Via POST /api/orders ──');
    if (_remote.lastApiLog != null) {
      apiLog.writeln(_remote.lastApiLog);
    }

    created = _unwrapOrderResponse(created);
    apiLog
      ..writeln()
      ..writeln('── Données extraites après création ──')
      ..writeln(formatApiPayload(created));

    var orderId = OrderMapper.orderIdFromDetail(created);
    if (orderId <= 0) {
      orderId = (await _resolveOrderIdForTable(
            tableId: table.id,
            tableNumber: int.tryParse(tableNumber.trim()),
          )) ??
          0;
      if (orderId > 0) {
        apiLog.writeln('── Order id résolu via open-orders: $orderId ──');
      }
    }

    if (orderId <= 0) {
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

    final parsedTableNumber = int.tryParse(tableNumber.trim());
    await refreshOpenOrdersEnsuring(
      orderId,
      fallbackTableNumber: parsedTableNumber,
    );

    final inOpenList = findCachedSummary(orderId) != null;
    apiLog.writeln(
      inOpenList
          ? 'Présent dans open-orders: oui (id=$orderId)'
          : 'Présent via détail commande: oui (id=$orderId)',
    );

    final displayNumber = OrderMapper.tableDisplayNumber(tableNumber);
    final order =
        OrderMapper.fromOrderDetail(detail).copyWith(number: displayNumber);

    apiLog
      ..writeln()
      ..writeln('── Résultat final ──')
      ..writeln('orderId=${order.id}, affichage=${order.number}');

    lastCreateOrderLog = apiLog.toString();
    return CreateTableOrderResult(order: order, apiLog: apiLog.toString());
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
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 350 * attempt));
      }

      final openOrders = await _remote.fetchOpenOrders();
      for (final summary in openOrders.openOrders) {
        if (summary.tableId == tableId) return summary.id;
        if (tableNumber != null && summary.tableNumber == tableNumber) {
          return summary.id;
        }
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
