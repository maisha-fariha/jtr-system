class MenuItem {
  const MenuItem({
    required this.name,
    required this.priceValue,
    required this.courseNumber,
    this.code,
  });

  final String name;
  final double priceValue;
  final int courseNumber;
  final String? code;

  String get formattedPrice =>
      '${priceValue.toStringAsFixed(2).replaceAll('.', ',')} €';
}
