class OrderProduct {
  const OrderProduct({
    required this.quantity,
    required this.name,
    required this.price,
    this.message,
  });

  final String quantity;
  final String name;
  final String price;
  final String? message;

  OrderProduct copyWith({
    String? quantity,
    String? name,
    String? price,
    String? message,
    bool clearMessage = false,
  }) {
    return OrderProduct(
      quantity: quantity ?? this.quantity,
      name: name ?? this.name,
      price: price ?? this.price,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
