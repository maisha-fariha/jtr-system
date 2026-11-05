import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/models/catalog/catalog_product_model.dart';

CatalogProductModel _from({
  required String price,
  String? priceType,
  bool isComposed = false,
}) {
  return CatalogProductModel.fromJson({
    'id': 1,
    'name': 'Test',
    'price': price,
    'is_composed': isComposed,
    'is_active': true,
    if (priceType != null) 'price_type': priceType,
    'category': {'id': 4, 'name': 'Cat'},
  });
}

void main() {
  group('prix libre uses price_type only', () {
    test('price_type free → requires cashier price even if price is 0', () {
      final product = _from(price: '0.00', priceType: 'free');
      expect(product.isPrixLibre, isTrue);
      expect(product.requiresCashierPrice, isTrue);
    });

    test('price_type normal + price 0 → normal product, no price prompt', () {
      final product = _from(price: '0.00', priceType: 'normal');
      expect(product.isPrixLibre, isFalse);
      expect(product.requiresCashierPrice, isFalse);
      expect(product.formattedPrice, '0,00');
    });

    test('missing price_type + price 0 → not free-priced', () {
      final product = _from(price: '0');
      expect(product.isPrixLibre, isFalse);
      expect(product.requiresCashierPrice, isFalse);
    });

    test('composed product never requires simple cashier price prompt', () {
      final product = _from(
        price: '0.00',
        priceType: 'free',
        isComposed: true,
      );
      expect(product.isPrixLibre, isTrue);
      expect(product.requiresCashierPrice, isFalse);
    });
  });
}
