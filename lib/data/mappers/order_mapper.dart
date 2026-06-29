import 'package:flutter/material.dart';

import '../../models/order_product.dart';
import '../../models/session_order.dart';
import '../../utils/app_theme.dart';

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

  /// Builds session rows from [GET /api/tables/list]:
  /// tables with [active_order] and open tables with [session] only.
  static List<SessionOrder> sessionOrdersFromTables(
    List<Map<String, dynamic>> tables,
  ) {
    final byDisplay = <String, SessionOrder>{};
    final sortMillisByDisplay = <String, int>{};

    // Pass 1: rows with active_order always win (e.g. separated T25 vs parent session).
    for (final table in tables) {
      final activeOrder = table['active_order'];
      if (activeOrder is! Map<String, dynamic>) continue;

      final orderId = (activeOrder['id'] as num?)?.toInt();
      if (orderId == null || orderId <= 0) continue;

      final tableNumber = (table['table_number'] as num?)?.toInt();
      final displayNumber = tableDisplayNumber(
        '${tableNumber ?? tableNumberFromDetail(activeOrder) ?? orderId}',
      );

      byDisplay[displayNumber] =
          fromOrderDetail(activeOrder).copyWith(number: displayNumber);
      sortMillisByDisplay[displayNumber] = _tableSortMillis(table);
    }

    // Pass 2: session-only tables not already represented by an order.
    for (final table in tables) {
      if (!_hasOpenSession(table)) continue;

      final sessionOrder = fromTableSession(table);
      final displayNumber = sessionOrder.number;
      if (byDisplay.containsKey(displayNumber)) continue;

      byDisplay[displayNumber] = sessionOrder;
      sortMillisByDisplay[displayNumber] = _tableSortMillis(table);
    }

    final displayNumbers = byDisplay.keys.toList()
      ..sort(
        (a, b) => (sortMillisByDisplay[b] ?? 0)
            .compareTo(sortMillisByDisplay[a] ?? 0),
      );

    return displayNumbers.map((number) => byDisplay[number]!).toList();
  }

  static bool _hasOpenSession(Map<String, dynamic> table) {
    if (_activeOrderId(table) != null) return false;

    if (table['session'] is Map<String, dynamic>) return true;
    if (table['status'] == 'open') return true;
    if (table['is_locked'] == true) return true;

    return false;
  }

  static SessionOrder fromTableSession(Map<String, dynamic> table) {
    final tableId = (table['id'] as num?)?.toInt() ?? 0;
    final tableNumber = (table['table_number'] as num?)?.toInt() ?? tableId;
    final session = table['session'];
    final sessionMap =
        session is Map<String, dynamic> ? session : const <String, dynamic>{};

    final waiterName = sessionMap['waiter_name'] as String? ?? '—';
    final guests = sessionMap['number_of_guests'];
    final floorName = table['floor_name'] as String? ?? 'SUR PLACE';

    return SessionOrder(
      id: -tableId,
      number: tableDisplayNumber('$tableNumber'),
      numberColor: AppTheme.primary,
      group: '1',
      poste: _shortPoste(waiterName),
      profitCenter: floorName.toUpperCase(),
      couverts: '${guests ?? 0}',
      impressionCount: 0,
      impressionColor: impressionColorFor(0),
      total: formatPrice('0'),
      products: const [],
    );
  }

  static int _tableSortMillis(Map<String, dynamic> table) {
    final activeOrder = table['active_order'];
    if (activeOrder is Map<String, dynamic>) {
      final createdAt = activeOrder['created_at'];
      if (createdAt is String) {
        return DateTime.tryParse(createdAt)?.millisecondsSinceEpoch ?? 0;
      }
    }

    final session = table['session'];
    if (session is Map<String, dynamic>) {
      final lockedAt = session['locked_at'];
      if (lockedAt is String) {
        return DateTime.tryParse(lockedAt)?.millisecondsSinceEpoch ?? 0;
      }
    }

    final tableLockedAt = table['locked_at'];
    if (tableLockedAt is String) {
      return DateTime.tryParse(tableLockedAt)?.millisecondsSinceEpoch ?? 0;
    }

    return 0;
  }

  static bool isTableOccupied(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    return isTableInUse(tables, tableNumber);
  }

  static bool hasExistingActiveOrder(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    final resolved = resolveTableForNewOrder(tables, tableNumber);
    return resolved?.hasActiveOrder ?? false;
  }

  /// Table already has an order or an open session (no new table entry).
  static bool isTableInUse(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    if (hasExistingActiveOrder(tables, tableNumber)) return true;

    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return false;

    for (final table in _tablesMatchingNumber(tables, normalized)) {
      if (_hasOpenSession(table)) return true;
    }

    return false;
  }

  /// Picks the table row used for [POST /api/orders] (available seat first).
  static ResolvedTable? resolveTableForNewOrder(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return null;

    final matches = _tablesMatchingNumber(tables, normalized);
    if (matches.isEmpty) return null;

    return _toResolvedTable(_pickTableForNewOrder(matches));
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
      total: formatPrice(
        '${data['total_price'] ?? data['remaining_amount'] ?? '0'}',
      ),
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

    final zone = table['sales_zone'];
    if (zone is Map<String, dynamic>) {
      final zoneId = zone['id'];
      if (zoneId is num) return zoneId.toInt();
    }

    final activeOrder = table['active_order'];
    if (activeOrder is Map<String, dynamic>) {
      final fromOrder = activeOrder['sales_zone_id'];
      if (fromOrder is num) return fromOrder.toInt();

      final orderZone = activeOrder['sales_zone'];
      if (orderZone is Map<String, dynamic>) {
        final zoneId = orderZone['id'];
        if (zoneId is num) return zoneId.toInt();
      }
    }

    return null;
  }

  /// Resolves sales zone from active day, target table, or any table in the list.
  static int? inferSalesZoneId(
    List<Map<String, dynamic>> tables, {
    int? preferred,
    ResolvedTable? table,
  }) {
    if (preferred != null && preferred > 0) return preferred;
    if (table?.salesZoneId != null && table!.salesZoneId! > 0) {
      return table.salesZoneId;
    }

    for (final entry in tables) {
      final id = _salesZoneIdFromTable(entry);
      if (id != null && id > 0) return id;
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

  static int? activeOrderIdForTableId(
    List<Map<String, dynamic>> tables,
    int tableId,
  ) {
    for (final table in tables) {
      if ((table['id'] as num?)?.toInt() != tableId) continue;
      return _activeOrderId(table);
    }
    return null;
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

  /// Default seat for adding items (first seat in order, else 1).
  static int resolveDefaultSeatNumber(Map<String, dynamic> detail) {
    final seatOrders = detail['seat_orders'];
    if (seatOrders is List && seatOrders.isNotEmpty) {
      final first = seatOrders.first;
      if (first is Map<String, dynamic>) {
        final seatNumber = first['seat_number'];
        if (seatNumber is num) return seatNumber.toInt();
      }
    }
    return 1;
  }

  /// Seat order row id (POST URL fallback when [seat_number] fails).
  static int? resolveSeatOrderRecordId(
    Map<String, dynamic> detail, {
    int? seatNumber,
  }) {
    final targetSeat = seatNumber ?? resolveDefaultSeatNumber(detail);
    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List) return null;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final seatNo = (seat['seat_number'] as num?)?.toInt();
      if (seatNo == targetSeat) {
        return (seat['id'] as num?)?.toInt();
      }
    }
    return null;
  }

  /// Active course on the target seat.
  static ({int? id, int number}) resolveActiveCourse(
    Map<String, dynamic> detail, {
    int? seatNumber,
  }) {
    final targetSeat = seatNumber ?? resolveDefaultSeatNumber(detail);
    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List || seatOrders.isEmpty) {
      return (id: null, number: 1);
    }

    int? lastActiveId;
    int? lastActiveNumber;
    int? lastAnyId;
    int? lastAnyNumber;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final seatNo = (seat['seat_number'] as num?)?.toInt();
      if (seatNo != targetSeat) continue;

      final courses = seat['courses'];
      if (courses is! List) continue;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final courseNumber = (course['course_number'] as num?)?.toInt();
        if (courseNumber == null) continue;

        final courseId = (course['id'] as num?)?.toInt();
        lastAnyId = courseId;
        lastAnyNumber = courseNumber;

        final status = course['status'] as String?;
        if (status == 'in_progress' ||
            status == 'to_be_continued' ||
            status == 'pending') {
          lastActiveId = courseId;
          lastActiveNumber = courseNumber;
        }
      }
    }

    return (
      id: lastActiveId ?? lastAnyId,
      number: lastActiveNumber ?? lastAnyNumber ?? 1,
    );
  }

  /// POST body field `course_number` expects the course database id.
  static int resolvePostCourseNumber(({int? id, int number}) course) {
    return course.id ?? course.number;
  }

  static Map<String, dynamic> buildAddSeatOrderItemsPayload({
    required int courseNumber,
    required int productId,
    required double unitPrice,
    int qty = 1,
    String comment = '',
    List<Map<String, dynamic>>? menuSelections,
    double? subTotal,
  }) {
    final item = <String, dynamic>{
      'product_id': productId,
      'qty': qty,
      'sub_total': subTotal ?? unitPrice * qty,
      'comment': comment,
    };
    if (menuSelections != null && menuSelections.isNotEmpty) {
      item['menu_selections'] = menuSelections;
    }

    return {
      'course_number': courseNumber,
      'items': [item],
    };
  }

  /// PUT /api/orders/:id writable body.
  static Map<String, dynamic> buildOrderUpdatePayload(
    Map<String, dynamic> orderDetail,
  ) {
    final seatOrders = orderDetail['seat_orders'];
    return {
      'waiter_id': orderDetail['waiter_id'],
      'number_of_guests': orderDetail['number_of_guests'],
      if (orderDetail['sales_zone_id'] != null)
        'sales_zone_id': orderDetail['sales_zone_id'],
      if (orderDetail['table_id'] != null) 'table_id': orderDetail['table_id'],
      if (orderDetail['customer_id'] != null)
        'customer_id': orderDetail['customer_id'],
      'seat_orders': seatOrders is List
          ? seatOrders
              .whereType<Map<String, dynamic>>()
              .map(_sanitizeSeatOrderForUpdate)
              .toList()
          : <dynamic>[],
    };
  }

  static Map<String, dynamic> appendComposedItem({
    required Map<String, dynamic> orderDetail,
    required int productId,
    required double subTotal,
    required List<Map<String, dynamic>> menuSelections,
    String comment = '',
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final course = resolveActiveCourse(working, seatNumber: seatNumber);
    final itemStatus = _resolveItemStatusForCourse(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
    );

    final newItem = <String, dynamic>{
      'seat_number': seatNumber,
      if (course.id != null) 'course_id': course.id,
      if (course.id != null) 'course_number': course.number,
      'product_id': productId,
      'product': {'id': productId},
      'qty': 1,
      'sub_total': _formatMoney(subTotal),
      'status': itemStatus,
      'comment': comment,
      'menu_selections': menuSelections,
    };

    _appendItemToSeatOrders(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
      newItem: newItem,
    );

    return buildOrderUpdatePayload(working);
  }

  static void _appendItemToSeatOrders(
    Map<String, dynamic> detail, {
    required int seatNumber,
    required int courseNumber,
    required Map<String, dynamic> newItem,
  }) {
    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List || seatOrders.isEmpty) {
      detail['seat_orders'] = [
        {
          'seat_number': seatNumber,
          'courses': [
            {
              'course_number': courseNumber,
              'seat_number': seatNumber,
              'items': [newItem],
            },
          ],
        },
      ];
      return;
    }

    final updatedSeats = <dynamic>[];
    var itemAdded = false;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) {
        updatedSeats.add(seat);
        continue;
      }

      final seatCopy = Map<String, dynamic>.from(seat);
      final seatNo = (seatCopy['seat_number'] as num?)?.toInt() ?? seatNumber;

      if (!itemAdded && seatNo == seatNumber) {
        final courses = seatCopy['courses'];
        if (courses is List && courses.isNotEmpty) {
          seatCopy['courses'] = courses.map((course) {
            if (course is! Map<String, dynamic>) return course;
            final courseCopy = Map<String, dynamic>.from(course);
            final cn = (courseCopy['course_number'] as num?)?.toInt();
            if (cn == courseNumber) {
              final items = courseCopy['items'];
              final itemsList =
                  items is List ? List<dynamic>.from(items) : <dynamic>[];
              itemsList.add(newItem);
              courseCopy['items'] = itemsList;
              itemAdded = true;
            }
            return courseCopy;
          }).toList();
        } else {
          seatCopy['courses'] = [
            {
              'course_number': courseNumber,
              'seat_number': seatNumber,
              'items': [newItem],
            },
          ];
          itemAdded = true;
        }
      }

      updatedSeats.add(seatCopy);
    }

    if (!itemAdded) {
      updatedSeats.add({
        'seat_number': seatNumber,
        'courses': [
          {
            'course_number': courseNumber,
            'seat_number': seatNumber,
            'items': [newItem],
          },
        ],
      });
    }

    detail['seat_orders'] = updatedSeats;
  }

  static String _resolveItemStatusForCourse(
    Map<String, dynamic> detail, {
    required int seatNumber,
    required int courseNumber,
  }) {
    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List) return 'in_progress';

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      if ((seat['seat_number'] as num?)?.toInt() != seatNumber) continue;

      final courses = seat['courses'];
      if (courses is! List) continue;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        if ((course['course_number'] as num?)?.toInt() != courseNumber) {
          continue;
        }

        final items = course['items'];
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final status = item['status'];
              if (status is String && status.isNotEmpty) return status;
            }
          }
        }

        final courseStatus = course['status'];
        if (courseStatus is String && courseStatus.isNotEmpty) {
          return courseStatus;
        }
      }
    }

    return 'in_progress';
  }

  static Map<String, dynamic> _sanitizeSeatOrderForUpdate(
    Map<String, dynamic> seat,
  ) {
    final courses = seat['courses'];
    final sanitized = <String, dynamic>{
      'seat_number': seat['seat_number'],
      'courses': courses is List
          ? courses
              .whereType<Map<String, dynamic>>()
              .map(_sanitizeCourseForUpdate)
              .toList()
          : <dynamic>[],
    };
    final id = seat['id'];
    final orderId = seat['order_id'];
    if (id != null) sanitized['id'] = id;
    if (orderId != null) sanitized['order_id'] = orderId;
    return sanitized;
  }

  static Map<String, dynamic> _sanitizeCourseForUpdate(
    Map<String, dynamic> course,
  ) {
    final items = course['items'];
    final sanitized = <String, dynamic>{
      'course_number': course['course_number'],
      'seat_number': course['seat_number'],
      'items': items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(_sanitizeItemForUpdate)
              .toList()
          : <dynamic>[],
    };
    final id = course['id'];
    final orderId = course['order_id'];
    if (id != null) sanitized['id'] = id;
    if (orderId != null) sanitized['order_id'] = orderId;
    if (course['label'] != null) sanitized['label'] = course['label'];
    if (course['status'] != null) sanitized['status'] = course['status'];
    return sanitized;
  }

  static Map<String, dynamic> _sanitizeItemForUpdate(Map<String, dynamic> item) {
    final product = item['product'];
    final productId = (item['product_id'] as num?)?.toInt() ??
        (product is Map<String, dynamic>
            ? (product['id'] as num?)?.toInt()
            : null);

    final sanitized = <String, dynamic>{
      'seat_number': item['seat_number'],
      if (item['course_id'] != null) 'course_id': item['course_id'],
      if (item['course_number'] != null) 'course_number': item['course_number'],
      if (productId != null) 'product': {'id': productId},
      if (productId != null) 'product_id': productId,
      'sub_total': item['sub_total'],
      'qty': item['qty'],
      'status': item['status'] ?? 'in_progress',
      'comment': item['comment'] ?? '',
    };

    final id = item['id'];
    final orderId = item['order_id'];
    if (id != null) sanitized['id'] = id;
    if (orderId != null) sanitized['order_id'] = orderId;

    final menuSelections = item['menu_selections'];
    if (menuSelections is List && menuSelections.isNotEmpty) {
      sanitized['menu_selections'] = menuSelections;
    }

    return sanitized;
  }

  static String _formatMoney(double value) => value.toStringAsFixed(2);
}
