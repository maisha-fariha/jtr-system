import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/menu_mapper.dart';
import 'package:jtr_system/data/models/catalog/catalog_product_model.dart';

void main() {
  group('defaultMenuSelectionsForProduct', () {
    test('builds required category defaults for composed seed product', () {
      const product = CatalogProductModel(
        id: 13,
        name: 'Menu seed',
        price: '20',
        categoryId: 1,
        categoryName: 'Menus',
        isComposed: true,
        isActive: true,
        menuCategories: [
          ProductMenuCategoryModel(
            id: 4,
            name: 'Entrée',
            isRequired: true,
            minSelections: 1,
            maxSelections: 1,
            products: [
              ProductMenuOptionModel(
                id: 69,
                name: 'Option A',
                menuPrice: '0',
                basePrice: '0',
                isDefault: true,
              ),
            ],
          ),
        ],
      );

      final selections =
          MenuMapper.defaultMenuSelectionsForProduct(product);

      expect(selections, hasLength(1));
      expect(selections.first['menu_category_id'], 4);
      expect(selections.first['selected_product_id'], 69);
      expect(selections.first['price'], 0.0);
    });

    test('returns empty list for simple products', () {
      const product = CatalogProductModel(
        id: 54,
        name: 'DIVER BOISSON',
        price: '0',
        categoryId: 1,
        categoryName: 'Boissons',
        isComposed: false,
        isActive: true,
      );

      expect(MenuMapper.defaultMenuSelectionsForProduct(product), isEmpty);
    });
  });
}
