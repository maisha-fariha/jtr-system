import 'order_product.dart';

enum OrderDisplayEntryType { product, suivreSeparator }

class OrderDisplayEntry {
  const OrderDisplayEntry._({
    required this.type,
    this.product,
    this.lineIndex,
  });

  const OrderDisplayEntry.product({
    required OrderProduct product,
    required int lineIndex,
  }) : this._(
          type: OrderDisplayEntryType.product,
          product: product,
          lineIndex: lineIndex,
        );

  const OrderDisplayEntry.suivre()
      : this._(type: OrderDisplayEntryType.suivreSeparator);

  final OrderDisplayEntryType type;
  final OrderProduct? product;
  final int? lineIndex;
}
