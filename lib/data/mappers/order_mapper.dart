import 'package:flutter/material.dart';

import '../../models/order_product.dart';
import '../../models/session_order.dart';
import '../../utils/app_theme.dart';
import '../models/open_order_summary.dart';

class ResolvedTable {
  const ResolvedTable({
    required this.id,
    required this.tableNumber,
    this.salesZoneId,
    this.existingOrderId,
    this.status,
    this.isSeparated = false,
  });

  final int id;
  final int tableNumber;
  final int? salesZoneId;
  final int? existingOrderId;
  final String? status;
  final bool isSeparated;

  bool get hasActiveOrder => existingOrderId != null && existingOrderId! > 0;

  bool get isAvailable => status == 'available' && !hasActiveOrder;
}

class OrderMapper {
  OrderMapper._();

  static String tableDisplayNumber(String tableNumber) =>
      'T${tableNumber.trim()}';

  /// Builds an open-orders row from [GET /api/orders/:id] when the list lags.
  static OpenOrderSummary summaryFromDetail(
    Map<String, dynamic> data, {
    int? fallbackTableNumber,
  }) {
    final orderId = (data['id'] as num?)?.toInt() ?? 0;
    final tableId = (data['table_id'] as num?)?.toInt();

    var tableNumber = tableNumberFromDetail(data);
    tableNumber ??= fallbackTableNumber;

    return OpenOrderSummary(
      id: orderId,
      orderNumber: '${data['order_number'] ?? orderId}',
      tableId: tableId,
      tableNumber: tableNumber,
      status: '${data['status'] ?? 'open'}',
      totalPrice: '${data['total_price'] ?? '0'}',
      createdAt: data['created_at'] as String?,
    );
  }

  static SessionOrder fromOpenOrder(OpenOrderSummary summary) {
    return SessionOrder(
      id: summary.id,
      number: displayKey(
        orderId: summary.id,
        tableId: summary.tableId,
        tableNumber: summary.tableNumber,
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
    final tableNumber = tableNumberFromDetail(data);
    final tableId = (data['table_id'] as num?)?.toInt();
    final orderId = orderIdFromDetail(data);
    final printCount = (data['receipt_print_count'] as num?)?.toInt() ?? 0;

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
      products: extractProducts(data),
    );
  }

  static int orderIdFromDetail(Map<String, dynamic> data) =>
      (data['id'] as num?)?.toInt() ?? 0;

  static int? tableNumberFromDetail(Map<String, dynamic> data) {
    final direct = (data['table_number'] as num?)?.toInt();
    if (direct != null) return direct;

    final table = data['table'];
    if (table is Map<String, dynamic>) {
      return (table['table_number'] as num?)?.toInt() ??
          (table['number'] as num?)?.toInt();
    }
    return null;
  }

  static List<OrderProduct> extractProducts(Map<String, dynamic> data) {
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

          final status = item['status'] as String?;
          if (status == 'cancelled') continue;

          final product = item['product'];
          final name = product is Map<String, dynamic>
              ? (product['name'] as String? ?? 'Article')
              : 'Article';
          final qty = item['qty'] ?? 1;
          final subTotal = item['sub_total']?.toString() ?? '0';
          final isOffer = item['is_offer'] == true;
          final comment = item['comment'];
          final message = comment is String && comment.trim().isNotEmpty
              ? comment.trim()
              : null;

          products.add(
            OrderProduct(
              quantity: '$qty',
              name: name,
              price: isOffer ? '0,00 €' : formatPrice(subTotal),
              message: message,
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

  /// Minimal payload to open an empty table. Do not send [seat_orders]:
  /// the API requires nested courses/items when that field is present.
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
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return null;

    final matches = _tablesMatchingNumber(tables, normalized);
    if (matches.isEmpty) return null;

    for (final table in matches) {
      final orderId = _activeOrderId(table);
      if (orderId != null) {
        return _toResolvedTable(table, orderId: orderId);
      }
    }

    final preferred = _pickTableForNewOrder(matches);
    return _toResolvedTable(preferred);
  }

  static List<Map<String, dynamic>> _tablesMatchingNumber(
    List<Map<String, dynamic>> tables,
    String normalized,
  ) {
    final matches = <Map<String, dynamic>>[];
    final parsed = int.tryParse(normalized);

    for (final table in tables) {
      final number = table['table_number']?.toString() ??
          table['number']?.toString();
      if (number == normalized) {
        matches.add(table);
        continue;
      }

      final id = table['id'];
      if (parsed != null && id is num && id.toInt() == parsed) {
        matches.add(table);
      }
    }

    return matches;
  }

  static Map<String, dynamic> _pickTableForNewOrder(
    List<Map<String, dynamic>> matches,
  ) {
    bool isParentTable(Map<String, dynamic> table) {
      if (table['is_separated'] == true) return false;
      final parentId = table['parent_table_id'];
      return parentId == null;
    }

    for (final table in matches) {
      if (!isParentTable(table)) continue;
      if (table['status'] == 'available' && _activeOrderId(table) == null) {
        return table;
      }
    }

    for (final table in matches) {
      if (table['status'] == 'available' && _activeOrderId(table) == null) {
        return table;
      }
    }

    for (final table in matches) {
      if (isParentTable(table)) return table;
    }

    return matches.first;
  }

  static int? _activeOrderId(Map<String, dynamic> table) {
    final activeOrder = table['active_order'];
    if (activeOrder is! Map<String, dynamic>) return null;
    return (activeOrder['id'] as num?)?.toInt();
  }

  static int? _salesZoneIdFromTable(Map<String, dynamic> table) {
    final direct = table['sales_zone_id'];
    if (direct is num) return direct.toInt();

    final activeOrder = table['active_order'];
    if (activeOrder is Map<String, dynamic>) {
      final fromOrder = activeOrder['sales_zone_id'];
      if (fromOrder is num) return fromOrder.toInt();
    }

    return null;
  }

  static ResolvedTable _toResolvedTable(
    Map<String, dynamic> table, {
    int? orderId,
  }) {
    final id = (table['id'] as num?)?.toInt() ?? 0;
    final tableNumber = (table['table_number'] as num?)?.toInt() ?? id;

    return ResolvedTable(
      id: id,
      tableNumber: tableNumber,
      salesZoneId: _salesZoneIdFromTable(table),
      existingOrderId: orderId ?? _activeOrderId(table),
      status: table['status'] as String?,
      isSeparated: table['is_separated'] == true,
    );
  }

  static int? activeOrderIdForTableNumber(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    return resolveTable(tables, tableNumber)?.existingOrderId;
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
        final courseIdInt = courseId is int
            ? courseId
            : (courseId is num ? courseId.toInt() : null);
        if (courseIdInt == null) continue;

        if (status == 'to_be_continued' || status == 'pending') {
          ids.add(courseIdInt);
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
        final courseIdInt = courseId is int
            ? courseId
            : (courseId is num ? courseId.toInt() : null);
        if (courseIdInt != null) ids.add(courseIdInt);
      }
    }

    return ids;
  }

  static int? resolveTableId(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    return resolveTable(tables, tableNumber)?.id;
  }

  static int? extractOrderIdFromPayload(Map<String, dynamic> data) {
    final direct = orderIdFromDetail(data);
    if (direct > 0) return direct;

    final activeOrder = data['active_order'];
    if (activeOrder is Map<String, dynamic>) {
      final id = (activeOrder['id'] as num?)?.toInt();
      if (id != null && id > 0) return id;
    }

    final orderId = data['order_id'];
    if (orderId is num) return orderId.toInt();

    return null;
  }
}
