import 'order_product.dart';

enum OrderDisplayEntryType { product, suivreSeparator }

class OrderDisplayEntry {
  const OrderDisplayEntry._({
    required this.type,
    this.product,
    this.lineIndex,
    this.sectionIndex,
  });

  const OrderDisplayEntry.product({
    required OrderProduct product,
    required int lineIndex,
    int sectionIndex = 0,
  }) : this._(
          type: OrderDisplayEntryType.product,
          product: product,
          lineIndex: lineIndex,
          sectionIndex: sectionIndex,
        );

  const OrderDisplayEntry.suivre({required int sectionIndex})
      : this._(
          type: OrderDisplayEntryType.suivreSeparator,
          sectionIndex: sectionIndex,
        );

  final OrderDisplayEntryType type;
  final OrderProduct? product;
  final int? lineIndex;

  /// `0` = first course. `1+` = À suivre section index (matches collapse state).
  final int? sectionIndex;
}
