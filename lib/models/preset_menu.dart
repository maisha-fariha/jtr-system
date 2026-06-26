import 'menu_category.dart';

class PresetMenu {
  const PresetMenu({
    required this.number,
    required this.label,
    required this.priceValue,
    required this.description,
    required this.categories,
  });

  final int number;
  final String label;
  final double priceValue;
  final String description;
  final List<MenuCategory> categories;

  String get badgeLabel => 'M $number';

  String get formattedPrice =>
      '${priceValue.toStringAsFixed(2).replaceAll('.', ',')} €';
}
