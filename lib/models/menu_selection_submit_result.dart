/// Returned from [MenuSelectionPage] when the waiter confirms — table details
/// applies optimistic UI and syncs the API in background.
class MenuSelectionSubmitResult {
  const MenuSelectionSubmitResult({
    required this.productId,
    required this.productName,
    required this.basePrice,
    required this.menuSelections,
    this.comment = '',
  });

  final int productId;
  final String productName;
  final double basePrice;
  final List<Map<String, dynamic>> menuSelections;
  final String comment;
}
