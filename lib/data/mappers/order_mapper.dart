import 'package:flutter/material.dart';

import '../../models/order_product.dart';
import '../../models/session_order.dart';
import '../../utils/app_theme.dart';
import '../models/open_order_summary.dart';

class ResolvedTable {
  const ResolvedTable({
    required this.id,
    this.salesZoneId,
  });

  final int id;
  final int? salesZoneId;
}

class OrderMapper {
  OrderMapper._();

  static SessionOrder fromOpenOrder(OpenOrderSummary summary) {
    return SessionOrder(
      id: summary.id,
      number: displayKey(
        orderId: summary.id,
        tableId: summary.tableId,
      ),
      numberColor: AppTheme.primary,
      group: '1',
      poste: '—',
      profitCenter: 'SUR PLACE',
      couverts: '0',
      impressionCount: 0,
      impressionColor: impressionColorFor(0),
      total: formatPrice(summary.totalPrice),
      products: const [],
    );
  }

  static SessionOrder fromOrderDetail(Map<String, dynamic> data) {
    final tableNumber = data['table_number'] as int?;
    final tableId = data['table_id'] as int?;
    final orderId = data['id'] as int? ?? 0;
    final printCount = data['receipt_print_count'] as int? ?? 0;

    final salesZone = data['sales_zone'];
    final zoneName = salesZone is Map<String, dynamic>
        ? (salesZone['name'] as String? ?? 'SUR PLACE')
        : 'SUR PLACE';

    final waiter = data['waiter'];
    final waiterName =
        waiter is Map<String, dynamic> ? (waiter['name'] as String? ?? '—') : '—';

    return SessionOrder(
      id: orderId,
      number: displayKey(
        orderId: orderId,
        tableId: tableId,
        tableNumber: tableNumber,
      ),
      numberColor: AppTheme.primary,
      group: '1',
      poste: _shortPoste(waiterName),
      profitCenter: zoneName.toUpperCase(),
      couverts: '${data['number_of_guests'] ?? 0}',
      impressionCount: printCount,
      impressionColor: impressionColorFor(printCount),
      total: formatPrice('${data['total_price'] ?? '0'}'),
      products: _extractProducts(data),
    );
  }

  static List<OrderProduct> _extractProducts(Map<String, dynamic> data) {
    final products = <OrderProduct>[];
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return products;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final items = course['items'];
        if (items is! List) continue;

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          final product = item['product'];
          final name = product is Map<String, dynamic>
              ? (product['name'] as String? ?? 'Article')
              : 'Article';
          final qty = item['qty'] ?? 1;
          final subTotal = item['sub_total']?.toString() ?? '0';
          final isOffer = item['is_offer'] == true;

          products.add(
            OrderProduct(
              quantity: '$qty',
              name: name,
              price: isOffer ? '0,00 €' : formatPrice(subTotal),
              message: item['comment'] as String?,
            ),
          );
        }
      }
    }

    return products;
  }

  static String displayKey({
    required int orderId,
    int? tableId,
    int? tableNumber,
  }) {
    final table = tableNumber ?? tableId;
    if (table != null) return 'T$table';
    return 'O$orderId';
  }

  static String formatPrice(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return '${parsed.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  static Color impressionColorFor(int count) {
    if (count <= 0) return const Color(0xFFE74C3C);
    if (count == 1) return const Color(0xFFF1C40F);
    return const Color(0xFF27AE60);
  }

  static String _shortPoste(String waiterName) {
    if (waiterName == '—' || waiterName.isEmpty) return '—';
    final parts = waiterName.trim().split(' ');
    if (parts.length == 1) return parts.first.length > 6 ? 'POC1' : parts.first;
    return parts.first;
  }

  /// Marks every line item as offered inside a raw order detail payload.
  static Map<String, dynamic> applyTableOffer(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    final seatOrders = copy['seat_orders'];
    if (seatOrders is! List) return copy;

    final updatedSeats = <dynamic>[];
    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) {
        updatedSeats.add(seat);
        continue;
      }
      final seatCopy = Map<String, dynamic>.from(seat);
      final courses = seatCopy['courses'];
      if (courses is List) {
        seatCopy['courses'] = courses.map((course) {
          if (course is! Map<String, dynamic>) return course;
          final courseCopy = Map<String, dynamic>.from(course);
          final items = courseCopy['items'];
          if (items is List) {
            courseCopy['items'] = items.map((item) {
              if (item is! Map<String, dynamic>) return item;
              final itemCopy = Map<String, dynamic>.from(item);
              itemCopy['is_offer'] = true;
              itemCopy['offer_reason'] = 'Table offerte';
              itemCopy['offer_datetime'] =
                  DateTime.now().toUtc().toIso8601String();
              itemCopy['sub_total'] = '0.00';
              return itemCopy;
            }).toList();
          }
          return courseCopy;
        }).toList();
      }
      updatedSeats.add(seatCopy);
    }

    copy['seat_orders'] = updatedSeats;
    copy['total_price'] = '0.00';
    copy['remaining_amount'] = '0.00';
    return copy;
  }

  static Map<String, dynamic> buildCreateOrderPayload({
    required int waiterId,
    required int numberOfGuests,
    required int tableId,
    int? salesZoneId,
  }) {
    final payload = <String, dynamic>{
      'waiter_id': waiterId,
      'number_of_guests': numberOfGuests,
      'table_id': tableId,
      // Business flow: table + guests only. Backend requires seat_orders but
      // not courses/items when opening an empty table.
      'seat_orders': [
        {'seat_number': 1},
      ],
    };

    if (salesZoneId != null) {
      payload['sales_zone_id'] = salesZoneId;
    }

    return payload;
  }

  static Map<String, dynamic> buildStartTableSessionPayload({
    required int waiterId,
    required int numberOfGuests,
  }) {
    return {
      'waiter_id': waiterId,
      'number_of_guests': numberOfGuests,
    };
  }

  static ResolvedTable? resolveTable(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    final id = resolveTableId(tables, tableNumber);
    if (id == null) return null;

    for (final table in tables) {
      final tableId = table['id'];
      if (tableId != id) continue;

      final zoneId = table['sales_zone_id'];
      return ResolvedTable(
        id: id,
        salesZoneId: zoneId is int ? zoneId : (zoneId as num?)?.toInt(),
      );
    }

    return ResolvedTable(id: id);
  }

  static List<int> extractRequestableCourseIds(Map<String, dynamic> data) {
    final ids = <int>[];
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return ids;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final status = course['status'] as String?;
        final courseId = course['id'];
        if (courseId is! int) continue;

        if (status == 'to_be_continued' || status == 'pending') {
          ids.add(courseId);
        }
      }
    }

    if (ids.isNotEmpty) return ids;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final courseId = course['id'];
        if (courseId is int) ids.add(courseId);
      }
    }

    return ids;
  }

  static int? resolveTableId(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return null;

    for (final table in tables) {
      final number = table['table_number']?.toString() ??
          table['number']?.toString() ??
          table['name']?.toString();
      if (number == normalized) {
        final id = table['id'];
        if (id is int) return id;
      }
    }

    final parsed = int.tryParse(normalized);
    if (parsed != null) {
      for (final table in tables) {
        final id = table['id'];
        if (id == parsed) return parsed;
      }
      return parsed;
    }

    return null;
  }
}
