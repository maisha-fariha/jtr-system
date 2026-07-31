import 'package:get/get.dart';

import '../data/models/stock/product_stock_limit.dart';
import '../data/repositories/stock_repository.dart';

/// Local Stock Visuel state for one open order screen.
///
/// Keeps [stockDeltas] optimistic until Send → apply-deltas.
/// Does not mutate order lines — callers own cart mutations.
class StockVisualState {
  StockVisualState([this._repository]);

  final StockRepository? _repository;

  final stockLimits = <int, ProductStockLimit>{}.obs;
  final stockDeltas = <int, int>{}.obs;
  final isStockVisualMode = false.obs;
  final isLoadingLimits = false.obs;
  final stockUiRevision = 0.obs;

  bool get isAvailable => _repository != null;

  void _bumpUi() => stockUiRevision.value++;

  Future<void> loadLimits({bool forceRefresh = true}) async {
    final repo = _repository;
    if (repo == null) return;

    isLoadingLimits.value = true;
    try {
      final limits = await repo.getLimits(forceRefresh: forceRefresh);
      stockLimits
        ..clear()
        ..addAll(limits);
      _bumpUi();
    } finally {
      isLoadingLimits.value = false;
    }
  }

  ProductStockLimit? limitFor(int productId) => stockLimits[productId];

  int deltaFor(int productId) => stockDeltas[productId] ?? 0;

  /// remaining = current_stock + stock_deltas[id]
  int? remainingFor(int productId) {
    final limit = stockLimits[productId];
    if (limit == null || limit.isFreed) return null;
    return limit.currentStock + deltaFor(productId);
  }

  /// Badge value: max(0, remaining). Null = no badge.
  int? badgeFor(int productId) {
    final remaining = remainingFor(productId);
    if (remaining == null) return null;
    return remaining < 0 ? 0 : remaining;
  }

  bool isTracked(int productId) {
    final limit = stockLimits[productId];
    return limit != null && !limit.isFreed;
  }

  bool canAdd(int productId, {int qty = 1}) {
    if (!isTracked(productId)) return true;
    final remaining = remainingFor(productId) ?? 0;
    return remaining >= qty;
  }

  /// Consume [qty] locally (negative delta). No API.
  void consumeLocally(int productId, int qty) {
    if (qty <= 0 || !isTracked(productId)) return;
    stockDeltas[productId] = deltaFor(productId) - qty;
    stockDeltas.refresh();
    _bumpUi();
  }

  /// Restore [qty] locally (positive delta). No API.
  void restoreLocally(int productId, int qty) {
    if (qty <= 0 || !isTracked(productId)) return;
    stockDeltas[productId] = deltaFor(productId) + qty;
    stockDeltas.refresh();
    _bumpUi();
  }

  /// Snapshot of non-zero deltas for apply-deltas.
  Map<int, int> pendingDeltas() {
    return {
      for (final entry in stockDeltas.entries)
        if (entry.value != 0) entry.key: entry.value,
    };
  }

  void clearDeltas() {
    stockDeltas.clear();
    _bumpUi();
  }

  List<ProductStockLimit> trackedLimitsSorted() {
    final list = stockLimits.values.where((l) => !l.isFreed).toList()
      ..sort((a, b) {
        final an = (a.productName ?? '').toLowerCase();
        final bn = (b.productName ?? '').toLowerCase();
        return an.compareTo(bn);
      });
    return list;
  }

  void applyBlockedLocally(int productId, {String? productName}) {
    final existing = stockLimits[productId];
    if (existing == null) {
      stockLimits[productId] = ProductStockLimit(
        productId: productId,
        productName: productName,
        currentStock: 0,
        isBlocked: true,
      );
    } else {
      stockLimits[productId] = existing.copyWith(
        currentStock: 0,
        isBlocked: true,
      );
    }
    stockLimits.refresh();
    _bumpUi();
  }

  void dispose() {
    stockLimits.close();
    stockDeltas.close();
    isStockVisualMode.close();
    isLoadingLimits.close();
    stockUiRevision.close();
  }
}
