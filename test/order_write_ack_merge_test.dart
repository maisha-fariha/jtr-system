import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';

Map<String, dynamic> _cachedDetail() => {
      'id': 123,
      'order_number': 'ORD-1',
      'status': 'pending',
      'payment_status': 'not_paid',
      'table_id': 5,
      'table_number': '12',
      'number_of_guests': 2,
      'total_price': '10.00',
      'total_paid': '0.00',
      'remaining_amount': '10.00',
      'sales_zone': {'id': 1, 'name': 'Salle', 'has_tables': true},
      'seat_orders': [
        {
          'id': 10,
          'seat_number': 1,
          'courses': [
            {
              'id': 20,
              'course_number': 1,
              'items': [
                {
                  'id': 9000,
                  'seat_number': 1,
                  'qty': 1,
                  'sub_total': '10.00',
                  'status': 'pending',
                  'created_at': '2026-10-05T10:00:00Z',
                  'product': {'id': 7, 'name': 'Café', 'price': '10.00'},
                },
              ],
            },
          ],
        },
      ],
    };

/// PUT body: existing line + one new line (id 0, client uid, product id only).
Map<String, dynamic> _sentPayload() => {
      'waiter_id': 2,
      'number_of_guests': 2,
      'table_id': 5,
      'seat_orders': [
        {
          'id': 10,
          'seat_number': 1,
          'courses': [
            {
              'id': 20,
              'course_number': 1,
              'items': [
                {
                  'id': 9000,
                  'seat_number': 1,
                  'qty': 1,
                  'sub_total': '10.00',
                  'status': 'pending',
                  'created_at': '2026-10-05T10:00:00Z',
                  'product': {'id': 7, 'name': 'Café', 'price': '10.00'},
                },
                {
                  'id': 0,
                  'uid': 'client-uid-1',
                  'seat_number': 1,
                  'course_id': 20,
                  'qty': 2,
                  'sub_total': 24,
                  'status': 'to_be_continued',
                  'created_at': '2026-10-05T10:05:00Z',
                  'product': {'id': 42},
                },
              ],
            },
          ],
        },
      ],
    };

Map<String, dynamic> _writeAck() => {
      'id': 123,
      'order_number': 'ORD-1',
      'status': 'pending',
      'payment_status': 'not_paid',
      'table_id': 5,
      'number_of_guests': 2,
      'total_price': '34.00',
      'total_paid': '0.00',
      'remaining_amount': '34',
      'has_changes': true,
      'kitchen_printed_via_gateway': false,
      'item_uid_map': [
        {
          'uid': 'client-uid-1',
          'id': 9001,
          'seat_number': 1,
          'course_number': 1,
        },
      ],
      'items': [
        {'id': 9000, 'seat_number': 1, 'course_number': 1, 'qty': 1, 'status': 'pending'},
        {
          'id': 9001,
          'uid': 'client-uid-1',
          'seat_number': 1,
          'course_number': 1,
          'qty': 2,
          'status': 'pending',
        },
      ],
      'seat_orders': [
        {'id': 10, 'seat_number': 1},
      ],
      'courses': [
        {'id': 20, 'course_number': 1, 'seat_number': 1, 'seat_order_id': 10},
      ],
    };

List<Map<String, dynamic>> _items(Map<String, dynamic> detail) => [
      for (final seat in detail['seat_orders'] as List)
        for (final course in (seat as Map)['courses'] as List)
          for (final item in (course as Map)['items'] as List)
            item as Map<String, dynamic>,
    ];

void main() {
  group('OrderMapper.mergeWriteAck', () {
    test('keeps the tree, maps new line id via item_uid_map, applies totals',
        () {
      final merged = OrderMapper.mergeWriteAck(
        ack: _writeAck(),
        sent: _sentPayload(),
        previous: _cachedDetail(),
        catalogNamesById: const {42: 'Pizza'},
      );

      final items = _items(merged);
      expect(items, hasLength(2));
      expect(items[1]['id'], 9001);
      expect(items[1]['status'], 'pending');
      expect((items[1]['product'] as Map)['name'], 'Pizza');
      expect(merged['total_price'], '34.00');
      expect(merged['remaining_amount'], '34');
      expect(merged['order_number'], 'ORD-1');
      expect(merged['table_number'], '12');
      expect(OrderMapper.orderDetailLinesComplete(merged), isTrue);
    });

    test('renders product lines with names after merge', () {
      final merged = OrderMapper.mergeWriteAck(
        ack: _writeAck(),
        sent: _sentPayload(),
        previous: _cachedDetail(),
        catalogNamesById: const {42: 'Pizza'},
      );
      final names = OrderMapper.extractProducts(merged).map((p) => p.name);
      expect(names, containsAll(<String>['Café', 'Pizza']));
    });

    test('is incomplete when a new line name cannot be resolved', () {
      final merged = OrderMapper.mergeWriteAck(
        ack: _writeAck(),
        sent: _sentPayload(),
        previous: _cachedDetail(),
      );
      expect(OrderMapper.orderDetailLinesComplete(merged), isFalse);
    });

    test('is incomplete when item_uid_map misses a new line', () {
      final ack = _writeAck()
        ..['item_uid_map'] = <dynamic>[]
        ..['items'] = <dynamic>[];
      final merged = OrderMapper.mergeWriteAck(
        ack: ack,
        sent: _sentPayload(),
        previous: _cachedDetail(),
        catalogNamesById: const {42: 'Pizza'},
      );
      expect(OrderMapper.orderDetailLinesComplete(merged), isFalse);
    });

    test('does not mutate the sent payload or cached detail', () {
      final sent = _sentPayload();
      final previous = _cachedDetail();
      OrderMapper.mergeWriteAck(
        ack: _writeAck(),
        sent: sent,
        previous: previous,
        catalogNamesById: const {42: 'Pizza'},
      );
      expect(_items(sent)[1]['id'], 0);
      expect((_items(sent)[1]['product'] as Map).containsKey('name'), isFalse);
      expect(_items(previous), hasLength(1));
    });
  });

  group('OrderMapper.mergePaymentAck', () {
    final lean = <String, dynamic>{
      'id': 123,
      'status': 'pending',
      'payment_status': 'partially_paid',
      'total_price': '10.00',
      'total_paid': '4.00',
      'remaining_amount': 6,
      'sales_zone': {'id': 1, 'require_send_before_payment': true},
      'payment_transactions': [
        {'id': 1, 'order_id': 123, 'amount': '4.00'},
      ],
    };

    test('keeps seats/items and applies totals + transactions', () {
      final merged =
          OrderMapper.mergePaymentAck(base: _cachedDetail(), lean: lean);
      expect(_items(merged), hasLength(1));
      expect(merged['total_paid'], '4.00');
      expect(merged['remaining_amount'], 6);
      expect(merged['payment_status'], 'partially_paid');
      expect(merged['payment_transactions'], hasLength(1));
      expect((merged['sales_zone'] as Map)['name'], 'Salle');
      expect(
        (merged['sales_zone'] as Map)['require_send_before_payment'],
        isTrue,
      );
    });

    test('ack seat_orders never replace the cached tree', () {
      final ackWithSeats = Map<String, dynamic>.from(lean)
        ..['seat_orders'] = [
          {'id': 10, 'seat_number': 1},
        ];
      final merged = OrderMapper.mergePaymentAck(
        base: _cachedDetail(),
        lean: ackWithSeats,
      );
      expect(_items(merged), hasLength(1));
      expect(merged['total_paid'], '4.00');
    });

    test('without a cached tree the lean order is returned as-is', () {
      final merged = OrderMapper.mergePaymentAck(base: null, lean: lean);
      expect(OrderMapper.orderDetailHasSeatTree(merged), isFalse);
      expect(merged['total_paid'], '4.00');
    });
  });
}
