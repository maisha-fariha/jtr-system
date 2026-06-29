import 'menu_category.dart';

class PresetMenu {
  const PresetMenu({
    required this.number,
    required this.label,
    required this.priceValue,
    required this.description,
    required this.categories,
    int? badgeNumber,
  }) : badgeNumber = badgeNumber ?? number;

  /// Composed product id ([GET /api/products/:id]).
  final int number;
  final int badgeNumber;
  final String label;
  final double priceValue;
  final String description;
  final List<MenuCategory> categories;

  int get productId => number;

  String get badgeLabel => 'M $badgeNumber';

  String get formattedPrice =>
      '${priceValue.toStringAsFixed(2).replaceAll('.', ',')} €';
}
