import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';
import 'package:jtr_system/models/order_display_entry.dart';
import 'package:jtr_system/models/order_product.dart';
import 'package:jtr_system/models/session_order.dart';

void main() {
  final product = OrderProduct(
    name: 'THE',
    quantity: '1',
    price: '25,00 €',
  );

  test('predictAfterCancelLineAtIndex clears last product from UI model', () {
    final current = SessionOrder(
      id: 1,
      number: '9',
      numberColor: Colors.red,
      group: '1',
      poste: 'SA',
      profitCenter: 'SUR PLACE',
      couverts: '2',
      impressionCount: 0,
      impressionColor: Colors.grey,
      total: '25,00 €',
      products: [product],
      displayEntries: [
        OrderDisplayEntry.product(product: product, lineIndex: 0),
      ],
    );

    final predicted = OrderMapper.predictAfterCancelLineAtIndex(current, 0);
    expect(predicted.products, isEmpty);
    expect(
      predicted.displayEntries
          .where((e) => e.type == OrderDisplayEntryType.product),
      isEmpty,
    );
    expect(predicted.itemCount, 0);
  });
}
