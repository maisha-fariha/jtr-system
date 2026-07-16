import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/mappers/order_mapper.dart';

void main() {
  Map<String, dynamic> orderWithSeed({
    required int productId,
    required String subTotal,
    String status = 'pending',
  }) {
    return {
      'id': 190,
      'status': status,
      'table_number': 9,
      'number_of_guests': 3,
      'total_price': subTotal,
      'payment_status': 'not_paid',
      'payment_status_detailed': 'fully_paid',
      'waiter_id': 1,
      'seat_orders': [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 919,
              'course_number': 1,
              'seat_number': 1,
              'items': [
                {
                  'id': 1261,
                  'product_id': productId,
                  'product': {
                    'id': productId,
                    'name': 'DIVER BOISSON',
                    'price': subTotal,
                  },
                  'qty': 1,
                  'sub_total': subTotal,
                  'status': 'to_be_continued',
                },
              ],
            },
          ],
        },
      ],
    };
  }

  test('asOpenEmptyOrderShell clears seed items', () {
    final shell = OrderMapper.asOpenEmptyOrderShell(
      orderWithSeed(productId: 54, subTotal: '0.00'),
    );
    expect(OrderMapper.orderDetailHasNoVisibleItems(shell), isTrue);
    expect(shell['payment_status'], 'not_paid');
    expect(shell['payment_status_detailed'], 'not_paid');
  });

  test('sessionOrderHidingCreateSeed hides only-seed ticket', () {
    final mapped = OrderMapper.sessionOrderHidingCreateSeed(
      orderWithSeed(productId: 54, subTotal: '0.00'),
      seedProductId: 54,
    );
    expect(mapped.products, isEmpty);
    expect(mapped.displayEntries, isEmpty);
    expect(mapped.itemCount, 0);
  });

  test('sessionOrderHidingCreateSeed keeps real priced line', () {
    final mapped = OrderMapper.sessionOrderHidingCreateSeed(
      orderWithSeed(productId: 51, subTotal: '55.00'),
      seedProductId: 54,
    );
    expect(mapped.products, isNotEmpty);
  });

  test('hasOnlyEmptyCreateSeed detects zero-price single line', () {
    expect(
      OrderMapper.hasOnlyEmptyCreateSeed(
        orderWithSeed(productId: 99, subTotal: '0.00'),
      ),
      isTrue,
    );
  });
}
