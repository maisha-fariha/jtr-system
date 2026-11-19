import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/jtr_mobile/data/mappers/jtr_mobile_dashboard_mapper.dart';

void main() {
  test('maps waiter-performance rows sorted by revenue with shares', () {
    final sales = JtrMobileDashboardMapper.mapWaiterSales({
      'waiters': [
        {
          'waiter_name': 'Alice',
          'chiffre_affaires': 100,
          'total_encaissement': 90,
          'order_count': 4,
          'covers': 8,
        },
        {
          'waiter': {'name': 'Bob'},
          'chiffre_affaires': '300.50',
          'total_encaissement': 300.5,
          'order_count': 10,
          'covers': 20,
        },
      ],
      'totals': {'chiffre_affaires': 400.5},
    });
    expect(sales.map((s) => s.name), ['Bob', 'Alice']);
    expect(sales.first.orderCount, 10);
    expect(sales.first.percent, closeTo(75.0, 0.5));
  });

  test('empty payload gives no rows', () {
    expect(JtrMobileDashboardMapper.mapWaiterSales({}), isEmpty);
  });
}
