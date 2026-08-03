/// Daily stock limit for one product (from GET /api/stock/limits).
class ProductStockLimit {
  const ProductStockLimit({
    required this.productId,
    required this.currentStock,
    this.productName,
    this.dailyLimit,
    this.isFreed = false,
    this.isBlocked = false,
  });

  final int productId;
  final String? productName;

  /// Remaining quantity on the server for the active day.
  final int currentStock;

  /// Configured daily limit when known (optional).
  final int? dailyLimit;

  /// Freed products skip badges and enforcement.
  final bool isFreed;

  /// Explicitly blocked (0 remaining).
  final bool isBlocked;

  ProductStockLimit copyWith({
    int? productId,
    String? productName,
    int? currentStock,
    int? dailyLimit,
    bool? isFreed,
    bool? isBlocked,
  }) {
    return ProductStockLimit(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      currentStock: currentStock ?? this.currentStock,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      isFreed: isFreed ?? this.isFreed,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}

/// Per-product status from GET /api/stock/product/{id}/status.
class ProductStockStatus {
  const ProductStockStatus({
    required this.productId,
    required this.currentStock,
    this.productName,
    this.dailyLimit,
    this.isFreed = false,
    this.isBlocked = false,
    this.hasLimit = true,
  });

  final int productId;
  final String? productName;
  final int currentStock;
  final int? dailyLimit;
  final bool isFreed;
  final bool isBlocked;
  final bool hasLimit;
}
