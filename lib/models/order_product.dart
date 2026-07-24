class OrderProduct {
  const OrderProduct({
    required this.quantity,
    required this.name,
    required this.price,
    this.message,
    this.menuItems = const [],
    this.isOffered = false,
  });

  final String quantity;
  final String name;
  final String price;
  final String? message;
  final List<String> menuItems;
  final bool isOffered;

  bool get hasMenuItems => menuItems.isNotEmpty;

  OrderProduct copyWith({
    String? quantity,
    String? name,
    String? price,
    String? message,
    List<String>? menuItems,
    bool? isOffered,
    bool clearMessage = false,
  }) {
    return OrderProduct(
      quantity: quantity ?? this.quantity,
      name: name ?? this.name,
      price: price ?? this.price,
      message: clearMessage ? null : (message ?? this.message),
      menuItems: menuItems ?? this.menuItems,
      isOffered: isOffered ?? this.isOffered,
    );
  }
}
