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

  List<SessionOrder> get cachedOpenOrders =>
      _local.readOpenOrders().map(OrderMapper.fromOpenOrder).toList();

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
      return data.openOrders.map(OrderMapper.fromOpenOrder).toList();
    }

    if (_local.readOpenOrders().isNotEmpty) {
      return cachedOpenOrders;
    }

    throw ApiException(message: 'Aucune commande disponible hors ligne.');
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
}
