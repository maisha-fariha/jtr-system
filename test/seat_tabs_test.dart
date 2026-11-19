import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';
import 'package:jtr_system/data/models/local_draft_line.dart';

Map<String, dynamic> _item(int id, int productId, {int seat = 1}) => {
      'id': id,
      'seat_number': seat,
      'product': {'id': productId, 'name': 'P$productId'},
      'qty': 1,
      'sub_total': 5,
      'status': 'to_be_continued',
    };

void main() {
  tearDown(() => OrderMapper.preferredSeatNumber = null);

  test('normalizeTableKey treats 015 and 15 as the same table', () {
    expect(OrderMapper.normalizeTableKey('015'), '15');
    expect(OrderMapper.normalizeTableKey('T015'), '15');
    expect(OrderMapper.normalizeTableKey('0'), '0');
    expect(OrderMapper.normalizeTableKey('15'), '15');
  });

  test('extractProducts carries the seat number of each line', () {
    final detail = {
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {'course_number': 1, 'items': [_item(1, 10)]},
          ],
        },
        {
          'seat_number': 2,
          'courses': [
            {'course_number': 1, 'items': [_item(2, 11, seat: 2)]},
          ],
        },
      ],
    };
    final products = OrderMapper.extractProducts(detail);
    expect(products.map((p) => p.seatNumber), [1, 2]);
    final entries = OrderMapper.extractOrderDisplayEntries(detail);
    expect(entries.map((e) => e.product?.seatNumber), [1, 2]);
    // Seat 2 course 1 is not a follow-up: no À SUIVRE divider is invented.
    expect(entries.any((e) => e.isSectionDivider), isFalse);
  });

  test('create from drafts groups lines per seat, courses restart', () {
    final payload = OrderMapper.buildCreateOrderFromDraftLines(
      waiterId: 1,
      numberOfGuests: 2,
      lines: const [
        LocalDraftLine(productId: 10, unitPrice: 5),
        LocalDraftLine(productId: 11, unitPrice: 6, seatNumber: 2),
      ],
    );
    final seats = payload['seat_orders'] as List;
    expect(seats.length, 2);
    expect(seats[1]['seat_number'], 2);
    final item = seats[1]['courses'][0]['items'][0] as Map;
    expect(item['seat_number'], 2);
    expect(item['course_number'], 1);
    expect(item['item_messages'], isEmpty);
  });

  test('single seat create payload keeps one seat', () {
    final payload = OrderMapper.buildCreateOrderFromDraftLines(
      waiterId: 1,
      numberOfGuests: 2,
      lines: const [LocalDraftLine(productId: 10, unitPrice: 5)],
    );
    expect((payload['seat_orders'] as List).length, 1);
  });

  test('preferred seat drives the default seat only when set', () {
    final detail = {
      'seat_orders': [
        {'seat_number': 1, 'courses': []},
      ],
    };
    expect(OrderMapper.resolveDefaultSeatNumber(detail), 1);
    OrderMapper.preferredSeatNumber = 2;
    expect(OrderMapper.resolveDefaultSeatNumber(detail), 2);
  });
}
