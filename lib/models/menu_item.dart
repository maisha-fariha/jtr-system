class MenuItem {
  const MenuItem({
    required this.name,
    required this.priceValue,
    required this.courseNumber,
    this.code,
    this.productId,
    this.menuCategoryId,
    this.menuCategoryName,
    this.supplement,
    this.basePrice,
  });

  final String name;
  final double priceValue;
  final int courseNumber;
  final String? code;
  final int? productId;
  final int? menuCategoryId;
  final String? menuCategoryName;
  final double? supplement;
  final double? basePrice;

  String get formattedPrice =>
      '${priceValue.toStringAsFixed(2).replaceAll('.', ',')} €';

  /// Human-readable price for CHOIX cards (supplement vs included).
  String get displayPriceLabel {
    final extra = supplement ?? priceValue;
    if (extra > 0) {
      return '+${extra.toStringAsFixed(2).replaceAll('.', ',')} €';
    }
    final base = basePrice ?? 0;
    if (base > 0) {
      return '${base.toStringAsFixed(2).replaceAll('.', ',')} €';
    }
    return 'Inclus';
  }
}
