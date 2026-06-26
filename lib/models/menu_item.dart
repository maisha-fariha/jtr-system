class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    this.description = '',
    this.imageAsset,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final double price;
  final String categoryId;
  final String description;
  final String? imageAsset;
  final bool isAvailable;
}

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    this.iconCode,
  });

  final String id;
  final String name;
  final int? iconCode;
}
