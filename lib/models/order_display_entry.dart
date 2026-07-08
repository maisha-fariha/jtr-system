import 'order_product.dart';

enum OrderDisplayEntryType { product, suivreSeparator, demandeSeparator }

class OrderDisplayEntry {
  const OrderDisplayEntry._({
    required this.type,
    this.product,
    this.lineIndex,
    this.sectionIndex,
    this.courseNumber,
    this.demandeTimeLabel,
  });

  const OrderDisplayEntry.product({
    required OrderProduct product,
    required int lineIndex,
    int sectionIndex = 0,
    int? courseNumber,
  }) : this._(
          type: OrderDisplayEntryType.product,
          product: product,
          lineIndex: lineIndex,
          sectionIndex: sectionIndex,
          courseNumber: courseNumber,
        );

  const OrderDisplayEntry.suivre({
    required int sectionIndex,
    required int courseNumber,
  }) : this._(
          type: OrderDisplayEntryType.suivreSeparator,
          sectionIndex: sectionIndex,
          courseNumber: courseNumber,
        );

  const OrderDisplayEntry.demande({
    required int sectionIndex,
    required int courseNumber,
    required String demandeTimeLabel,
  }) : this._(
          type: OrderDisplayEntryType.demandeSeparator,
          sectionIndex: sectionIndex,
          courseNumber: courseNumber,
          demandeTimeLabel: demandeTimeLabel,
        );

  final OrderDisplayEntryType type;
  final OrderProduct? product;
  final int? lineIndex;

  /// UI collapse/selection key. Increments per À SUIVRE row.
  final int? sectionIndex;

  /// API `course_number` for the service above this separator.
  final int? courseNumber;

  /// Formatted local time for a kitchen demande, e.g. `13:30:33`.
  final String? demandeTimeLabel;

  bool get isSectionDivider =>
      type == OrderDisplayEntryType.suivreSeparator ||
      type == OrderDisplayEntryType.demandeSeparator;
}
