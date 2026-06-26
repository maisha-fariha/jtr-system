import 'order_product.dart';

class SessionOrder {
  const SessionOrder({
    required this.number,
    required this.tableNumber,
    required this.products,
    this.isSelected = false,
    this.isExpanded = false,
  });

  final String number;
  final int tableNumber;
  final List<OrderProduct> products;
  final bool isSelected;
  final bool isExpanded;

  double get total => products.fold(0, (sum, p) => sum + p.totalPrice);

  int get itemCount => products.fold(0, (sum, p) => sum + p.quantity);

  SessionOrder copyWith({
    String? number,
    int? tableNumber,
    List<OrderProduct>? products,
    bool? isSelected,
    bool? isExpanded,
  }) {
    return SessionOrder(
      number: number ?? this.number,
      tableNumber: tableNumber ?? this.tableNumber,
      products: products ?? this.products,
      isSelected: isSelected ?? this.isSelected,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}
