import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';

void main() {
  group('open-by-number helpers', () {
    test('parseTableNumberForOpenByNumber accepts plain and T-prefixed keys', () {
      expect(OrderMapper.parseTableNumberForOpenByNumber('42'), 42);
      expect(OrderMapper.parseTableNumberForOpenByNumber('T42'), 42);
      expect(OrderMapper.parseTableNumberForOpenByNumber(''), isNull);
      expect(OrderMapper.parseTableNumberForOpenByNumber('abc'), isNull);
    });

    test('buildOpenTableByNumberPayload includes optional fields', () {
      final payload = OrderMapper.buildOpenTableByNumberPayload(
        tableNumber: 42,
        numberOfGuests: 2,
        waiterId: 5,
        waiterName: 'Ahmed',
        salesZoneId: 3,
      );

      expect(payload['table_number'], 42);
      expect(payload['number_of_guests'], 2);
      expect(payload['waiter_id'], 5);
      expect(payload['waiter_name'], 'Ahmed');
      expect(payload['sales_zone_id'], 3);
    });

    test('activeOrderIdFromConflictBody reads nested active_order', () {
      final id = OrderMapper.activeOrderIdFromConflictBody({
        'success': false,
        'message': 'Cette table a déjà une commande active.',
        'data': {
          'id': 123,
          'table_number': 42,
          'active_order': {'id': 987},
        },
      });

      expect(id, 987);
    });

    test('resolvedTableFromPayload maps table row', () {
      final table = OrderMapper.resolvedTableFromPayload({
        'id': 123,
        'table_number': 42,
        'status': 'open',
        'active_order': null,
      });

      expect(table.id, 123);
      expect(table.tableNumber, 42);
      expect(table.status, 'open');
      expect(table.hasActiveOrder, isFalse);
    });
  });
}
