import 'package:flutter/material.dart';

import '../../models/menu_category.dart';
import '../../models/menu_item.dart';
import '../../models/preset_menu.dart';
import '../models/catalog/catalog_product_model.dart';

class MenuMapper {
  MenuMapper._();

  static const _courseColors = <Color>[
    Color(0xFFEE8B78),
    Color(0xFF4A90D9),
    Color(0xFF5BAD6F),
    Color(0xFF9B59B6),
    Color(0xFFF1C40F),
  ];

  /// List row for composed menu products (categories loaded on tap).
  static PresetMenu thinPresetFromProduct(
    CatalogProductModel product, {
    required int badgeNumber,
  }) {
    return PresetMenu(
      number: product.id,
      badgeNumber: badgeNumber,
      label: product.name,
      priceValue: product.unitPrice,
      description: product.description ?? '',
      categories: product.menuCategories.isNotEmpty
          ? categoriesFromProduct(product)
          : const [],
    );
  }

  /// Full preset with CHOIX categories from [GET /api/products/:id].
  static PresetMenu presetFromProduct(
    CatalogProductModel product, {
    required int badgeNumber,
  }) {
    return PresetMenu(
      number: product.id,
      badgeNumber: badgeNumber,
      label: product.name,
      priceValue: product.unitPrice,
      description: product.description ?? '',
      categories: categoriesFromProduct(product),
    );
  }

  static List<MenuCategory> categoriesFromProduct(CatalogProductModel product) {
    final categories = <MenuCategory>[];

    for (var i = 0; i < product.menuCategories.length; i++) {
      final menuCategory = product.menuCategories[i];
      final courseNumber = i + 1;

      categories.add(
        MenuCategory(
          number: courseNumber,
          label: menuCategory.name.toUpperCase(),
          color: _courseColors[i % _courseColors.length],
          items: menuCategory.products
              .map(
                (option) => MenuItem(
                  name: option.name,
                  priceValue: option.supplement,
                  courseNumber: courseNumber,
                  productId: option.id,
                  menuCategoryId: menuCategory.id,
                  menuCategoryName: menuCategory.name,
                  supplement: option.supplement,
                ),
              )
              .toList(),
        ),
      );
    }

    return categories;
  }

  static List<Map<String, dynamic>> menuSelectionsFromItems(
    Iterable<MenuItem> items,
  ) {
    final selections = <Map<String, dynamic>>[];

    for (final item in items) {
      final categoryId = item.menuCategoryId;
      final productId = item.productId;
      if (categoryId == null || productId == null) continue;

      selections.add({
        'menu_category_id': categoryId,
        'selected_product_id': productId,
        'price': item.supplement ?? item.priceValue,
        if (item.menuCategoryName != null)
          'menu_category_name': item.menuCategoryName,
        'selected_product_name': item.name,
      });
    }

    return selections;
  }
}
