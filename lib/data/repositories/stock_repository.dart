import '../../services/connectivity_service.dart';
import '../datasources/stock_remote_datasource.dart';
import '../models/stock/product_stock_limit.dart';

/// Stock Visuel API facade. Soft-fails on limits fetch so order UI stays usable.
class StockRepository {
  StockRepository({
    required StockRemoteDataSource remote,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _connectivity = connectivity;

  final StockRemoteDataSource _remote;
  final ConnectivityService _connectivity;

  Map<int, ProductStockLimit> _cachedLimits = {};

  Map<int, ProductStockLimit> get cachedLimits =>
      Map<int, ProductStockLimit>.unmodifiable(_cachedLimits);

  /// Loads limits. Returns empty map on network/API failure (no throw).
  Future<Map<int, ProductStockLimit>> getLimits({
    bool forceRefresh = true,
  }) async {
    if (!forceRefresh && _cachedLimits.isNotEmpty) {
      return cachedLimits;
    }

    try {
      if (!await _connectivity.isOnline) {
        return cachedLimits;
      }
      final limits = await _remote.fetchLimits();
      _cachedLimits = limits;
      return cachedLimits;
    } catch (_) {
      return cachedLimits;
    }
  }

  Future<ProductStockStatus> getProductStatus(int productId) {
    return _remote.fetchProductStatus(productId);
  }

  Future<void> setLimit({
    required int productId,
    required int dailyLimit,
  }) {
    return _remote.setLimit(productId: productId, dailyLimit: dailyLimit);
  }

  Future<void> removeLimit(int productId) {
    return _remote.removeLimit(productId);
  }

  Future<void> blockProduct(int productId) {
    return _remote.blockProduct(productId);
  }

  Future<void> freeProduct(int productId) {
    return _remote.freeProduct(productId);
  }

  Future<void> applyDeltas(Map<int, int> deltas) {
    if (deltas.isEmpty) return Future.value();
    return _remote.applyDeltas(deltas);
  }

  void patchLocalLimit(ProductStockLimit limit) {
    _cachedLimits = {..._cachedLimits, limit.productId: limit};
  }

  void removeLocalLimit(int productId) {
    final next = Map<int, ProductStockLimit>.from(_cachedLimits);
    next.remove(productId);
    _cachedLimits = next;
  }

  void clearCache() {
    _cachedLimits = {};
  }
}
