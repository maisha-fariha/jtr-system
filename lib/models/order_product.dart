class OrderProduct {
  const OrderProduct({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.note = '',
  });

  final String id;
  final String name;
  final double unitPrice;
  final int quantity;
  final String note;

  double get totalPrice => unitPrice * quantity;

  OrderProduct copyWith({
    String? id,
    String? name,
    double? unitPrice,
    int? quantity,
    String? note,
  }) {
    return OrderProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }
}
