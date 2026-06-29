import '../../core/network/api_exception.dart';
import '../../models/session_order.dart';
import '../../services/connectivity_service.dart';
import '../datasources/order_local_datasource.dart';
import '../datasources/order_remote_datasource.dart';
import '../mappers/order_mapper.dart';
import '../models/open_order_summary.dart';

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

  OpenOrderSummary? findCachedSummary(int orderId) {
    for (final order in _local.readOpenOrders()) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  Future<SessionOrder> createTableOrder({
    required int waiterId,
    required String tableNumber,
    required int numberOfGuests,
    required List<Map<String, dynamic>> tables,
    int? salesZoneId,
  }) async {
    if (!await _connectivity.isOnline) {
      throw ApiException(
        message: 'Création impossible hors ligne. Vérifiez votre réseau.',
      );
    }

    final table = OrderMapper.resolveTable(tables, tableNumber);
    if (table == null) {
      throw ApiException(message: 'Table $tableNumber introuvable.');
    }

    final sessionPayload = OrderMapper.buildStartTableSessionPayload(
      waiterId: waiterId,
      numberOfGuests: numberOfGuests,
    );

    Map<String, dynamic> created;
    try {
      created = await _remote.startTableSession(table.id, sessionPayload);
    } on ApiException {
      final orderPayload = OrderMapper.buildCreateOrderPayload(
        waiterId: waiterId,
        numberOfGuests: numberOfGuests,
        tableId: table.id,
        salesZoneId: salesZoneId ?? table.salesZoneId,
      );
      created = await _remote.createOrder(orderPayload);
    }

    created = _unwrapOrderResponse(created);
    var orderId = (created['id'] as num?)?.toInt();

    if (orderId == null) {
      final detail = await _findOpenOrderDetailForTable(table.id);
      if (detail != null) {
        created = detail;
        orderId = (created['id'] as num?)?.toInt();
      }
    }

    if (orderId != null) {
      await _local.saveOrderDetail(orderId, created);
    }

    final data = await _remote.fetchOpenOrders();
    await _local.saveOpenOrders(data.openOrders);

    return OrderMapper.fromOrderDetail(created);
  }

  Map<String, dynamic> _unwrapOrderResponse(Map<String, dynamic> data) {
    final order = data['order'];
    if (order is Map<String, dynamic>) return order;
    return data;
  }

  Future<Map<String, dynamic>?> _findOpenOrderDetailForTable(int tableId) async {
    final openOrders = await _remote.fetchOpenOrders();
    for (final summary in openOrders.openOrders) {
      if (summary.tableId == tableId) {
        return _remote.fetchOrderDetail(summary.id);
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
