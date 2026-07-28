
import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';
import 'package:jtr_system/models/order_display_entry.dart';
import 'package:jtr_system/models/order_product.dart';

void main() {
  OrderProduct product(String name) => OrderProduct(
        name: name,
        quantity: '1',
        price: '10,00',
      );

  test('removes DEMANDÉE rows with no products under them', () {
    final entries = [
      OrderDisplayEntry.product(product: product('A'), lineIndex: 0),
      OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '12:06:47',
      ),
      OrderDisplayEntry.demande(
        sectionIndex: 2,
        courseNumber: 2,
        demandeTimeLabel: '12:07:06',
      ),
    ];

    final cleaned = OrderMapper.withoutEmptyDemandeSeparators(entries);
    expect(cleaned.length, 1);
    expect(cleaned.first.type, OrderDisplayEntryType.product);
  });

  test('keeps DEMANDÉE rows that still have products', () {
    final entries = [
      OrderDisplayEntry.demande(
        sectionIndex: 1,
        courseNumber: 1,
        demandeTimeLabel: '12:06:47',
      ),
      OrderDisplayEntry.product(
        product: product('A'),
        lineIndex: 0,
        sectionIndex: 1,
      ),
      OrderDisplayEntry.demande(
        sectionIndex: 2,
        courseNumber: 2,
        demandeTimeLabel: '12:07:06',
      ),
    ];

    final cleaned = OrderMapper.withoutEmptyDemandeSeparators(entries);
    expect(
      cleaned.where((e) => e.type == OrderDisplayEntryType.demandeSeparator).length,
      1,
    );
    expect(cleaned.any((e) => e.type == OrderDisplayEntryType.product), isTrue);
  });
}
