/// One line on a local-only ticket, ready for POST /api/orders on Send.
class LocalDraftLine {
  const LocalDraftLine({
    required this.productId,
    required this.unitPrice,
    this.qty = 1,
    this.menuSelections = const [],
    this.comment = '',
    this.courseNumber = 1,
    this.seatNumber = 1,
    this.isOffered = false,
  });

  final int productId;
  final double unitPrice;
  final int qty;
  final List<Map<String, dynamic>> menuSelections;
  final String comment;
  final int courseNumber;
  final int seatNumber;
  final bool isOffered;

  LocalDraftLine copyWith({
    int? productId,
    double? unitPrice,
    int? qty,
    List<Map<String, dynamic>>? menuSelections,
    String? comment,
    int? courseNumber,
    int? seatNumber,
    bool? isOffered,
  }) {
    return LocalDraftLine(
      productId: productId ?? this.productId,
      unitPrice: unitPrice ?? this.unitPrice,
      qty: qty ?? this.qty,
      menuSelections: menuSelections ?? this.menuSelections,
      comment: comment ?? this.comment,
      courseNumber: courseNumber ?? this.courseNumber,
      seatNumber: seatNumber ?? this.seatNumber,
      isOffered: isOffered ?? this.isOffered,
    );
  }
}
