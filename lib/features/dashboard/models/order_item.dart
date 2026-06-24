/// A single line item inside a table order.
class OrderItem {
  const OrderItem({
    required this.quantity,
    required this.name,
    required this.price,
    this.course = 1,
  });

  final int quantity;
  final String name;
  final double price;
  final int course;

  String get formattedPrice =>
      '${price.toStringAsFixed(2).replaceAll('.', ',')} €';
}
