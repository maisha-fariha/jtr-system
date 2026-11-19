class OrderProduct {
  const OrderProduct({
    required this.quantity,
    required this.name,
    required this.price,
    this.message,
    this.menuItems = const [],
    this.isOffered = false,
    this.isStillMenuMissing = false,
    this.seatNumber = 1,
  });

  final String quantity;
  final String name;
  final String price;
  final String? message;
  final List<String> menuItems;
  final bool isOffered;

  /// "Choix en attente": optional menu choices can still be added.
  final bool isStillMenuMissing;

  /// Seat (`seat_orders[].seat_number`) this line belongs to.
  final int seatNumber;

  bool get hasMenuItems => menuItems.isNotEmpty;

  OrderProduct copyWith({
    String? quantity,
    String? name,
    String? price,
    String? message,
    List<String>? menuItems,
    bool? isOffered,
    bool? isStillMenuMissing,
    int? seatNumber,
    bool clearMessage = false,
  }) {
    return OrderProduct(
      quantity: quantity ?? this.quantity,
      name: name ?? this.name,
      price: price ?? this.price,
      message: clearMessage ? null : (message ?? this.message),
      menuItems: menuItems ?? this.menuItems,
      isOffered: isOffered ?? this.isOffered,
      isStillMenuMissing: isStillMenuMissing ?? this.isStillMenuMissing,
      seatNumber: seatNumber ?? this.seatNumber,
    );
  }
}
