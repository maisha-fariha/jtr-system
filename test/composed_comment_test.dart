import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';

void main() {
  test('optimistic composed add keeps the typed message on the line', () {
    final current =
        OrderMapper.buildSessionPlaceholderOrder(tableNumber: 11, numberOfGuests: 2);
    final predicted = OrderMapper.predictAfterAppendComposedProduct(
      current: current,
      cachedDetail: null,
      productId: 1,
      productName: 'PTIT PAUL POULET',
      basePrice: 59,
      menuSelections: const [],
      quantity: 2,
      comment: 'sans sel | bien cuit',
    );
    expect(predicted.products.last.message, 'sans sel | bien cuit');
    final shown = predicted.displayEntries
        .where((e) => e.product != null)
        .map((e) => e.product!.message);
    expect(shown, contains('sans sel | bien cuit'));
  });
}
