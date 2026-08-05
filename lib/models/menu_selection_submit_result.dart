/// Returned from [MenuSelectionPage] when the waiter confirms — table details
/// applies optimistic UI and syncs the API in background.
class MenuSelectionSubmitResult {
  const MenuSelectionSubmitResult({
    required this.productId,
    required this.productName,
    required this.basePrice,
    required this.menuSelections,
    this.quantity = 1,
    this.comment = '',
  });

  final int productId;
  final String productName;
  final double basePrice;
  final List<Map<String, dynamic>> menuSelections;

  /// How many menus to insert on the order (from quantity dialog).
  final int quantity;
  final String comment;
}
