import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jtr_system/core/network/api_client.dart';
import 'package:jtr_system/core/network/api_exception.dart';
import 'package:jtr_system/data/datasources/order_remote_datasource.dart';
import 'package:jtr_system/data/datasources/session_datasource.dart';

typedef _Handler = ({int status, Object body}) Function(RequestOptions);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final _Handler handler;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    final result = handler(options);
    final body = result.body;
    return ResponseBody.fromString(
      jsonEncode(
        body is Map<String, dynamic>
            ? {'status': result.status, ...body}
            : body,
      ),
      result.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _page(List<Map<String, dynamic>> rows, {int last = 1}) => {
      'success': true,
      'data': {
        'data': rows,
        'meta': {'last_page': last, 'per_page': 20, 'total': rows.length},
      },
    };

Map<String, dynamic> _summaryRow(int id) => {
      'id': id,
      'status': 'pending',
      'payment_status': 'unpaid',
      'total_price': 12.5,
      'waiter_id': 3,
      'table': {'id': 40 + id, 'table_number': id},
      'sales_zone': {'id': 1, 'name': 'SALLE'},
    };

(ApiClient, _FakeAdapter) _client(_Handler handler) {
  final client = ApiClient();
  final adapter = _FakeAdapter(handler);
  client.dio
    ..options.baseUrl = 'http://pos.test'
    ..httpClientAdapter = adapter;
  return (client, adapter);
}

void main() {
  group('orders list → /api/orders/summary', () {
    test('uses summary only and maps nested table / zone', () async {
      final (client, adapter) = _client(
        (_) => (status: 200, body: _page([_summaryRow(5)])),
      );

      final first =
          await SessionRemoteDataSource(client).fetchOrdersFirstPage();
      final row = first.orders.single;

      expect(adapter.calls, ['GET /api/orders/summary']);
      expect(row['table_number'], 5);
      expect(row['table_id'], 45);
      expect(row['sales_zone_name'], 'SALLE');
      expect(row['sales_zone'], {'id': 1, 'name': 'SALLE'});
      expect(row['items_count'], isNull);
    });

    test('sends the list filters as query parameters', () async {
      late Map<String, dynamic> query;
      final (client, _) = _client((options) {
        query = options.queryParameters;
        return (status: 200, body: _page(const []));
      });

      await SessionRemoteDataSource(client)
          .fetchOrdersFirstPage(waiterId: 3, salesZoneId: 2);

      expect(query['active_day'], false);
      expect(query['page'], 1);
      expect(query['per_page'], SessionRemoteDataSource.ordersPageSize);
      expect(query['waiter_id'], 3);
      expect(query['sales_zone_id'], 2);
    });

    test('unknown payload shape is an error, not an empty list', () async {
      final (client, _) = _client(
        (_) => (status: 200, body: {'success': true, 'data': {'foo': 1}}),
      );

      await expectLater(
        SessionRemoteDataSource(client).fetchOrdersFirstPage(),
        throwsA(isA<ApiException>()),
      );
    });

    test('paginates on the summary endpoint', () async {
      final (client, adapter) = _client(
        (_) => (status: 200, body: _page([_summaryRow(1)], last: 2)),
      );

      final orders = await SessionRemoteDataSource(client).fetchOrdersList();

      expect(orders, hasLength(2));
      expect(adapter.calls, [
        'GET /api/orders/summary',
        'GET /api/orders/summary',
      ]);
    });
  });

  group('POST /api/orders/{id}/open', () {
    test('returns the unwrapped order detail', () async {
      final (client, adapter) = _client(
        (_) => (
          status: 200,
          body: {
            'success': true,
            'data': {
              'order': {'id': 12, 'seat_orders': const []},
              'session': {'table_id': 4},
            },
          },
        ),
      );

      final detail = await OrderRemoteDataSource(client).openOrder(12);

      expect(detail['id'], 12);
      expect(adapter.calls, ['POST /api/orders/12/open']);
    });

    test('409 table in use surfaces as ApiException',
        () async {
      final (client, _) = _client(
        (_) => (
          status: 409,
          body: {'success': false, 'message': 'Table already in use'},
        ),
      );

      await expectLater(
        OrderRemoteDataSource(client).openOrder(12),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'status', 409),
        ),
      );
    });

    test('payload for another order is rejected', () async {
      final (client, _) = _client(
        (_) => (status: 200, body: {'success': true, 'data': {'id': 99}}),
      );

      await expectLater(
        OrderRemoteDataSource(client).openOrder(12),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
