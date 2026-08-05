class CatalogProductModel {
  const CatalogProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    required this.isComposed,
    required this.isActive,
    this.description,
    this.image,
    this.menuCategories = const [],
  });

  final int id;
  final String name;
  final String price;
  final int categoryId;
  final String categoryName;
  final bool isComposed;
  final bool isActive;
  final String? description;
  final String? image;
  final List<ProductMenuCategoryModel> menuCategories;

  double get unitPrice =>
      double.tryParse(price.replaceAll(',', '.')) ?? 0;

  String get formattedPrice =>
      '${unitPrice.toStringAsFixed(2).replaceAll('.', ',')} €';

  factory CatalogProductModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final categoryId = category is Map<String, dynamic>
        ? (category['id'] as num?)?.toInt() ?? 0
        : 0;
    final categoryName = category is Map<String, dynamic>
        ? (category['name'] as String? ?? '')
        : '';

    final rawMenus = json['menu_categories'];
    final menus = rawMenus is List
        ? rawMenus
            .whereType<Map<String, dynamic>>()
            .map(ProductMenuCategoryModel.fromJson)
            .toList()
        : <ProductMenuCategoryModel>[];

    return CatalogProductModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      price: json['price']?.toString() ?? '0',
      categoryId: categoryId,
      categoryName: categoryName,
      isComposed: json['is_composed'] == true,
      isActive: json['is_active'] != false,
      description: json['description'] as String?,
      image: json['image'] as String?,
      menuCategories: menus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'category': {'id': categoryId, 'name': categoryName},
        'is_composed': isComposed,
        'is_active': isActive,
        'description': description,
        'image': image,
        'menu_categories':
            menuCategories.map((menu) => menu.toJson()).toList(),
      };
}

class ProductMenuCategoryModel {
  const ProductMenuCategoryModel({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.minSelections,
    required this.maxSelections,
    required this.products,
    this.description,
    this.position = 0,
  });

  final int id;
  final String name;
  final String? description;
  final bool isRequired;

  /// Per composed product — same category id can differ across menus.
  final int minSelections;
  final int maxSelections;
  final int position;
  final List<ProductMenuOptionModel> products;

  factory ProductMenuCategoryModel.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final products = rawProducts is List
        ? rawProducts
            .whereType<Map<String, dynamic>>()
            .map(ProductMenuOptionModel.fromJson)
            .toList()
        : <ProductMenuOptionModel>[];
    products.sort((a, b) => a.position.compareTo(b.position));

    return ProductMenuCategoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      isRequired: json['is_required'] == true,
      minSelections: (json['min_selections'] as num?)?.toInt() ?? 1,
      maxSelections: (json['max_selections'] as num?)?.toInt() ?? 1,
      position: (json['position'] as num?)?.toInt() ?? 0,
      products: products,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'is_required': isRequired,
        'min_selections': minSelections,
        'max_selections': maxSelections,
        'position': position,
        'products': products.map((p) => p.toJson()).toList(),
      };
}

class ProductMenuOptionModel {
  const ProductMenuOptionModel({
    required this.id,
    required this.name,
    required this.menuPrice,
    required this.basePrice,
    required this.isDefault,
    this.position = 0,
  });

  final int id;
  final String name;
  final String menuPrice;
  final String basePrice;
  final bool isDefault;
  final int position;

  double get supplement =>
      double.tryParse(menuPrice.replaceAll(',', '.')) ?? 0;

  factory ProductMenuOptionModel.fromJson(Map<String, dynamic> json) {
    return ProductMenuOptionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      menuPrice: json['menu_price']?.toString() ?? '0',
      basePrice: json['base_price']?.toString() ?? '0',
      isDefault: json['is_default'] == true,
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'menu_price': menuPrice,
        'base_price': basePrice,
        'is_default': isDefault,
        'position': position,
      };
}
