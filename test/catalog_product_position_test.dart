import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/models/catalog/catalog_product_model.dart';

CatalogProductModel _product({
  required int id,
  required String name,
  required int categoryId,
  int position = 0,
}) {
  return CatalogProductModel(
    id: id,
    name: name,
    price: '10',
    categoryId: categoryId,
    categoryName: 'Cat',
    isComposed: false,
    isActive: true,
    position: position,
  );
}

/// Mirrors [CatalogRepository.productsForCategory].
List<CatalogProductModel> productsForCategory(
  List<CatalogProductModel> products,
  int categoryId,
) {
  final forCategory = [
    for (final product in products)
      if (product.categoryId == categoryId) product,
  ];
  return CatalogProductModel.sortedByPosition(forCategory);
}

void main() {
  group('CatalogProductModel.position', () {
    test('parses numeric position from API json', () {
      final product = CatalogProductModel.fromJson({
        'id': 12,
        'name': 'Espresso',
        'price': '15',
        'is_composed': false,
        'is_active': true,
        'position': 3,
        'category': {'id': 1, 'name': 'Boissons'},
      });

      expect(product.position, 3);
      expect(product.toJson()['position'], 3);
    });

    test('null / missing / invalid position defaults to 0 without throwing', () {
      expect(
        CatalogProductModel.fromJson({
          'id': 1,
          'name': 'A',
          'price': '1',
          'category': {'id': 1, 'name': 'C'},
        }).position,
        0,
      );
      expect(
        CatalogProductModel.fromJson({
          'id': 2,
          'name': 'B',
          'price': '1',
          'position': null,
          'category': {'id': 1, 'name': 'C'},
        }).position,
        0,
      );
      expect(
        CatalogProductModel.fromJson({
          'id': 3,
          'name': 'C',
          'price': '1',
          'position': 'not-a-number',
          'category': {'id': 1, 'name': 'C'},
        }).position,
        0,
      );
    });

    test('distinct positions sort ascending', () {
      final products = [
        _product(id: 1, name: 'Zulu', categoryId: 1, position: 2),
        _product(id: 2, name: 'Alpha', categoryId: 1, position: 1),
        _product(id: 3, name: 'Beta', categoryId: 1, position: 10),
      ];

      expect(
        CatalogProductModel.sortedByPosition(products).map((p) => p.id),
        [2, 1, 3],
      );
    });

    test(
      'PETIT DEJEUNER: all position 0 keeps API order (not alphabetical)',
      () {
        // Exact payload order from products/list for category 13.
        final apiOrder = [
          _product(
            id: 1,
            name: 'PETIT DEJ MARRAKCHI',
            categoryId: 13,
            position: 0,
          ),
          _product(
            id: 2,
            name: 'PETIT DEJ EXPRESS',
            categoryId: 13,
            position: 0,
          ),
          _product(
            id: 3,
            name: 'PETIT DEJ CONTINENTAL',
            categoryId: 13,
            position: 0,
          ),
          _product(
            id: 4,
            name: 'PETIT DEJ DUO',
            categoryId: 13,
            position: 0,
          ),
        ];

        final ordered = productsForCategory(apiOrder, 13);

        expect(ordered.map((p) => p.name).toList(), [
          'PETIT DEJ MARRAKCHI',
          'PETIT DEJ EXPRESS',
          'PETIT DEJ CONTINENTAL',
          'PETIT DEJ DUO',
        ]);
        // Must NOT be alphabetical (Continental, Duo, Express, Marrakchi).
        expect(ordered.first.name, isNot('PETIT DEJ CONTINENTAL'));
      },
    );

    test('mixed positions reorder only by position; ties keep API order', () {
      final products = [
        _product(id: 10, name: 'C', categoryId: 5, position: 2),
        _product(id: 11, name: 'A', categoryId: 5, position: 0),
        _product(id: 12, name: 'B', categoryId: 5, position: 0),
        _product(id: 13, name: 'D', categoryId: 5, position: 1),
      ];

      final ordered = CatalogProductModel.sortedByPosition(products);
      expect(ordered.map((p) => p.name).toList(), ['A', 'B', 'D', 'C']);
      expect(ordered.map((p) => p.position).toList(), [0, 0, 1, 2]);
    });
  });
}
