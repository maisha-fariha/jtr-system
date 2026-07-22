/// Constants for empty-table order creation (POST /api/orders seed line).
class OrderCreateConstants {
  OrderCreateConstants._();

  /// Placeholder product required by the POS when opening an empty table.
  /// Stripped/hidden in UI after create — must match backend expectation.
  static const int emptyOrderSeedProductId = 13;
}
