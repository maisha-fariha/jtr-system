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
  });

  final String name;
  final double priceValue;
  final int courseNumber;
  final String? code;
  final int? productId;
  final int? menuCategoryId;
  final String? menuCategoryName;
  final double? supplement;

  String get formattedPrice =>
      '${priceValue.toStringAsFixed(2).replaceAll('.', ',')} €';
}
