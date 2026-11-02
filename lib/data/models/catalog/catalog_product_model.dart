class CatalogProductModel {
  const CatalogProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    required this.isComposed,
    required this.isActive,
    this.priceType,
    this.description,
    this.image,
    this.position = 0,
    this.menuCategories = const [],
  });

  final int id;
  final String name;
  final String price;
  final int categoryId;
  final String categoryName;
  final bool isComposed;
  final bool isActive;
  /// Backend `price_type` — `free` means prix libre (cashier enters price).
  final String? priceType;
  final String? description;
  final String? image;
  /// Backend catalog `position` — display order within a category (ascending).
  final int position;
  final List<ProductMenuCategoryModel> menuCategories;

  /// Prix libre — only when products/list `price_type` is free (not by price).
  bool get isPrixLibre {
    final normalized = priceType?.trim().toLowerCase();
    return normalized == 'free' ||
        normalized == 'prix_libre' ||
        normalized == 'libre' ||
        normalized == 'open';
  }

  /// Cashier must enter a unit price — solely when [isPrixLibre].
  /// `price_type: normal` with price 0 is a normal 0 DH product (no prompt).
  bool get requiresCashierPrice => !isComposed && isPrixLibre;

  double get unitPrice =>
      double.tryParse(price.replaceAll(',', '.')) ?? 0;

  String get formattedPrice =>
      unitPrice.toStringAsFixed(2).replaceAll('.', ',');

  CatalogProductModel copyWith({
    int? id,
    String? name,
    String? price,
    int? categoryId,
    String? categoryName,
    bool? isComposed,
    bool? isActive,
    String? priceType,
    String? description,
    String? image,
    int? position,
    List<ProductMenuCategoryModel>? menuCategories,
  }) {
    return CatalogProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      isComposed: isComposed ?? this.isComposed,
      isActive: isActive ?? this.isActive,
      priceType: priceType ?? this.priceType,
      description: description ?? this.description,
      image: image ?? this.image,
      position: position ?? this.position,
      menuCategories: menuCategories ?? this.menuCategories,
    );
  }

  /// Keep detail-only fields when a list refresh omits them.
  CatalogProductModel mergePreservingDetailFields(CatalogProductModel? previous) {
    if (previous == null || previous.id != id) return this;
    return copyWith(
      priceType: priceType ?? previous.priceType,
      menuCategories: menuCategories.isNotEmpty
          ? menuCategories
          : previous.menuCategories,
      description: description ?? previous.description,
      // Keep prior position if this payload omitted it (parsed as 0).
      position: position != 0 || previous.position == 0
          ? position
          : previous.position,
    );
  }

  static String? _priceTypeFromJson(Map<String, dynamic> json) {
    final raw = json['price_type'] ?? json['priceType'];
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  /// Null / missing / invalid → `0` (sorts first; never throws).
  static int positionFromJson(Map<String, dynamic> json) {
    final raw = json['position'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  /// Ascending [position]. Equal positions keep caller-defined order
  /// (pass original list index via [compareByPositionThenIndex], or use id).
  static int compareByPosition(CatalogProductModel a, CatalogProductModel b) {
    final byPos = a.position.compareTo(b.position);
    if (byPos != 0) return byPos;
    // Do not sort by name — when position ties, preserve API list order.
    return a.id.compareTo(b.id);
  }

  /// Ascending [position], then original list index (exact API order on ties).
  static int compareByPositionThenIndex(
    int indexA,
    CatalogProductModel a,
    int indexB,
    CatalogProductModel b,
  ) {
    final byPos = a.position.compareTo(b.position);
    if (byPos != 0) return byPos;
    return indexA.compareTo(indexB);
  }

  /// Sort [products] by [position] ascending; equal positions keep list order.
  static List<CatalogProductModel> sortedByPosition(
    List<CatalogProductModel> products,
  ) {
    final indexed = [
      for (var i = 0; i < products.length; i++) MapEntry(i, products[i]),
    ]..sort(
        (a, b) => compareByPositionThenIndex(
          a.key,
          a.value,
          b.key,
          b.value,
        ),
      );
    return [for (final entry in indexed) entry.value];
  }

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
      priceType: _priceTypeFromJson(json),
      description: json['description'] as String?,
      image: json['image'] as String?,
      position: positionFromJson(json),
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
        if (priceType != null) 'price_type': priceType,
        'description': description,
        'image': image,
        'position': position,
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
