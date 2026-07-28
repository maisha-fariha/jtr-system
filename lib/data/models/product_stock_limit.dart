/// Post-send stock allowance for a product (ordered qty becomes the limit).
class ProductStockLimit {
  const ProductStockLimit({
    required this.limitQty,
    required this.baselineOrderedQty,
  });

  /// Stock/order limit captured at send (e.g. 5 Coca-Colas sent → limit 5).
  final int limitQty;

  /// Ordered qty when [limitQty] was captured.
  final int baselineOrderedQty;

  /// Remaining stock shown on the badge; decreases as more units are added.
  int remainingQty(int currentOrderedQty) {
    final additional = currentOrderedQty - baselineOrderedQty;
    return (limitQty - additional).clamp(0, limitQty);
  }

  bool isExhausted(int currentOrderedQty) =>
      remainingQty(currentOrderedQty) <= 0;
}
