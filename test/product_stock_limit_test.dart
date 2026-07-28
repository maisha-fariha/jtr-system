import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/models/product_stock_limit.dart';

void main() {
  group('ProductStockLimit', () {
    test('remaining starts at sent qty and decreases with each add', () {
      // Sent 5 Coca-Colas → badge 5; each extra add decreases remaining.
      const limit = ProductStockLimit(limitQty: 5, baselineOrderedQty: 5);

      expect(limit.remainingQty(5), 5);
      expect(limit.remainingQty(6), 4);
      expect(limit.remainingQty(7), 3);
      expect(limit.remainingQty(9), 1);
      expect(limit.remainingQty(10), 0);
      expect(limit.isExhausted(10), isTrue);
      expect(limit.isExhausted(9), isFalse);
    });

    test('remaining never goes below zero', () {
      const limit = ProductStockLimit(limitQty: 2, baselineOrderedQty: 2);
      expect(limit.remainingQty(20), 0);
    });
  });
}
