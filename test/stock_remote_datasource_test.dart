import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/data/datasources/stock_remote_datasource.dart';

void main() {
  group('StockRemoteDataSource.parseStockLimits', () {
    test('parses list with current_stock and is_freed', () {
      final map = StockRemoteDataSource.parseStockLimits([
        {
          'product_id': 10,
          'current_stock': 6,
          'is_freed': false,
        },
        {
          'product_id': 20,
          'current_stock': 0,
          'is_blocked': true,
        },
        {
          'product_id': 30,
          'current_stock': 4,
          'is_freed': true,
        },
      ]);

      expect(map[10]?.currentStock, 6);
      expect(map[10]?.isFreed, isFalse);
      expect(map[20]?.isBlocked, isTrue);
      expect(map[30]?.isFreed, isTrue);
    });

    test('parses product-id keyed map', () {
      final map = StockRemoteDataSource.parseStockLimits({
        '42': {'current_stock': 8, 'daily_limit': 12},
      });

      expect(map[42]?.currentStock, 8);
      expect(map[42]?.dailyLimit, 12);
    });

    test('parses nested limits list', () {
      final map = StockRemoteDataSource.parseStockLimits({
        'limits': [
          {
            'product': {'id': 99, 'name': 'OULMES'},
            'available_qty': 5,
          },
        ],
      });

      expect(map[99]?.currentStock, 5);
      expect(map[99]?.productName, 'OULMES');
    });
  });

  group('StockRemoteDataSource.parseProductStatus', () {
    test('parses blocked status', () {
      final status = StockRemoteDataSource.parseProductStatus(42, {
        'is_blocked': true,
        'current_stock': 0,
      });
      expect(status?.productId, 42);
      expect(status?.isBlocked, isTrue);
      expect(status?.currentStock, 0);
    });
  });
}
