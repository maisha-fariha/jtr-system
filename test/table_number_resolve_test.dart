import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';

void main() {
  group('resolveTableForNewOrder', () {
    test('matches by table_number, not by database id', () {
      final tables = [
        {
          'id': 36,
          'table_number': 2,
          'status': 'available',
        },
        {
          'id': 99,
          'table_number': 36,
          'status': 'available',
        },
      ];

      final resolved = OrderMapper.resolveTableForNewOrder(tables, '36');

      expect(resolved, isNotNull);
      expect(resolved!.id, 99);
      expect(resolved.tableNumber, 36);
    });

    test('does not fall back to id when table_number is absent', () {
      final tables = [
        {
          'id': 36,
          'status': 'available',
        },
      ];

      final resolved = OrderMapper.resolveTableForNewOrder(tables, '36');

      expect(resolved, isNull);
    });

    test('accepts string table_number values', () {
      final tables = [
        {
          'id': 2789,
          'table_number': '25',
          'status': 'available',
        },
      ];

      final resolved = OrderMapper.resolveTableForNewOrder(tables, '25');

      expect(resolved, isNotNull);
      expect(resolved!.id, 2789);
      expect(resolved.tableNumber, 25);
    });
  });
}
