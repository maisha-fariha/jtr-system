import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/order_display_entry.dart';
import '../../models/order_product.dart';
import '../../models/session_order.dart';
import '../../utils/app_theme.dart';
import '../../utils/order_item_uid.dart';

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

  static String normalizeTableKey(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.replaceFirst(RegExp(r'^T'), '');
  }

  /// Resolves the waiter user id on an order or table-session payload.
  static int? waiterIdFromOrderMap(Map<String, dynamic> data) {
    final direct = data['waiter_id'];
    if (direct is num) return direct.toInt();

    final waiter = data['waiter'];
    if (waiter is Map<String, dynamic>) {
      final id = waiter['id'];
      if (id is num) return id.toInt();
    }

    final session = data['session'];
    if (session is Map<String, dynamic>) {
      final sessionWaiterId = session['waiter_id'];
      if (sessionWaiterId is num) return sessionWaiterId.toInt();

      final sessionWaiter = session['waiter'];
      if (sessionWaiter is Map<String, dynamic>) {
        final id = sessionWaiter['id'];
        if (id is num) return id.toInt();
      }
    }

    return null;
  }

  static bool orderBelongsToWaiter(
    Map<String, dynamic> order,
    int waiterId,
  ) {
    if (waiterId <= 0) return true;
    final orderWaiterId = waiterIdFromOrderMap(order);
    return orderWaiterId != null && orderWaiterId == waiterId;
  }

  /// Builds session rows from [GET /api/orders] (active-day open orders).
  ///
  /// [lightweight] skips product/seat parsing — use for the session list.
  static List<SessionOrder> sessionOrdersFromOrdersList(
    List<Map<String, dynamic>> orders, {
    int? waiterId,
    bool lightweight = false,
  }) {
    final sortMillisById = <int, int>{};
    final rows = <SessionOrder>[];
    final seenOrderIds = <int>{};

    for (final order in orders) {
      if (!isActiveDayOpenOrder(order)) continue;
      if (waiterId != null &&
          waiterId > 0 &&
          !orderBelongsToWaiter(order, waiterId)) {
        continue;
      }

      final orderId = orderIdFromDetail(order);
      if (orderId <= 0 || seenOrderIds.contains(orderId)) continue;
      seenOrderIds.add(orderId);

      rows.add(
        lightweight
            ? sessionOrderSummaryFromListMap(order)
            : fromOrderDetail(order),
      );
      sortMillisById[orderId] = _orderSortMillis(order);
    }

    rows.sort(
      (a, b) =>
          (sortMillisById[b.id] ?? 0).compareTo(sortMillisById[a.id] ?? 0),
    );
    return rows;
  }

  /// Fast list-row mapping — header fields only (no seat/product tree).
  static SessionOrder sessionOrderSummaryFromListMap(
    Map<String, dynamic> data,
  ) {
    final tableNumber = tableNumberFromDetail(data);
    final orderId = orderIdFromDetail(data);
    final printCount = (data['receipt_print_count'] as num?)?.toInt() ?? 0;

    final salesZone = data['sales_zone'];
    final zoneName = salesZone is Map<String, dynamic>
        ? (salesZone['name'] as String? ?? 'SUR PLACE')
        : (data['sales_zone_name'] as String? ?? 'SUR PLACE');

    final waiter = data['waiter'];
    final waiterName = waiter is Map<String, dynamic>
        ? (waiter['name'] as String? ?? '—')
        : (data['waiter_name'] as String? ?? '—');

    return SessionOrder(
      id: orderId,
      number: displayKey(orderId: orderId, tableNumber: tableNumber),
      numberColor: AppTheme.primary,
      group: '1',
      poste: _shortPoste(waiterName),
      profitCenter: zoneName.toUpperCase(),
      couverts: '${data['number_of_guests'] ?? data['guests'] ?? 0}',
      impressionCount: printCount,
      impressionColor: impressionColorFor(printCount),
      total: formatPrice(
        '${data['total_price'] ?? data['remaining_amount'] ?? '0'}',
      ),
      products: const [],
      displayEntries: const [],
      waiterId: waiterIdFromOrderMap(data),
    );
  }

  /// Keeps only open orders for the active business day list.
  static bool isActiveDayOpenOrder(Map<String, dynamic> order) {
    final status = order['status']?.toString().toLowerCase();
    return status != 'closed' && status != 'cancelled';
  }

  /// True when the order has no non-cancelled line items.
  static bool orderDetailHasNoVisibleItems(Map<String, dynamic> orderDetail) {
    return countVisibleLineItems(orderDetail) == 0;
  }

  static int countVisibleLineItems(Map<String, dynamic> orderDetail) {
    return extractProducts(orderDetail).length;
  }

  static bool isOrderClosedOrCancelled(Map<String, dynamic> orderDetail) {
    final status = orderDetail['status']?.toString().toLowerCase();
    return status == 'closed' || status == 'cancelled';
  }

  static bool isOrderFullyPaid(Map<String, dynamic> orderDetail) {
    final detailed =
        orderDetail['payment_status_detailed']?.toString().toLowerCase();
    if (detailed == 'fully_paid' || detailed == 'paid') return true;

    final payment = orderDetail['payment_status']?.toString().toLowerCase();
    return payment == 'fully_paid' ||
        payment == 'paid' ||
        payment == 'completed';
  }

  /// Empty shells that the backend already closed/paid cannot accept new lines.
  /// The first new item must open a fresh order for the same table.
  static bool shouldRecreateOrderForAdd(Map<String, dynamic> orderDetail) {
    if (!orderDetailHasNoVisibleItems(orderDetail)) return false;
    return isOrderClosedOrCancelled(orderDetail) ||
        isOrderFullyPaid(orderDetail);
  }

  /// Status to keep an emptied order open (delete icon is the only closer).
  static String preserveOpenOrderStatus(Map<String, dynamic> orderDetail) {
    final status = orderDetail['status']?.toString();
    if (status != null &&
        status.isNotEmpty &&
        status.toLowerCase() != 'closed' &&
        status.toLowerCase() != 'cancelled') {
      return status;
    }
    return 'open';
  }

  /// Local cache copy that stays visible in the session list after all items
  /// were cancelled (backend may mark the order closed automatically).
  static Map<String, dynamic> asOpenEmptyOrderShell(
    Map<String, dynamic> orderDetail,
  ) {
    final copy = Map<String, dynamic>.from(orderDetail);
    if (isOrderClosedOrCancelled(copy) || isOrderFullyPaid(copy)) {
      copy['status'] = preserveOpenOrderStatus(orderDetail);
      copy['payment_status'] = 'unpaid';
      copy['payment_status_detailed'] = 'unpaid';
    }
    copy['total_price'] = copy['total_price'] ?? '0';
    copy['remaining_amount'] = copy['remaining_amount'] ?? '0';
    return copy;
  }

  /// Union of [GET /api/orders] pages/lists by id (later list wins on duplicate).
  static List<Map<String, dynamic>> mergeOrderMapLists(
    List<Map<String, dynamic>> first,
    List<Map<String, dynamic>> second,
  ) {
    final byId = <int, Map<String, dynamic>>{};
    for (final order in first) {
      final id = orderIdFromDetail(order);
      if (id > 0) byId[id] = order;
    }
    for (final order in second) {
      final id = orderIdFromDetail(order);
      if (id > 0) byId[id] = order;
    }
    return byId.values.toList(growable: false);
  }

  static int _orderSortMillis(Map<String, dynamic> order) {
    final createdAt = order['created_at'];
    if (createdAt is String) {
      return DateTime.tryParse(createdAt)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  static bool _hasOpenSession(Map<String, dynamic> table) {
    if (_activeOrderId(table) != null) return false;

    if (table['session'] is Map<String, dynamic>) return true;
    if (table['status'] == 'open') return true;
    if (table['is_locked'] == true) return true;

    return false;
  }

  /// Waiter that owns the table lock / session (no active order required).
  static int? tableSessionOwnerId(Map<String, dynamic> table) {
    final lockedBy = table['locked_by'];
    if (lockedBy is num && lockedBy.toInt() > 0) return lockedBy.toInt();
    return waiterIdFromOrderMap(table);
  }

  /// Waiter assigned to the table's active order (if any).
  static int? activeOrderOwnerId(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return null;

    for (final table in _tablesMatchingNumber(tables, normalized)) {
      final active = table['active_order'];
      if (active is Map<String, dynamic>) {
        final fromOrder = waiterIdFromOrderMap(active);
        if (fromOrder != null && fromOrder > 0) return fromOrder;
      }
      if (_activeOrderId(table) != null) {
        final fromTable = waiterIdFromOrderMap(table);
        if (fromTable != null && fromTable > 0) return fromTable;
      }
    }
    return null;
  }

  /// Status of the table's active order (`pending`, `open`, …), if any.
  static String? activeOrderStatus(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return null;

    for (final table in _tablesMatchingNumber(tables, normalized)) {
      final active = table['active_order'];
      if (active is Map<String, dynamic>) {
        final status = active['status']?.toString().trim();
        if (status != null && status.isNotEmpty) return status.toLowerCase();
      }
    }
    return null;
  }

  /// True when another waiter owns this table's order/session.
  static bool isAssignedToOtherWaiter(
    List<Map<String, dynamic>> tables,
    String tableNumber, {
    required int waiterId,
  }) {
    if (waiterId <= 0) return false;

    final orderOwner = activeOrderOwnerId(tables, tableNumber);
    if (orderOwner != null && orderOwner > 0 && orderOwner != waiterId) {
      return true;
    }

    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return false;

    for (final table in _tablesMatchingNumber(tables, normalized)) {
      final sessionOwner = tableSessionOwnerId(table);
      if (sessionOwner != null &&
          sessionOwner > 0 &&
          sessionOwner != waiterId) {
        // Other waiter holds lock/session or is listed on the table row.
        if (_activeOrderId(table) != null ||
            hasOrphanSessionWithoutOrder(table) ||
            table['is_locked'] == true ||
            table['status'] == 'open') {
          return true;
        }
      }

      // active_order present without our waiter id → treat as foreign.
      if (_activeOrderId(table) != null) {
        final active = table['active_order'];
        if (active is Map<String, dynamic>) {
          final activeWaiter = waiterIdFromOrderMap(active);
          if (activeWaiter != null &&
              activeWaiter > 0 &&
              activeWaiter != waiterId) {
            return true;
          }
          // Has active order but waiter unknown and not reclaimable by us.
          if (activeWaiter == null || activeWaiter <= 0) {
            final lockedBy = table['locked_by'];
            if (lockedBy is num &&
                lockedBy.toInt() > 0 &&
                lockedBy.toInt() != waiterId) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Skip dialog whenever another waiter owns the table (order or session lock).
  /// Own reclaimable orphan sessions never skip.
  static bool shouldShowSkipDialogForCreate(
    List<Map<String, dynamic>> tables,
    String tableNumber, {
    required int waiterId,
  }) {
    if (waiterId <= 0) return false;
    if (canReclaimOrphanTableSession(
      tables,
      tableNumber,
      waiterId: waiterId,
    )) {
      return false;
    }

    if (isAssignedToOtherWaiter(
      tables,
      tableNumber,
      waiterId: waiterId,
    )) {
      return true;
    }

    // Table already in use (order/session) and not reclaimable by this waiter.
    return isTableInUse(tables, tableNumber);
  }

  /// API messages that mean this waiter cannot take over the table.
  static bool isTableOwnershipDeniedMessage(String message) {
    final msg = message.toLowerCase();
    return msg.contains('not allowed to release') ||
        msg.contains('not allowed') ||
        msg.contains('release this table') ||
        msg.contains('n\'est pas autoris') ||
        msg.contains('pas autoris') ||
        msg.contains('occup') ||
        msg.contains('already') ||
        msg.contains('lock') ||
        (msg.contains('waiter') && msg.contains('table')) ||
        msg.contains('session');
  }

  /// Open/locked session with no [active_order] (orphan after session-only create).
  static bool hasOrphanSessionWithoutOrder(Map<String, dynamic> table) {
    if (_activeOrderId(table) != null) return false;
    return _hasOpenSession(table);
  }

  /// Same waiter left a session with no order — safe to end and reopen.
  static bool canReclaimOrphanTableSession(
    List<Map<String, dynamic>> tables,
    String tableNumber, {
    required int waiterId,
  }) {
    if (waiterId <= 0) return false;
    if (hasExistingActiveOrder(tables, tableNumber)) return false;

    final normalized = tableNumber.trim();
    if (normalized.isEmpty) return false;

    for (final table in _tablesMatchingNumber(tables, normalized)) {
      if (!hasOrphanSessionWithoutOrder(table)) continue;
      final owner = tableSessionOwnerId(table);
      if (owner != null && owner == waiterId) return true;
    }
    return false;
  }

  static bool isTableOccupied(
    List<Map<String, dynamic>> tables,
    String tableNumber, {
    int? forWaiterId,
  }) {
    if (forWaiterId != null &&
        canReclaimOrphanTableSession(
          tables,
          tableNumber,
          waiterId: forWaiterId,
        )) {
      return false;
    }
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

  /// True when this table row can accept [POST /api/orders] (new order).
  static bool canPostNewOrderOnTable(Map<String, dynamic> table) =>
      reasonCannotPostNewOrderOnTable(table) == null;

  /// Human-readable blocker, or `null` when POST is allowed on this row.
  static String? reasonCannotPostNewOrderOnTable(Map<String, dynamic> table) {
    final activeId = _activeOrderId(table);
    if (activeId != null) return 'active_order=$activeId';

    if (_hasOpenSession(table)) {
      if (table['session'] is Map<String, dynamic>) return 'open session';
      if (table['status'] == 'open') return 'status=open';
      if (table['is_locked'] == true) return 'is_locked';
      return 'in use';
    }

    if (table['status'] != 'available') {
      return 'status=${table['status'] ?? '—'}';
    }

    return null;
  }

  /// Multi-line summary for console: which table rows can receive POST /api/orders.
  static String buildTablesPostOrderAvailabilityLog(
    List<Map<String, dynamic>> tables, {
    String? targetTableNumber,
  }) {
    final buffer = StringBuffer(
      'Tables for POST /api/orders (${tables.length} rows from GET /api/tables/list):',
    );

    final sorted = List<Map<String, dynamic>>.from(tables);
    sorted.sort((a, b) {
      final an = (a['table_number'] as num?)?.toInt() ??
          (a['id'] as num?)?.toInt() ??
          0;
      final bn = (b['table_number'] as num?)?.toInt() ??
          (b['id'] as num?)?.toInt() ??
          0;
      return an.compareTo(bn);
    });

    final targetId = targetTableNumber == null
        ? null
        : resolveTableForNewOrder(tables, targetTableNumber)?.id;

    for (final table in sorted) {
      final id = (table['id'] as num?)?.toInt() ?? 0;
      final tableNum = (table['table_number'] as num?)?.toInt() ?? id;
      final status = table['status'] ?? '—';
      final activeId = _activeOrderId(table);
      final hasSession = table['session'] is Map<String, dynamic>;
      final locked = table['is_locked'] == true;
      final separated = table['is_separated'] == true;
      final reason = reasonCannotPostNewOrderOnTable(table);
      final targetMark = targetId != null && id == targetId ? ' [TARGET]' : '';
      final verdict = reason == null ? '→ OK' : '→ SKIP ($reason)';

      buffer.writeln(
        '  id=$id T$tableNum status=$status '
        'active_order=${activeId ?? 'null'} '
        'session=${hasSession ? 'yes' : 'no'} '
        'locked=${locked ? 'yes' : 'no'}'
        '${separated ? ' separated' : ''}$targetMark $verdict',
      );
    }

    final okCount = sorted.where(canPostNewOrderOnTable).length;
    buffer.writeln('  Summary: $okCount/${sorted.length} rows OK for POST');

    if (targetTableNumber != null) {
      final resolved = resolveTableForNewOrder(tables, targetTableNumber);
      if (resolved == null) {
        buffer.writeln('  Target T$targetTableNumber: NOT FOUND');
      } else {
        final blocked = reasonCannotPostNewOrderOnTable(
          _pickTableForNewOrder(
            _tablesMatchingNumber(tables, targetTableNumber.trim()),
          ),
        );
        buffer.writeln(
          '  Target T$targetTableNumber → id=${resolved.id} '
          'status=${resolved.status ?? '—'} '
          'active_order=${resolved.existingOrderId ?? 'null'} '
          '${blocked == null ? '→ will POST' : '→ blocked ($blocked)'}',
        );
      }
    }

    return buffer.toString().trimRight();
  }

  static SessionOrder fromOrderDetail(
    Map<String, dynamic> data, {
    List<OrderDisplayEntry>? previousDisplayEntries,
    List<int> suivreSplitHints = const [],
    int suivreCountHint = 0,
  }) {
    final tableNumber = tableNumberFromDetail(data);
    final orderId = orderIdFromDetail(data);
    final printCount = (data['receipt_print_count'] as num?)?.toInt() ?? 0;

    final salesZone = data['sales_zone'];
    final zoneName = salesZone is Map<String, dynamic>
        ? (salesZone['name'] as String? ?? 'SUR PLACE')
        : 'SUR PLACE';

    final waiter = data['waiter'];
    final waiterName =
        waiter is Map<String, dynamic> ? (waiter['name'] as String? ?? '—') : '—';

    final products = extractProducts(data);
    final displayEntries = finalizeDisplayEntries(
      data,
      previousDisplayEntries: previousDisplayEntries,
      suivreSplitHints: suivreSplitHints,
      suivreCountHint: suivreCountHint,
    );

    return SessionOrder(
      id: orderId,
      number: displayKey(
        orderId: orderId,
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
      products: products,
      displayEntries: displayEntries.isNotEmpty
          ? displayEntries
          : [
              for (var i = 0; i < products.length; i++)
                OrderDisplayEntry.product(
                  product: products[i],
                  lineIndex: i,
                ),
            ],
      waiterId: waiterIdFromOrderMap(data),
    );
  }

  static int orderIdFromDetail(Map<String, dynamic> data) =>
      (data['id'] as num?)?.toInt() ?? 0;

  static int? tableNumberFromDetail(Map<String, dynamic> data) {
    final direct = _readTableNumberField(data['table_number']);
    if (direct != null) return direct;

    final table = data['table'];
    if (table is Map<String, dynamic>) {
      return _readTableNumberField(table['table_number']) ??
          _readTableNumberField(table['number']);
    }
    return null;
  }

  static int? _readTableNumberField(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  static List<Map<String, dynamic>> _sortedCoursesList(dynamic coursesRaw) {
    if (coursesRaw is! List) return const [];

    final parsed = <Map<String, dynamic>>[];
    for (final course in coursesRaw) {
      if (course is Map<String, dynamic>) parsed.add(course);
    }
    parsed.sort((a, b) {
      final left = (a['course_number'] as num?)?.toInt() ?? 0;
      final right = (b['course_number'] as num?)?.toInt() ?? 0;
      return left.compareTo(right);
    });
    return parsed;
  }

  static List<OrderProduct> extractProducts(Map<String, dynamic> data) {
    final products = <OrderProduct>[];
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return products;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = _sortedCoursesList(seat['courses']);

      for (final course in courses) {
        final items = course['items'];
        if (items is! List) continue;

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;

          final status = item['status'] as String?;
          if (status == 'cancelled') continue;

          products.add(orderProductFromItem(item));
        }
      }
    }

    return products;
  }

  static OrderDisplayEntry _suivreEntry(
    int sectionIndex, {
    required int courseNumber,
  }) =>
      OrderDisplayEntry.suivre(
        sectionIndex: sectionIndex,
        courseNumber: courseNumber,
      );

  static int? _resolveCourseNumberAboveInDisplay(
    List<OrderDisplayEntry> entries,
  ) {
    for (var i = entries.length - 1; i >= 0; i--) {
      final entry = entries[i];
      if (entry.type == OrderDisplayEntryType.product) {
        return entry.courseNumber;
      }
    }
    return null;
  }

  /// API course_number for the service tied to a selected À SUIVRE row.
  static int? resolveCourseNumberForSuivreSection(
    List<OrderDisplayEntry> entries,
    int suivreSectionIndex,
  ) {
    final idx = entries.indexWhere(
      (entry) =>
          entry.isSectionDivider && entry.sectionIndex == suivreSectionIndex,
    );
    if (idx < 0) return null;

    final divider = entries[idx];
    if (divider.courseNumber != null) return divider.courseNumber;

    for (var i = idx - 1; i >= 0; i--) {
      final previous = entries[i];
      if (previous.isSectionDivider) break;
      if (previous.type == OrderDisplayEntryType.product &&
          previous.courseNumber != null) {
        return previous.courseNumber;
      }
    }

    return null;
  }

  static bool _isSectionDivider(OrderDisplayEntry entry) =>
      entry.isSectionDivider;

  static String? formatDemandeTime(dynamic requestedAt) {
    if (requestedAt == null) return null;
    final raw = requestedAt.toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    final local = parsed.toLocal();
    final hours = local.hour.toString().padLeft(2, '0');
    final minutes = local.minute.toString().padLeft(2, '0');
    final seconds = local.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static Map<String, dynamic>? findCourseInOrderDetail(
    Map<String, dynamic> data,
    int courseNumber,
  ) {
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return null;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        if ((course['course_number'] as num?)?.toInt() == courseNumber) {
          return course;
        }
      }
    }

    return null;
  }

  static List<OrderDisplayEntry> applyDemandeSeparatorsFromApi(
    Map<String, dynamic> data,
    List<OrderDisplayEntry> entries,
  ) {
    final result = <OrderDisplayEntry>[];

    for (final entry in entries) {
      if (entry.type != OrderDisplayEntryType.suivreSeparator) {
        result.add(entry);
        continue;
      }

      final sectionIndex = entry.sectionIndex ?? 0;
      final courseNumber = entry.courseNumber ?? sectionIndex;
      if (sectionIndex <= 0 && courseNumber <= 0) {
        result.add(entry);
        continue;
      }

      // À SUIVRE headers store the course-number "above" (used to route new
      // items into the next course). Show DEMANDÉE only when that follow-up
      // course (`courseNumber + 1`) was requested — not when an earlier course
      // above the divider was already sent to the kitchen.
      final courseNext = courseNumber > 0
          ? findCourseInOrderDetail(data, courseNumber + 1)
          : null;

      final courseToUse = courseNext != null &&
              _courseWasRequestedToKitchen(courseNext)
          ? courseNext
          : null;

      if (courseToUse == null) {
        result.add(entry);
        continue;
      }

      final timeLabel = formatDemandeTime(courseToUse['requested_at']);
      if (timeLabel == null) {
        result.add(entry);
        continue;
      }

      result.add(
        OrderDisplayEntry.demande(
          sectionIndex: sectionIndex,
          courseNumber: courseNumber,
          demandeTimeLabel: timeLabel,
        ),
      );
    }

    return result;
  }

  static void _appendSuivreIfNeeded({
    required List<OrderDisplayEntry> entries,
    required int sectionIndex,
    required int courseNumber,
  }) {
    if (entries.isNotEmpty &&
        entries.last.type == OrderDisplayEntryType.suivreSeparator &&
        entries.last.sectionIndex == sectionIndex) {
      return;
    }
    entries.add(_suivreEntry(sectionIndex, courseNumber: courseNumber));
  }

  static int _resolveItemCourseGroupKey(
    Map<String, dynamic> item,
    Map<String, dynamic> course,
    int courseIndex,
  ) {
    final itemCourseId = (item['course_id'] as num?)?.toInt();
    if (itemCourseId != null && itemCourseId > 0) {
      return itemCourseId;
    }

    final courseId = (course['id'] as num?)?.toInt();
    if (courseId != null && courseId > 0) {
      return courseId;
    }

    final courseNumber = (course['course_number'] as num?)?.toInt();
    if (courseNumber != null) {
      return courseNumber;
    }

    return courseIndex + 1;
  }

  static List<OrderDisplayEntry> extractOrderDisplayEntries(
    Map<String, dynamic> data,
  ) {
    final entries = <OrderDisplayEntry>[];
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return entries;

    var lineIndex = 0;
    var suivreSectionIndex = 0;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final coursesRaw = seat['courses'];
      if (coursesRaw is! List || coursesRaw.isEmpty) continue;

      final courses = <Map<String, dynamic>>[];
      for (final course in coursesRaw) {
        if (course is Map<String, dynamic>) courses.add(course);
      }
      courses.sort((a, b) {
        final left = (a['course_number'] as num?)?.toInt() ?? 0;
        final right = (b['course_number'] as num?)?.toInt() ?? 0;
        return left.compareTo(right);
      });

      final firstCourseNumber =
          (courses.first['course_number'] as num?)?.toInt() ?? 1;

      int? firstGroupKey;
      int? currentGroupKey;

      for (var courseIndex = 0; courseIndex < courses.length; courseIndex++) {
        final course = courses[courseIndex];
        final courseNumber =
            (course['course_number'] as num?)?.toInt() ?? firstCourseNumber;
        final items = course['items'];

        final visibleItems = <Map<String, dynamic>>[];
        if (items is List) {
          for (final item in items) {
            if (item is! Map<String, dynamic>) continue;
            if (item['status'] == 'cancelled') continue;
            visibleItems.add(item);
          }
        }

        final isFollowUpCourse =
            courseIndex > 0 || courseNumber > firstCourseNumber;
        var activeSection = 0;
        var suivreHeaderForCourse = false;

        if (isFollowUpCourse && visibleItems.isEmpty) {
          continue;
        }

        if (isFollowUpCourse && visibleItems.isNotEmpty) {
          suivreSectionIndex++;
          activeSection = suivreSectionIndex;
          final demandCourseNumber = courseIndex > 0
              ? ((courses[courseIndex - 1]['course_number'] as num?)?.toInt() ??
                  courseNumber - 1)
              : courseNumber - 1;
          _appendSuivreIfNeeded(
            entries: entries,
            sectionIndex: activeSection,
            courseNumber: demandCourseNumber,
          );
          suivreHeaderForCourse = true;
        }

        var sawNonSuivreItemsInCourse = false;

        for (final item in visibleItems) {
          final groupKey =
              _resolveItemCourseGroupKey(item, course, courseIndex);
          final itemStatus = item['status'] as String?;
          final isSuivreItem = itemStatus == 'to_be_continued';

          if (firstGroupKey == null) {
            firstGroupKey = groupKey;
            currentGroupKey = groupKey;
            activeSection = 0;
          } else if (groupKey != currentGroupKey) {
            suivreSectionIndex++;
            activeSection = suivreSectionIndex;
            _appendSuivreIfNeeded(
              entries: entries,
              sectionIndex: activeSection,
              courseNumber: courseNumber,
            );
            currentGroupKey = groupKey;
            suivreHeaderForCourse = true;
            sawNonSuivreItemsInCourse = false;
          } else if (isFollowUpCourse && !suivreHeaderForCourse) {
            suivreSectionIndex++;
            activeSection = suivreSectionIndex;
            final demandCourseNumber = courseIndex > 0
                ? ((courses[courseIndex - 1]['course_number'] as num?)?.toInt() ??
                    courseNumber - 1)
                : courseNumber - 1;
            _appendSuivreIfNeeded(
              entries: entries,
              sectionIndex: activeSection,
              courseNumber: demandCourseNumber,
            );
            suivreHeaderForCourse = true;
          }

          if (isSuivreItem &&
              sawNonSuivreItemsInCourse &&
              !suivreHeaderForCourse) {
            suivreSectionIndex++;
            activeSection = suivreSectionIndex;
            _appendSuivreIfNeeded(
              entries: entries,
              sectionIndex: activeSection,
              courseNumber: courseNumber,
            );
            suivreHeaderForCourse = true;
          }

          if (!isSuivreItem) {
            sawNonSuivreItemsInCourse = true;
          }

          entries.add(
            OrderDisplayEntry.product(
              product: orderProductFromItem(item),
              lineIndex: lineIndex++,
              sectionIndex: activeSection,
              courseNumber: courseNumber,
            ),
          );
        }
      }
    }

    return entries;
  }

  static Map<String, dynamic> buildSeatOrderItemsPostPayload({
    required int courseNumber,
    required int productId,
    required int qty,
    required double subTotal,
    String comment = '',
  }) {
    return {
      'course_number': courseNumber,
      'items': [
        {
          'product_id': productId,
          'qty': qty,
          'sub_total': subTotal,
          'comment': comment,
        },
      ],
    };
  }

  static List<int> suivreSplitPositions(List<OrderDisplayEntry> entries) {
    final splits = <int>[];
    var productCount = 0;

    for (final entry in entries) {
      if (_isSectionDivider(entry)) {
        splits.add(productCount);
      } else if (entry.type == OrderDisplayEntryType.product) {
        productCount++;
      }
    }

    return splits;
  }

  static List<OrderDisplayEntry> _rebuildEntriesWithSuivreSplits(
    List<OrderDisplayEntry> entries,
    List<int> splitPositions,
  ) {
    if (splitPositions.isEmpty) return entries;

    final products = entries
        .where((entry) => entry.type == OrderDisplayEntryType.product)
        .toList();
    if (products.isEmpty) return entries;

    final validSplits = splitPositions
        .where((splitAt) => splitAt > 0 && splitAt < products.length)
        .toSet()
        .toList()
      ..sort();
    if (validSplits.isEmpty) return entries;

    final rebuilt = <OrderDisplayEntry>[];
    var lineIndex = 0;
    var sectionIndex = 0;
    var splitIdx = 0;

    for (var i = 0; i < products.length; i++) {
      while (splitIdx < validSplits.length && i == validSplits[splitIdx]) {
        sectionIndex++;
        final demandCourseNumber =
            products[i - 1].courseNumber ?? products[i].courseNumber ?? 1;
        rebuilt.add(
          _suivreEntry(
            sectionIndex,
            courseNumber: demandCourseNumber,
          ),
        );
        splitIdx++;
      }

      final productEntry = products[i];
      rebuilt.add(
        OrderDisplayEntry.product(
          product: productEntry.product!,
          lineIndex: lineIndex++,
          sectionIndex: sectionIndex,
          courseNumber: productEntry.courseNumber,
        ),
      );
    }

    return rebuilt;
  }

  static int suivreSeparatorCount(List<OrderDisplayEntry> entries) {
    return entries
        .where((entry) => entry.type == OrderDisplayEntryType.suivreSeparator)
        .length;
  }

  static List<int> _mergeSuivreSplitPositions({
    required List<int> extracted,
    List<int> hints = const [],
    List<OrderDisplayEntry>? previous,
  }) {
    final merged = <int>{...extracted, ...hints};
    if (previous != null) {
      merged.addAll(suivreSplitPositions(previous));
    }
    final sorted = merged.toList()..sort();
    return sorted;
  }

  /// Keeps À SUIVRE rows when a refresh returns fewer separators than before.
  static List<OrderDisplayEntry> reconcileSuivreDisplay({
    required List<OrderDisplayEntry> previous,
    required List<OrderDisplayEntry> next,
  }) {
    final previousSplits = suivreSplitPositions(previous);
    final nextSplits = suivreSplitPositions(next);
    final previousCount = suivreSeparatorCount(previous);
    final nextCount = suivreSeparatorCount(next);

    var result = next;

    if (previousSplits.isNotEmpty &&
        (nextSplits.length < previousSplits.length || nextCount < previousCount)) {
      final mergedSplits = _mergeSuivreSplitPositions(
        extracted: nextSplits,
        hints: previousSplits,
      );
      result = _rebuildEntriesWithSuivreSplits(next, mergedSplits);
    }

    if (previousCount > suivreSeparatorCount(result)) {
      result = ensureSuivreSeparatorCount(
        result,
        previousCount,
        forceAppend: true,
      );
    }

    return result;
  }

  static int? suivreSplitAt(List<OrderDisplayEntry> entries) {
    final splits = suivreSplitPositions(entries);
    if (splits.isEmpty) return null;
    return splits.first;
  }

  static List<OrderDisplayEntry> applySuivreSplitToProductEntries(
    List<OrderDisplayEntry> entries,
    int splitAt,
  ) {
    if (entries.any(_isSectionDivider)) {
      return entries;
    }

    return _rebuildEntriesWithSuivreSplits(entries, [splitAt]);
  }

  static List<OrderDisplayEntry> finalizeDisplayEntries(
    Map<String, dynamic> data, {
    List<OrderDisplayEntry>? previousDisplayEntries,
    List<int> suivreSplitHints = const [],
    int suivreCountHint = 0,
  }) {
    var entries = extractOrderDisplayEntries(data);
    entries = applyDemandeSeparatorsFromApi(data, entries);
    final apiSuivreCount = suivreSeparatorCount(entries);
    final previousSuivreCount = previousDisplayEntries == null
        ? 0
        : suivreSeparatorCount(previousDisplayEntries);
    final effectiveSuivreCount = suivreCountHint > previousSuivreCount
        ? suivreCountHint
        : previousSuivreCount;

    // Only overlay local À SUIVRE rows that are not yet reflected by API courses.
    if (effectiveSuivreCount > apiSuivreCount) {
      var pending = effectiveSuivreCount - apiSuivreCount;
      while (pending > 0) {
        final force = entries.isNotEmpty && _isSectionDivider(entries.last);
        entries = appendSuivreSeparatorAfterRequest(entries, force: force);
        pending--;
      }
    }

    if (previousDisplayEntries != null && previousDisplayEntries.isNotEmpty) {
      entries = reconcileSuivreDisplay(
        previous: previousDisplayEntries,
        next: entries,
      );
    }

    return _normalizeSuivreLayout(
      entries,
      keepTrailingEmptySuivre: effectiveSuivreCount > apiSuivreCount,
    );
  }

  static List<OrderDisplayEntry> _normalizeSuivreLayout(
    List<OrderDisplayEntry> entries, {
    bool keepTrailingEmptySuivre = false,
  }) {
    var result = _dedupeConsecutiveSuivreSeparators(entries);
    result = _stripEmptySuivreSections(
      result,
      keepTrailingEmpty: keepTrailingEmptySuivre,
    );
    if (!keepTrailingEmptySuivre) {
      result = _stripTrailingEmptySuivreSeparators(result);
    }
    return result;
  }

  static List<OrderDisplayEntry> _dedupeConsecutiveSuivreSeparators(
    List<OrderDisplayEntry> entries,
  ) {
    final result = <OrderDisplayEntry>[];
    for (final entry in entries) {
      if (_isSectionDivider(entry) &&
          result.isNotEmpty &&
          _isSectionDivider(result.last)) {
        continue;
      }
      result.add(entry);
    }
    return result;
  }

  /// Drops À SUIVRE headers that are not followed by any product line.
  static List<OrderDisplayEntry> _stripEmptySuivreSections(
    List<OrderDisplayEntry> entries, {
    bool keepTrailingEmpty = false,
  }) {
    final result = <OrderDisplayEntry>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.type == OrderDisplayEntryType.demandeSeparator) {
        result.add(entry);
        continue;
      }
      if (entry.type != OrderDisplayEntryType.suivreSeparator) {
        result.add(entry);
        continue;
      }

      var hasProducts = false;
      for (var j = i + 1; j < entries.length; j++) {
        if (_isSectionDivider(entries[j])) break;
        if (entries[j].type == OrderDisplayEntryType.product) {
          hasProducts = true;
          break;
        }
      }

      if (hasProducts) {
        result.add(entry);
        continue;
      }

      if (keepTrailingEmpty) {
        var hasLaterDivider = false;
        for (var j = i + 1; j < entries.length; j++) {
          if (_isSectionDivider(entries[j])) {
            hasLaterDivider = true;
            break;
          }
        }
        if (!hasLaterDivider) {
          result.add(entry);
        }
      }
    }
    return result;
  }

  /// Removes À SUIVRE rows that have no products after them.
  static List<OrderDisplayEntry> _stripTrailingEmptySuivreSeparators(
    List<OrderDisplayEntry> entries,
  ) {
    if (entries.isEmpty) return entries;

    var end = entries.length;
    while (end > 0 &&
        entries[end - 1].type == OrderDisplayEntryType.suivreSeparator) {
      end--;
    }

    return end == entries.length ? entries : entries.sublist(0, end);
  }

  /// Appends one À SUIVRE row to open the next local course section.
  static List<OrderDisplayEntry> appendSuivreSeparatorAfterRequest(
    List<OrderDisplayEntry> entries, {
    bool force = false,
  }) {
    if (entries.isEmpty) return entries;

    if (!force &&
        entries.isNotEmpty &&
        entries.last.type == OrderDisplayEntryType.suivreSeparator) {
      return entries;
    }

    final nextSection = entries
            .map((e) => e.sectionIndex ?? 0)
            .fold<int>(0, (max, value) => value > max ? value : max) +
        1;
    final demandCourseNumber = _resolveCourseNumberAboveInDisplay(entries);
    if (demandCourseNumber == null) return entries;

    return [
      ...entries,
      _suivreEntry(nextSection, courseNumber: demandCourseNumber),
    ];
  }

  static List<OrderDisplayEntry> ensureSuivreSeparatorCount(
    List<OrderDisplayEntry> entries,
    int expectedCount, {
    bool forceAppend = false,
  }) {
    if (expectedCount <= 0) return entries;

    var result = entries;
    while (suivreSeparatorCount(result) < expectedCount) {
      result = appendSuivreSeparatorAfterRequest(
        result,
        force: forceAppend,
      );
    }
    return result;
  }

  /// Ensures a visible À SUIVRE row when the API has not yet split courses.
  static List<OrderDisplayEntry> ensureTrailingSuivreMarker(
    List<OrderDisplayEntry> entries,
  ) {
    if (entries.any(_isSectionDivider)) {
      return entries;
    }
    return appendSuivreSeparatorAfterRequest(entries);
  }

  /// Session row label from API fields only (`table_number`, else order `id`).
  static String displayKey({
    required int orderId,
    int? tableNumber,
  }) {
    if (tableNumber != null) return 'T$tableNumber';
    if (orderId > 0) return 'O$orderId';
    return '—';
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
    return buildOrderUpdatePayload(copy);
  }

  /// Header POST /api/orders (table + waiter, no lines).
  static Map<String, dynamic> buildCreateOrderHeaderPayload({
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
    if (salesZoneId != null) payload['sales_zone_id'] = salesZoneId;
    return payload;
  }

  /// POST /api/orders with seat/course shell and one selected line item.
  static Map<String, dynamic> buildCreateOrderSeatCoursePayload({
    required int waiterId,
    required int numberOfGuests,
    required int tableId,
    required int productId,
    required double unitPrice,
    int? salesZoneId,
    int qty = 1,
  }) {
    const seatNumber = 1;
    final item = _buildNewItemPayload(
      seatNumber: seatNumber,
      courseId: 0,
      productId: productId,
      qty: qty,
      subTotal: unitPrice * qty,
      status: 'to_be_continued',
      comment: '',
      forCreate: true,
    );
    final payload = <String, dynamic>{
      'waiter_id': waiterId,
      'number_of_guests': numberOfGuests,
      'table_id': tableId,
      'seat_orders': [
        {
          'seat_number': seatNumber,
          'courses': [
            {
              'id': 0,
              'course_number': 1,
              'seat_number': seatNumber,
              'items': [item],
            },
          ],
        },
      ],
    };
    if (salesZoneId != null) payload['sales_zone_id'] = salesZoneId;
    return payload;
  }

  /// Payload candidates for POST /api/orders when the waiter selected a product
  /// (first article on a new/local order). Never used for empty table open.
  static List<Map<String, dynamic>> createOrderPayloadCandidates({
    required int waiterId,
    required int numberOfGuests,
    required int tableId,
    required int productId,
    required double unitPrice,
    int? salesZoneId,
  }) {
    return [
      buildCreateOrderWithItemPayload(
        waiterId: waiterId,
        numberOfGuests: numberOfGuests,
        productId: productId,
        unitPrice: unitPrice,
        tableId: tableId,
        salesZoneId: salesZoneId,
      ),
      buildCreateOrderSeatCoursePayload(
        waiterId: waiterId,
        numberOfGuests: numberOfGuests,
        tableId: tableId,
        productId: productId,
        unitPrice: unitPrice,
        salesZoneId: salesZoneId,
      ),
    ];
  }

  /// Session-only placeholder until the first selected article POSTs /api/orders.
  /// [id] is `-tableId` so delete can end the table session while local-only.
  static SessionOrder buildSessionPlaceholderOrder({
    required int tableNumber,
    required int numberOfGuests,
    int? tableId,
  }) {
    return SessionOrder(
      id: tableId != null && tableId > 0 ? -tableId : 0,
      number: displayKey(orderId: 0, tableNumber: tableNumber),
      numberColor: AppTheme.primary,
      group: '1',
      poste: '—',
      profitCenter: 'SUR PLACE',
      couverts: '$numberOfGuests',
      impressionCount: 0,
      impressionColor: impressionColorFor(0),
      total: formatPrice('0'),
      products: const [],
    );
  }

  /// Valid POST /api/orders body per Orders API spec.
  ///
  /// All nested ids are `0`; new items carry a client [uid]. Matches:
  /// waiter_id, number_of_guests, sales_zone_id, seat_orders → courses/items.
  static Map<String, dynamic> buildCreateOrderWithItemPayload({
    required int waiterId,
    required int numberOfGuests,
    required int productId,
    required double unitPrice,
    int? tableId,
    int? salesZoneId,
    int qty = 1,
    String comment = '',
    String status = 'to_be_continued',
    List<Map<String, dynamic>> menuSelections = const [],
    bool isStillMenuMissing = false,
  }) {
    const seatNumber = 1;
    final item = _buildNewItemPayload(
      seatNumber: seatNumber,
      courseId: 0,
      productId: productId,
      qty: qty,
      subTotal: unitPrice * qty,
      status: status,
      comment: comment,
      menuSelections: menuSelections,
      isStillMenuMissing: isStillMenuMissing,
      forCreate: true,
    );

    final payload = <String, dynamic>{
      'waiter_id': waiterId,
      'number_of_guests': numberOfGuests,
      'seat_orders': [
        {
          'seat_number': seatNumber,
          'courses': [
            {
              'id': 0,
              'course_number': 1,
              'seat_number': seatNumber,
              'items': [item],
            },
          ],
        },
      ],
    };

    if (salesZoneId != null) payload['sales_zone_id'] = salesZoneId;
    // Optional: some backends also accept table_id; session start usually binds it.
    if (tableId != null) payload['table_id'] = tableId;

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

  static int guestsForTable(List<Map<String, dynamic>> tables, int tableId) {
    for (final table in tables) {
      if ((table['id'] as num?)?.toInt() != tableId) continue;
      final session = table['session'];
      if (session is Map<String, dynamic>) {
        final guests = session['number_of_guests'];
        if (guests is num && guests > 0) return guests.toInt();
      }
      final activeOrder = table['active_order'];
      if (activeOrder is Map<String, dynamic>) {
        final guests = activeOrder['number_of_guests'];
        if (guests is num && guests > 0) return guests.toInt();
      }
    }
    return 1;
  }

  static List<int> extractRequestableCourseIds(Map<String, dynamic> data) {
    int? bestId;
    var bestNumber = -1;

    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return const [];

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        if (_visibleItemCountInCourse(course) <= 0) continue;
        if (_courseWasRequestedToKitchen(course)) continue;

        final status = course['status'] as String?;
        final courseId = course['id'];
        final courseIdInt = courseId is int
            ? courseId
            : (courseId is num ? courseId.toInt() : null);
        if (courseIdInt == null) continue;

        if (status == 'to_be_continued' ||
            status == 'pending' ||
            status == 'in_progress') {
          final courseNumber = (course['course_number'] as num?)?.toInt() ?? 0;
          if (bestId == null || courseNumber < bestNumber) {
            bestNumber = courseNumber;
            bestId = courseIdInt;
          }
        }
      }
    }

    if (bestId != null) return [bestId];

    bestId = null;
    bestNumber = -1;
    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        if (_visibleItemCountInCourse(course) <= 0) continue;
        if (_courseWasRequestedToKitchen(course)) continue;

        final courseId = course['id'];
        final courseIdInt = courseId is int
            ? courseId
            : (courseId is num ? courseId.toInt() : null);
        if (courseIdInt == null) continue;
        final courseNumber = (course['course_number'] as num?)?.toInt() ?? 0;
        if (bestId == null || courseNumber < bestNumber) {
          bestNumber = courseNumber;
          bestId = courseIdInt;
        }
      }
    }

    return bestId != null ? [bestId] : const [];
  }

  /// Course id for demande on a selected À SUIVRE section.
  static List<int> extractRequestableCourseIdsForSuivreSection(
    Map<String, dynamic> data, {
    required int courseNumber,
  }) {
    final courseId = _resolveRequestableCourseIdForNumber(
      data,
      courseNumber: courseNumber,
      requireKnownStatus: true,
    );
    if (courseId != null) return [courseId];

    final fallbackId = _resolveRequestableCourseIdForNumber(
      data,
      courseNumber: courseNumber,
      requireKnownStatus: false,
    );
    return fallbackId != null ? [fallbackId] : const [];
  }

  static String describeWhySuivreSectionNotRequestable(
    Map<String, dynamic> data, {
    required int courseNumber,
  }) {
    if (courseNumber <= 0) {
      return 'Sélectionnez un À SUIVRE avant de demander.';
    }

    final course = findCourseInOrderDetail(data, courseNumber);
    if (course == null) {
      return 'Service $courseNumber introuvable sur cette commande.';
    }

    if (_visibleItemCountInCourse(course) <= 0) {
      return 'Ce service ne contient aucun article à envoyer en cuisine.';
    }

    if (_courseWasRequestedToKitchen(course)) {
      final time = formatDemandeTime(course['requested_at']);
      if (time != null) {
        return 'Ce service a déjà été demandé à $time.';
      }
      return 'Ce service a déjà été demandé en cuisine.';
    }

    final status = course['status'] as String?;
    if (status != null &&
        status != 'to_be_continued' &&
        status != 'pending' &&
        status != 'in_progress') {
      return 'Ce service n\'est pas demandable (statut: $status).';
    }

    final courseId = course['id'];
    if (courseId == null) {
      return 'Identifiant du service introuvable.';
    }

    return 'Aucun service à demander pour cette section.';
  }

  static int? _resolveRequestableCourseIdForNumber(
    Map<String, dynamic> data, {
    required int courseNumber,
    required bool requireKnownStatus,
  }) {
    if (courseNumber <= 0) return null;

    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return null;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt();
        if (number != courseNumber) continue;
        if (_visibleItemCountInCourse(course) <= 0) continue;
        if (_courseWasRequestedToKitchen(course)) return null;

        if (requireKnownStatus) {
          final status = course['status'] as String?;
          if (status != 'to_be_continued' &&
              status != 'pending' &&
              status != 'in_progress') {
            continue;
          }
        }

        final courseId = course['id'];
        final courseIdInt = courseId is int
            ? courseId
            : (courseId is num ? courseId.toInt() : null);
        if (courseIdInt != null) return courseIdInt;
      }
    }

    return null;
  }

  /// Course ids to fire to the kitchen (send / envoyer).
  static List<int> extractKitchenSendCourseIds(Map<String, dynamic> data) {
    final ids = <int>{};
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return const [];

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
        if (courseIdInt == null) continue;

        final status = course['status'] as String?;
        if (status == 'in_progress' ||
            status == 'to_be_continued' ||
            status == 'pending') {
          ids.add(courseIdInt);
          continue;
        }

        final items = course['items'];
        if (items is! List) continue;
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          if (item['status'] == 'cancelled') continue;
          final itemStatus = item['status'] as String?;
          if (itemStatus == null ||
              itemStatus == 'in_progress' ||
              itemStatus == 'pending' ||
              itemStatus == 'to_be_continued') {
            ids.add(courseIdInt);
            break;
          }
        }
      }
    }

    if (ids.isNotEmpty) return ids.toList();

    return extractRequestableCourseIds(data);
  }

  /// Courses that must be sent to the kitchen before POST /api/orders/:id/pay.
  static List<int> extractCourseIdsPendingKitchenSendBeforePayment(
    Map<String, dynamic> data,
  ) {
    final ids = <int>{...extractKitchenSendCourseIds(data)};

    final seatOrders = data['seat_orders'];
    if (seatOrders is List) {
      for (final seat in seatOrders) {
        if (seat is! Map<String, dynamic>) continue;
        final courses = seat['courses'];
        if (courses is! List) continue;

        for (final course in courses) {
          if (course is! Map<String, dynamic>) continue;
          if (_visibleItemCountInCourse(course) <= 0) continue;
          if (_courseWasRequestedToKitchen(course)) continue;

          final courseId = course['id'];
          final courseIdInt = courseId is int
              ? courseId
              : (courseId is num ? courseId.toInt() : null);
          if (courseIdInt != null) ids.add(courseIdInt);
        }
      }
    }

    return ids.toList();
  }

  static bool requiresKitchenSendBeforePayment(Map<String, dynamic> data) {
    return extractCourseIdsPendingKitchenSendBeforePayment(data).isNotEmpty;
  }

  static bool isSendBeforePaymentError(ApiException error) {
    final message = error.message.toLowerCase();
    return message.contains('envoyer') &&
        (message.contains('payer') || message.contains('paiement'));
  }

  static int? resolveTableId(
    List<Map<String, dynamic>> tables,
    String tableNumber,
  ) {
    return resolveTable(tables, tableNumber)?.id;
  }

  static int? extractOrderIdFromPayload(Map<String, dynamic> data) {
    final activeOrder = data['active_order'];
    if (activeOrder is Map<String, dynamic>) {
      final id = (activeOrder['id'] as num?)?.toInt();
      if (id != null && id > 0) return id;
    }

    final nestedOrder = data['order'];
    if (nestedOrder is Map<String, dynamic>) {
      final id = orderIdFromDetail(nestedOrder);
      if (id > 0) return id;
    }

    final orderId = data['order_id'];
    if (orderId is num && orderId > 0) return orderId.toInt();

    // Table/session payloads must not treat table id as order id.
    if (data.containsKey('table_number') && activeOrder == null) {
      return null;
    }

    final order = unwrapOrderDetail(data);
    final direct = orderIdFromDetail(order);
    if (direct > 0) return direct;

    return null;
  }

  /// Normalizes create/update responses: `data.order` or raw order map.
  static Map<String, dynamic> unwrapOrderDetail(Map<String, dynamic> data) {
    final order = data['order'];
    if (order is Map<String, dynamic>) return order;
    if (data.containsKey('seat_orders') || orderIdFromDetail(data) > 0) {
      return data;
    }
    return data;
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

  static List<Map<String, dynamic>> _coursesForSeat(
    Map<String, dynamic> detail, {
    required int seatNumber,
  }) {
    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List) return const [];

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      if ((seat['seat_number'] as num?)?.toInt() != seatNumber) continue;

      final courses = seat['courses'];
      if (courses is! List) return const [];

      final parsed = <Map<String, dynamic>>[];
      for (final course in courses) {
        if (course is Map<String, dynamic>) parsed.add(course);
      }
      parsed.sort((a, b) {
        final left = (a['course_number'] as num?)?.toInt() ?? 0;
        final right = (b['course_number'] as num?)?.toInt() ?? 0;
        return left.compareTo(right);
      });
      return parsed;
    }

    return const [];
  }

  static int _visibleItemCountInCourse(Map<String, dynamic> course) {
    final items = course['items'];
    if (items is! List) return 0;

    var count = 0;
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      if (item['status'] == 'cancelled') continue;
      count++;
    }
    return count;
  }

  /// True when the course was already fired to the kitchen (demande done).
  static bool _courseWasRequestedToKitchen(Map<String, dynamic> course) {
    final requestedAt = course['requested_at'];
    if (requestedAt != null && requestedAt.toString().trim().isNotEmpty) {
      return true;
    }

    final status = course['status'] as String?;
    return status == 'requested' ||
        status == 'sent' ||
        status == 'served' ||
        status == 'completed' ||
        status == 'done';
  }

  static Map<String, dynamic>? _findCourseByNumber(
    List<Map<String, dynamic>> courses,
    int courseNumber,
  ) {
    for (final course in courses) {
      if ((course['course_number'] as num?)?.toInt() == courseNumber) {
        return course;
      }
    }
    return null;
  }

  static ({int? id, int number}) _resolveCourseTarget(
    List<Map<String, dynamic>> courses,
    int courseNumber,
  ) {
    final existing = _findCourseByNumber(courses, courseNumber);
    if (existing != null) {
      return (
        id: (existing['id'] as num?)?.toInt(),
        number: courseNumber,
      );
    }
    return (id: null, number: courseNumber);
  }

  /// Course number for the next item from the current display layout.
  static int? resolveAppendCourseNumberFromLayout(
    List<OrderDisplayEntry> layoutHints,
  ) {
    for (var i = layoutHints.length - 1; i >= 0; i--) {
      final entry = layoutHints[i];

      if (entry.type == OrderDisplayEntryType.suivreSeparator) {
        final above = entry.courseNumber;
        if (above != null && above > 0) return above + 1;
        return null;
      }

      if (entry.type == OrderDisplayEntryType.demandeSeparator) {
        final above = entry.courseNumber;
        if (above != null && above > 0) return above + 1;
        continue;
      }

      if (entry.type == OrderDisplayEntryType.product) {
        final number = entry.courseNumber;
        if (number != null && number > 0) return number;
        return null;
      }
    }

    return null;
  }

  /// Course that should receive newly added items (latest open course).
  static ({int? id, int number}) resolveAppendCourse(
    Map<String, dynamic> detail, {
    int? seatNumber,
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final targetSeat = seatNumber ?? resolveDefaultSeatNumber(detail);
    final courses = _coursesForSeat(detail, seatNumber: targetSeat);
    if (courses.isEmpty) {
      return (id: null, number: 1);
    }

    if (layoutHints != null && layoutHints.isNotEmpty) {
      final fromLayout = resolveAppendCourseNumberFromLayout(layoutHints);
      if (fromLayout != null && fromLayout > 0) {
        return _resolveCourseTarget(courses, fromLayout);
      }
    }

    var maxCourseNumber = 0;
    var coursesWithItems = 0;
    Map<String, dynamic>? latestCourseWithItems;
    var latestWithItemsNumber = 0;

    for (final course in courses) {
      final courseNumber = (course['course_number'] as num?)?.toInt() ?? 0;
      if (courseNumber > maxCourseNumber) {
        maxCourseNumber = courseNumber;
      }
      if (_visibleItemCountInCourse(course) <= 0) continue;

      coursesWithItems++;
      if (courseNumber >= latestWithItemsNumber) {
        latestWithItemsNumber = courseNumber;
        latestCourseWithItems = course;
      }
    }

    // Local À SUIVRE open: next items go to the course after the latest API course.
    if (suivreSectionCount > 0 && suivreSectionCount >= coursesWithItems) {
      final nextNumber = latestWithItemsNumber > 0
          ? latestWithItemsNumber + 1
          : maxCourseNumber + 1;
      return _resolveCourseTarget(courses, nextNumber);
    }

    // Prefer an empty follow-up course the backend may have opened after demande.
    for (var i = courses.length - 1; i >= 0; i--) {
      final course = courses[i];
      if (_visibleItemCountInCourse(course) > 0) continue;

      final courseNumber = (course['course_number'] as num?)?.toInt();
      if (courseNumber == null) continue;

      return (
        id: (course['id'] as num?)?.toInt(),
        number: courseNumber,
      );
    }

    if (latestCourseWithItems != null) {
      if (!_courseWasRequestedToKitchen(latestCourseWithItems)) {
        return (
          id: (latestCourseWithItems['id'] as num?)?.toInt(),
          number: latestWithItemsNumber,
        );
      }

      return _resolveCourseTarget(courses, latestWithItemsNumber + 1);
    }

    return _resolveCourseTarget(courses, maxCourseNumber > 0 ? maxCourseNumber : 1);
  }

  /// PUT /api/orders/:id writable body.
  static Map<String, dynamic> buildOrderUpdatePayload(
    Map<String, dynamic> orderDetail, {
    bool keepOpenWhenEmpty = false,
  }) {
    final seatOrders = orderDetail['seat_orders'];
    final payload = <String, dynamic>{
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

    // Cancelling the last item must not close the order — only the delete icon
    // should. Ask the API to keep the shell open when nothing visible remains.
    if (keepOpenWhenEmpty && orderDetailHasNoVisibleItems(orderDetail)) {
      payload['status'] = preserveOpenOrderStatus(orderDetail);
    }

    return payload;
  }

  /// PUT payload that only changes couverts / number_of_guests.
  static Map<String, dynamic> buildUpdateGuestCountPayload(
    Map<String, dynamic> orderDetail, {
    required int numberOfGuests,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    working['number_of_guests'] = numberOfGuests < 1 ? 1 : numberOfGuests;
    return buildOrderUpdatePayload(working);
  }

  static int quantityForSimpleProduct(
    Map<String, dynamic> orderDetail,
    int productId,
  ) {
    final item = findSimpleItemByProductId(orderDetail, productId);
    if (item == null) return 0;
    return (item['qty'] as num?)?.toInt() ?? 0;
  }

  static Map<String, dynamic>? findSimpleItemByProductId(
    Map<String, dynamic> orderDetail,
    int productId,
  ) {
    final seatOrders = orderDetail['seat_orders'];
    if (seatOrders is! List) return null;

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
          if (item['status'] == 'cancelled') continue;
          if (!_isSimpleLineItem(item)) continue;
          if (_itemProductId(item) == productId) return item;
        }
      }
    }

    return null;
  }

  static bool _isSimpleLineItem(Map<String, dynamic> item) {
    final menus = item['menu_selections'];
    if (menus is List && menus.isNotEmpty) return false;
    return item['is_still_menu_missing'] != true;
  }

  static double _itemUnitPrice(Map<String, dynamic> item) {
    final qty = (item['qty'] as num?)?.toInt() ?? 1;
    if (qty <= 0) return 0;
    return _parseMoney(item['sub_total']) / qty;
  }

  static Map<String, dynamic> addOrIncrementSimpleItem({
    required Map<String, dynamic> orderDetail,
    required int productId,
    required double unitPrice,
    int qty = 1,
    String comment = '',
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
  }) {
    return appendSimpleItem(
      orderDetail: orderDetail,
      productId: productId,
      unitPrice: unitPrice,
      qty: qty,
      comment: comment,
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
    );
  }

  static Map<String, dynamic> setLineQuantityAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
    required int qty,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    _mutateVisibleLineAtIndex(working, lineIndex, (item) {
      if (qty <= 0) {
        item['status'] = 'cancelled';
        return;
      }

      final unitPrice = _itemUnitPrice(item);
      item['qty'] = qty;
      item['sub_total'] = unitPrice * qty;
    });
    return buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
  }

  static Map<String, dynamic> adjustSimpleProductQuantity({
    required Map<String, dynamic> orderDetail,
    required int productId,
    required int delta,
    required double unitPrice,
  }) {
    final currentQty = quantityForSimpleProduct(orderDetail, productId);
    final existing = findSimpleItemByProductId(orderDetail, productId);
    final resolvedUnitPrice = existing != null
        ? (_itemUnitPrice(existing) > 0
            ? _itemUnitPrice(existing)
            : unitPrice)
        : unitPrice;

    return setSimpleProductQuantity(
      orderDetail: orderDetail,
      productId: productId,
      qty: currentQty + delta,
      unitPrice: resolvedUnitPrice,
    );
  }

  static Map<String, dynamic> setSimpleProductQuantity({
    required Map<String, dynamic> orderDetail,
    required int productId,
    required int qty,
    required double unitPrice,
  }) {
    if (qty <= 0) {
      return removeSimpleProductFromOrder(
        orderDetail: orderDetail,
        productId: productId,
      );
    }

    final working = Map<String, dynamic>.from(orderDetail);
    var updated = false;

    _mutateSimpleProductLines(
      working,
      productId: productId,
      onMatch: (item) {
        item['qty'] = qty;
        item['sub_total'] = unitPrice * qty;
        updated = true;
      },
    );

    if (updated) {
      return buildOrderUpdatePayload(working);
    }

    return appendSimpleItem(
      orderDetail: orderDetail,
      productId: productId,
      unitPrice: unitPrice,
      qty: qty,
    );
  }

  static List<int> productLineIndicesForSection(
    List<OrderDisplayEntry> entries,
    int sectionIndex,
  ) {
    return productLineIndicesForSuivreSection(entries, sectionIndex);
  }

  /// Product line indices displayed below a section divider.
  static List<int> productLineIndicesForSuivreSection(
    List<OrderDisplayEntry> entries,
    int suivreSectionIndex,
  ) {
    final dividerIndex = entries.indexWhere(
      (entry) =>
          entry.isSectionDivider && entry.sectionIndex == suivreSectionIndex,
    );
    if (dividerIndex < 0) return const [];

    final indices = <int>[];
    for (var i = dividerIndex + 1; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.isSectionDivider) break;
      if (entry.type == OrderDisplayEntryType.product &&
          entry.lineIndex != null) {
        indices.add(entry.lineIndex!);
      }
    }
    return indices;
  }

  static List<OrderDisplayEntry> removeSuivreSectionFromDisplay(
    List<OrderDisplayEntry> entries,
    int sectionIndex,
  ) {
    final dividerIndex = entries.indexWhere(
      (entry) =>
          entry.isSectionDivider && entry.sectionIndex == sectionIndex,
    );
    if (dividerIndex < 0) return entries;

    final result = entries.toList();
    result.removeAt(dividerIndex);
    while (dividerIndex < result.length && !result[dividerIndex].isSectionDivider) {
      result.removeAt(dividerIndex);
    }
    return result;
  }

  /// Rebuilds display rows using a trimmed suivre layout and fresh API products.
  static List<OrderDisplayEntry> applyTrimmedSuivreLayout({
    required List<OrderProduct> products,
    required List<OrderDisplayEntry> trimmedLayout,
  }) {
    if (products.isEmpty) return const [];

    final splits = suivreSplitPositions(trimmedLayout);
    if (splits.isEmpty) {
      return [
        for (var i = 0; i < products.length; i++)
          OrderDisplayEntry.product(
            product: products[i],
            lineIndex: i,
            sectionIndex: 0,
          ),
      ];
    }

    final flatProducts = [
      for (var i = 0; i < products.length; i++)
        OrderDisplayEntry.product(
          product: products[i],
          lineIndex: i,
          sectionIndex: 0,
        ),
    ];

    final validSplits = splits
        .where((splitAt) => splitAt > 0 && splitAt <= products.length)
        .toList();
    if (validSplits.isEmpty) {
      return flatProducts;
    }

    return _rebuildEntriesWithSuivreSplits(flatProducts, validSplits);
  }

  /// Cancels every visible line (used to clear auto-added create defaults).
  static const emptyCreateSeedCancelReason =
      'Commande vide — article automatique annulé';

  /// True when the ticket still has ONLY the empty-create seed line(s).
  static bool hasOnlyEmptyCreateSeed(
    Map<String, dynamic> orderDetail, {
    int? seedProductId,
  }) {
    if (orderDetailHasNoVisibleItems(orderDetail)) return false;

    if (seedProductId != null && seedProductId > 0) {
      final seatOrders = orderDetail['seat_orders'];
      if (seatOrders is! List) return false;
      var sawSeed = false;
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
            if (item['status'] == 'cancelled') continue;
            if (_itemProductId(item) != seedProductId) return false;
            sawSeed = true;
          }
        }
      }
      return sawSeed;
    }

    // Fallback: single free simple line left from create seed.
    if (countVisibleLineItems(orderDetail) != 1) return false;
    final item = firstVisibleItem(orderDetail);
    if (item == null) return false;
    if (!_isSimpleLineItem(item)) return false;
    return _parseMoney(item['sub_total']) <= 0.0001;
  }

  /// True when a leftover create-seed line is still present (possibly with others).
  static bool hasLeftoverEmptyCreateSeed(
    Map<String, dynamic> orderDetail, {
    int? seedProductId,
  }) {
    if (seedProductId != null && seedProductId > 0) {
      return containsVisibleProductId(orderDetail, seedProductId);
    }
    return hasOnlyEmptyCreateSeed(orderDetail);
  }

  static bool containsVisibleProductId(
    Map<String, dynamic> orderDetail,
    int productId,
  ) {
    final seatOrders = orderDetail['seat_orders'];
    if (seatOrders is! List) return false;

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
          if (item['status'] == 'cancelled') continue;
          if (_itemProductId(item) == productId) return true;
        }
      }
    }
    return false;
  }

  static Map<String, dynamic>? firstVisibleItem(Map<String, dynamic> orderDetail) {
    final seatOrders = orderDetail['seat_orders'];
    if (seatOrders is! List) return null;

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
          if (item['status'] == 'cancelled') continue;
          return item;
        }
      }
    }
    return null;
  }

  /// Deep copy with every course `items` cleared (keeps course/seat ids for PUT).
  static Map<String, dynamic> withAllCourseItemsCleared(
    Map<String, dynamic> orderDetail,
  ) {
    final working = _deepCopyOrderMap(orderDetail);
    final seatOrders = working['seat_orders'];
    if (seatOrders is! List) return working;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        course['items'] = <dynamic>[];
      }
    }
    return working;
  }

  /// Removes visible lines for [productId] (create-seed cleanup).
  static Map<String, dynamic> withoutVisibleProduct(
    Map<String, dynamic> orderDetail,
    int productId,
  ) {
    final working = _deepCopyOrderMap(orderDetail);
    final seatOrders = working['seat_orders'];
    if (seatOrders is! List) return working;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final items = course['items'];
        if (items is! List) continue;
        course['items'] = items.where((item) {
          if (item is! Map<String, dynamic>) return true;
          if (item['status'] == 'cancelled') return true;
          return _itemProductId(item) != productId;
        }).toList();
      }
    }
    return working;
  }

  static Map<String, dynamic> cancelAllVisibleItems(
    Map<String, dynamic> orderDetail, {
    String cancelReason = emptyCreateSeedCancelReason,
  }) {
    final working = _deepCopyOrderMap(orderDetail);
    final seatOrders = working['seat_orders'];
    if (seatOrders is! List) {
      return buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
    }

    final now = DateTime.now().toUtc().toIso8601String();
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
          if (item['status'] == 'cancelled') continue;
          item['status'] = 'cancelled';
          item['cancel_reason'] = cancelReason;
          item['canceled_datetime'] = now;
          item['cancelled_at'] = now;
        }
      }
    }

    final payload = buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
    payload['status'] = 'open';
    payload['payment_status'] = 'not_paid';
    payload['payment_status_detailed'] = 'not_paid';
    return payload;
  }

  /// Removes all line items from seat courses (stronger empty-order clear).
  static Map<String, dynamic> stripAllVisibleItems(
    Map<String, dynamic> orderDetail,
  ) {
    final working = withAllCourseItemsCleared(orderDetail);
    final payload = buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
    payload['status'] = 'open';
    payload['payment_status'] = 'not_paid';
    payload['payment_status_detailed'] = 'not_paid';
    return payload;
  }

  static Map<String, dynamic> _deepCopyOrderMap(Map<String, dynamic> source) {
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }

  static Map<String, dynamic> cancelOrderLinesAtIndices({
    required Map<String, dynamic> orderDetail,
    required Set<int> lineIndices,
  }) {
    if (lineIndices.isEmpty) {
      return buildOrderUpdatePayload(orderDetail);
    }

    final working = Map<String, dynamic>.from(orderDetail);
    var currentIndex = 0;

    final seatOrders = working['seat_orders'];
    if (seatOrders is! List) {
      return buildOrderUpdatePayload(working);
    }

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = _sortedCoursesList(seat['courses']);

      for (final course in courses) {
        final items = course['items'];
        if (items is! List) continue;

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          if (item['status'] == 'cancelled') continue;

          if (lineIndices.contains(currentIndex)) {
            item['status'] = 'cancelled';
          }
          currentIndex++;
        }
      }
    }

    return buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
  }

  static Map<String, dynamic> cancelOrderLineAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    var currentIndex = 0;
    var cancelled = false;

    final seatOrders = working['seat_orders'];
    if (seatOrders is! List) {
      return buildOrderUpdatePayload(working);
    }

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = _sortedCoursesList(seat['courses']);

      for (final course in courses) {
        final items = course['items'];
        if (items is! List) continue;

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          if (item['status'] == 'cancelled') continue;

          if (currentIndex == lineIndex) {
            item['status'] = 'cancelled';
            cancelled = true;
            break;
          }
          currentIndex++;
        }
        if (cancelled) break;
      }
      if (cancelled) break;
    }

    return buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
  }

  static Map<String, dynamic> adjustLineQuantityAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
    required int delta,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    _mutateVisibleLineAtIndex(working, lineIndex, (item) {
      final currentQty = (item['qty'] as num?)?.toInt() ?? 1;
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        item['status'] = 'cancelled';
        return;
      }
      final unitPrice = _itemUnitPrice(item);
      item['qty'] = newQty;
      item['sub_total'] = unitPrice * newQty;
    });
    return buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
  }

  static Map<String, dynamic> applyOfferAtLineIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    _mutateVisibleLineAtIndex(working, lineIndex, (item) {
      item['is_offer'] = true;
      item['offer_reason'] = 'Article offert';
      item['offer_datetime'] = DateTime.now().toUtc().toIso8601String();
      item['sub_total'] = '0.00';
    });
    return buildOrderUpdatePayload(working);
  }

  static bool _mutateVisibleLineAtIndex(
    Map<String, dynamic> orderDetail,
    int lineIndex,
    void Function(Map<String, dynamic> item) mutate,
  ) {
    var currentIndex = 0;
    final seatOrders = orderDetail['seat_orders'];
    if (seatOrders is! List) return false;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = _sortedCoursesList(seat['courses']);

      for (final course in courses) {
        final items = course['items'];
        if (items is! List) continue;

        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          if (item['status'] == 'cancelled') continue;

          if (currentIndex == lineIndex) {
            mutate(item);
            return true;
          }
          currentIndex++;
        }
      }
    }

    return false;
  }

  static double parseOrderPayableAmount(Map<String, dynamic> data) {
    final order = unwrapOrderDetail(data);
    final remaining = order['remaining_amount'];
    if (remaining is num && remaining > 0) return remaining.toDouble();
    if (remaining is String) {
      final parsed =
          double.tryParse(remaining.replaceAll(',', '.').replaceAll('€', '').trim());
      if (parsed != null && parsed > 0) return parsed;
    }

    return parseOrderTotalAmount(data);
  }

  static double formatPaymentAmount(double amount) =>
      double.parse(amount.toStringAsFixed(2));

  static String formatPaymentAmountDisplay(double amount) {
    final formatted = amount.toStringAsFixed(2).replaceAll('.', ',');
    return '$formatted €';
  }

  static double parseOrderTotalAmount(Map<String, dynamic> data) {
    final order = unwrapOrderDetail(data);
    final raw = order['total_price'] ??
        order['remaining_amount'] ??
        order['total'] ??
        data['total_price'];
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(raw.replaceAll(',', '.').replaceAll('€', '').trim()) ??
          0;
    }
    return 0;
  }

  static List<Map<String, dynamic>> extractPaymentModes(dynamic payload) {
    final raw = <Map<String, dynamic>>[];

    void collect(dynamic data) {
      if (data == null) return;

      if (data is List) {
        for (final entry in data) {
          if (entry is Map<String, dynamic>) {
            raw.add(entry);
          } else if (entry is Map) {
            raw.add(Map<String, dynamic>.from(entry));
          }
        }
        return;
      }

      if (data is! Map) return;
      final map = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data);

      if (_looksLikePaymentMode(map)) {
        raw.add(map);
        return;
      }

      for (final key in [
        'data',
        'payment_modes',
        'modes',
        'items',
        'paymentModes',
        'active_modes',
        'active',
        'results',
      ]) {
        if (!map.containsKey(key)) continue;
        collect(map[key]);
      }

      for (final entry in map.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final child = value is Map<String, dynamic>
            ? value
            : Map<String, dynamic>.from(value);
        if (_looksLikePaymentMode(child)) {
          raw.add({
            ...child,
            if (child['code'] == null) 'code': entry.key.toString(),
          });
        }
      }
    }

    if (payload is Map<String, dynamic> &&
        payload.containsKey('success') &&
        payload.containsKey('data')) {
      try {
        final envelope = payload;
        if (envelope['success'] == true) {
          collect(envelope['data']);
        }
        if (raw.isEmpty) {
          collect(payload);
        }
      } catch (_) {
        collect(payload);
      }
    } else {
      collect(payload);
    }

    final normalized = raw
        .map(normalizePaymentMode)
        .where((mode) => paymentModeId(mode) != null)
        .toList();

    final seen = <int>{};
    return normalized.where((mode) {
      final id = paymentModeId(mode);
      if (id == null || seen.contains(id)) return false;
      seen.add(id);
      return true;
    }).toList();
  }

  static List<Map<String, dynamic>> parsePaymentModesList(dynamic data) =>
      extractPaymentModes(data);

  static bool _looksLikePaymentMode(Map<String, dynamic> map) {
    if (map.containsKey('payment_mode')) return true;
    if (map.containsKey('payment_mode_id')) return true;
    if (map.containsKey('id') &&
        (map.containsKey('name') ||
            map.containsKey('label') ||
            map.containsKey('code') ||
            map.containsKey('type'))) {
      return true;
    }
    return false;
  }

  static Map<String, dynamic> normalizePaymentMode(Map<String, dynamic> raw) {
    final nested = raw['payment_mode'];
    if (nested is Map) {
      final mode = nested is Map<String, dynamic>
          ? nested
          : Map<String, dynamic>.from(nested);
      return {
        ...mode,
        'id': paymentModeId(mode) ?? paymentModeId(raw),
        'name': mode['name'] ?? raw['name'] ?? mode['label'] ?? raw['label'],
        'code': mode['code'] ?? raw['code'],
        'type': mode['type'] ?? raw['type'],
        'is_cash': mode['is_cash'] ?? raw['is_cash'],
        'is_active': mode['is_active'] ?? raw['is_active'],
        'active': mode['active'] ?? raw['active'],
      };
    }

    return {
      ...raw,
      'id': paymentModeId(raw),
    };
  }

  static int? paymentModeId(Map<String, dynamic> mode) {
    final id = mode['id'] ?? mode['payment_mode_id'];
    if (id is num) return id.toInt();
    if (id is String) return int.tryParse(id);
    return null;
  }

  static List<Map<String, dynamic>> paymentModesFromSettings(
    Map<String, dynamic> settings,
  ) {
    final modes = <Map<String, dynamic>>[];
    final cashId = settings['default_cash_payment_mode_id'];
    if (cashId is num) {
      modes.add({
        'id': cashId.toInt(),
        'name': 'Espèces',
        'code': 'cash',
        'is_cash': true,
        'is_active': true,
      });
    }

    final cardId = settings['default_card_payment_mode_id'] ??
        settings['default_credit_payment_mode_id'];
    if (cardId is num) {
      modes.add({
        'id': cardId.toInt(),
        'name': 'Carte',
        'code': 'card',
        'is_cash': false,
        'is_active': true,
      });
    }

    return modes;
  }

  static List<Map<String, dynamic>> activePaymentModes(
    List<Map<String, dynamic>> modes,
  ) {
    return modes.where((mode) {
      final status = mode['status']?.toString().toLowerCase();
      if (status == 'inactive' || status == 'disabled') return false;

      final isActive = mode['is_active'] ?? mode['active'];
      if (isActive == false || isActive == 0 || isActive == '0') return false;
      return true;
    }).toList();
  }

  static int? resolvePaymentModeId(
    List<Map<String, dynamic>> modes, {
    required bool isCash,
  }) {
    final active = activePaymentModes(modes);
    final candidates = active.isEmpty ? modes : active;
    if (candidates.isEmpty) return null;

    for (final mode in candidates) {
      final id = paymentModeId(mode);
      if (id == null) continue;

      if (mode['is_cash'] == true && isCash) return id;
      if (mode['is_cash'] == false && !isCash) return id;

      final label = [
        mode['name'],
        mode['code'],
        mode['label'],
        mode['type'],
        mode['slug'],
        if (mode['payment_mode'] is Map<String, dynamic>)
          ...(mode['payment_mode'] as Map<String, dynamic>).values
              .whereType<String>(),
      ].whereType<String>().join(' ').toLowerCase();

      final matchesCash = label.contains('esp') ||
          label.contains('espece') ||
          label.contains('espèce') ||
          label.contains('especes') ||
          label.contains('cash') ||
          label.contains('liquide');
      final matchesCard = label.contains('carte') ||
          label.contains('card') ||
          label.contains('credit') ||
          label.contains('crédit') ||
          label.contains('cb') ||
          label.contains('tpe');

      final type = mode['type']?.toString().toLowerCase() ?? '';
      final code = mode['code']?.toString().toLowerCase() ?? '';

      if (isCash &&
          (matchesCash || type == 'cash' || code == 'cash' || code == 'espece')) {
        return id;
      }
      if (!isCash &&
          (matchesCard ||
              type == 'card' ||
              type == 'credit' ||
              code == 'card' ||
              code == 'credit')) {
        return id;
      }
    }

    if (candidates.length == 1) {
      return paymentModeId(candidates.first);
    }

    final firstId = paymentModeId(candidates.first);
    final lastId = paymentModeId(candidates.last);
    return isCash ? firstId : lastId;
  }

  static Map<String, dynamic> removeSimpleProductFromOrder({
    required Map<String, dynamic> orderDetail,
    required int productId,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    _mutateSimpleProductLines(
      working,
      productId: productId,
      onMatch: (item) {
        item['status'] = 'cancelled';
      },
    );
    return buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
  }

  static void _mutateSimpleProductLines(
    Map<String, dynamic> orderDetail, {
    required int productId,
    required void Function(Map<String, dynamic> item) onMatch,
  }) {
    final seatOrders = orderDetail['seat_orders'];
    if (seatOrders is! List) return;

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
          if (item['status'] == 'cancelled') continue;
          if (!_isSimpleLineItem(item)) continue;
          if (_itemProductId(item) != productId) continue;
          onMatch(item);
          return;
        }
      }
    }
  }

  static String _resolveAppendItemStatus(
    Map<String, dynamic> detail, {
    required int seatNumber,
    required int courseNumber,
  }) {
    final seatOrders = detail['seat_orders'];
    if (seatOrders is List) {
      for (final seat in seatOrders) {
        if (seat is! Map<String, dynamic>) continue;
        if ((seat['seat_number'] as num?)?.toInt() != seatNumber) continue;

        final courses = seat['courses'];
        if (courses is! List || courses.isEmpty) continue;

        var firstCourseNumber = 1;
        for (final course in courses) {
          if (course is! Map<String, dynamic>) continue;
          final cn = (course['course_number'] as num?)?.toInt();
          if (cn != null) {
            firstCourseNumber = cn;
            break;
          }
        }

        if (courseNumber > firstCourseNumber) {
          return 'to_be_continued';
        }
      }
    }

    return _resolveItemStatusForCourse(
      detail,
      seatNumber: seatNumber,
      courseNumber: courseNumber,
    );
  }

  static Map<String, dynamic> appendSimpleItem({
    required Map<String, dynamic> orderDetail,
    required int productId,
    required double unitPrice,
    int qty = 1,
    String comment = '',
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final course = resolveAppendCourse(
      working,
      seatNumber: seatNumber,
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
    );
    final itemStatus = _resolveAppendItemStatus(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
    );

    final newItem = _buildNewItemPayload(
      seatNumber: seatNumber,
      courseId: course.id,
      productId: productId,
      qty: qty,
      subTotal: unitPrice * qty,
      status: itemStatus,
      comment: comment,
      forCreate: false,
    );

    _appendItemToSeatOrders(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
      newItem: newItem,
    );

    return buildOrderUpdatePayload(working);
  }

  static Map<String, dynamic> appendComposedItem({
    required Map<String, dynamic> orderDetail,
    required int productId,
    required double subTotal,
    required List<Map<String, dynamic>> menuSelections,
    String comment = '',
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final course = resolveAppendCourse(
      working,
      seatNumber: seatNumber,
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
    );
    final itemStatus = _resolveAppendItemStatus(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
    );

    final newItem = _buildNewItemPayload(
      seatNumber: seatNumber,
      courseId: course.id,
      productId: productId,
      qty: 1,
      subTotal: subTotal,
      status: itemStatus,
      comment: comment,
      menuSelections: menuSelections,
      isStillMenuMissing: false,
      forCreate: false,
    );

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
              'id': 0,
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
          var hasTargetCourse = false;
          for (final course in courses) {
            if (course is! Map<String, dynamic>) continue;
            if ((course['course_number'] as num?)?.toInt() == courseNumber) {
              hasTargetCourse = true;
              break;
            }
          }
          if (!hasTargetCourse) {
            final courseList = courses.whereType<Map<String, dynamic>>().toList();
            courseList.add({
              'id': 0,
              'course_number': courseNumber,
              'seat_number': seatNumber,
              'items': [newItem],
            });
            seatCopy['courses'] = courseList;
            itemAdded = true;
          } else {
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
          }
        } else {
          seatCopy['courses'] = [
            {
              'id': 0,
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
            'id': 0,
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
    if (seatOrders is! List) return 'to_be_continued';

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

    return 'to_be_continued';
  }

  /// API-storable menu selection fields only (Orders API).
  static List<Map<String, dynamic>> sanitizeMenuSelectionsForWrite(
    List<Map<String, dynamic>> selections,
  ) {
    return [
      for (final selection in selections)
        {
          'menu_category_id': selection['menu_category_id'],
          'selected_product_id': selection['selected_product_id'],
          'price': _parseMoney(selection['price']),
        },
    ];
  }

  static List<Map<String, dynamic>> _menuSelectionsWithDisplayNames(
    List<Map<String, dynamic>> selections,
  ) {
    final sanitized = sanitizeMenuSelectionsForWrite(selections);
    return [
      for (var i = 0; i < sanitized.length; i++)
        {
          ...sanitized[i],
          if (i < selections.length)
            ..._menuSelectionDisplayFields(selections[i]),
        },
    ];
  }

  static Map<String, dynamic> _menuSelectionDisplayFields(
    Map<String, dynamic> selection,
  ) {
    final fields = <String, dynamic>{};
    final productName = selection['selected_product_name'];
    if (productName is String && productName.trim().isNotEmpty) {
      fields['selected_product_name'] = productName.trim();
    }
    final categoryName = selection['menu_category_name'];
    if (categoryName is String && categoryName.trim().isNotEmpty) {
      fields['menu_category_name'] = categoryName.trim();
    }
    return fields;
  }

  static List<String> menuSelectionLabelsFromMaps(
    List<Map<String, dynamic>> selections,
  ) {
    final labels = <String>[];
    for (final selection in selections) {
      final name = _menuSelectionLabel(selection);
      if (name != null) labels.add(name);
    }
    return labels;
  }

  static List<String> menuSelectionLabelsFromItem(Map<String, dynamic> item) {
    final menus = item['menu_selections'];
    if (menus is! List || menus.isEmpty) return const [];
    return menuSelectionLabelsFromMaps(
      menus.whereType<Map<String, dynamic>>().toList(),
    );
  }

  static String? _menuSelectionLabel(Map<String, dynamic> selection) {
    for (final key in ['selected_product_name', 'name', 'label']) {
      final raw = selection[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim().toUpperCase();
      }
    }

    for (final nestedKey in ['selected_product', 'product']) {
      final nested = selection[nestedKey];
      if (nested is Map<String, dynamic>) {
        final name = nested['name'];
        if (name is String && name.trim().isNotEmpty) {
          return name.trim().toUpperCase();
        }
      }
    }

    return null;
  }

  static OrderProduct orderProductFromItem(Map<String, dynamic> item) {
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

    return OrderProduct(
      quantity: '$qty',
      name: name,
      price: isOffer ? '0,00 €' : formatPrice(subTotal),
      message: message,
      menuItems: menuSelectionLabelsFromItem(item),
    );
  }

  static Map<String, dynamic> _sanitizeSeatOrderForUpdate(
    Map<String, dynamic> seat,
  ) {
    final copy = Map<String, dynamic>.from(seat);
    final courses = seat['courses'];
    copy['courses'] = courses is List
        ? courses
            .whereType<Map<String, dynamic>>()
            .map(_sanitizeCourseForUpdate)
            .toList()
        : <dynamic>[];
    return copy;
  }

  static Map<String, dynamic> _sanitizeCourseForUpdate(
    Map<String, dynamic> course,
  ) {
    final copy = Map<String, dynamic>.from(course);
    final courseId = (course['id'] as num?)?.toInt();
    // New courses use id: 0 (PUT full state).
    if (courseId == null || courseId <= 0) {
      copy['id'] = 0;
    }
    final items = course['items'];
    copy['items'] = items is List
        ? items
            .whereType<Map<String, dynamic>>()
            .map(_sanitizeItemForUpdate)
            .toList()
        : <dynamic>[];
    return copy;
  }

  /// Existing lines keep server fields; new lines use [id: 0] and a client [uid].
  static Map<String, dynamic> _sanitizeItemForUpdate(Map<String, dynamic> item) {
    final itemId = (item['id'] as num?)?.toInt();
    if (itemId != null && itemId > 0) {
      final copy = Map<String, dynamic>.from(item);
      _ensureItemProductObject(copy);
      return copy;
    }

    final existingUid = item['uid'];
    return _buildNewItemPayload(
      seatNumber: (item['seat_number'] as num?)?.toInt() ?? 1,
      courseId: (item['course_id'] as num?)?.toInt(),
      productId: _itemProductId(item),
      qty: (item['qty'] as num?)?.toInt() ?? 1,
      subTotal: _parseMoney(item['sub_total']),
      status: item['status'] as String? ?? 'to_be_continued',
      comment: item['comment'] as String? ?? '',
      menuSelections: item['menu_selections'] is List
          ? (item['menu_selections'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : const [],
      isStillMenuMissing: item['is_still_menu_missing'] == true,
      forCreate: false,
      uid: existingUid is String && existingUid.isNotEmpty ? existingUid : null,
    );
  }

  static Map<String, dynamic> _buildNewItemPayload({
    required int seatNumber,
    required int? courseId,
    required int productId,
    required int qty,
    required double subTotal,
    required String status,
    required String comment,
    List<Map<String, dynamic>> menuSelections = const [],
    bool isStillMenuMissing = false,
    bool forCreate = false,
    String? uid,
  }) {
    final sanitizedMenus = _menuSelectionsWithDisplayNames(menuSelections);

    return {
      'id': 0,
      'uid': uid ?? generateOrderItemUid(),
      'seat_number': seatNumber,
      'course_id': forCreate ? 0 : (courseId ?? 0),
      'product': {'id': productId},
      'sub_total': subTotal,
      'qty': qty,
      'comment': comment,
      'status': status,
      'is_loss': false,
      'menu_selections': sanitizedMenus,
      'is_still_menu_missing': isStillMenuMissing,
    };
  }

  static int _itemProductId(Map<String, dynamic> item) {
    final direct = (item['product_id'] as num?)?.toInt();
    if (direct != null) return direct;
    final product = item['product'];
    if (product is Map<String, dynamic>) {
      return (product['id'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static void _ensureItemProductObject(Map<String, dynamic> item) {
    final productId = _itemProductId(item);
    if (productId <= 0) return;

    final product = item['product'];
    if (product is Map<String, dynamic>) {
      item['product'] = Map<String, dynamic>.from(product)
        ..putIfAbsent('id', () => productId);
    } else {
      item['product'] = {'id': productId};
    }
  }

  static double _parseMoney(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  // ── Optimistic UI predictions (Phase 1) ─────────────────────────────────

  static SessionOrder predictAfterAppendSimpleProduct({
    required SessionOrder current,
    Map<String, dynamic>? cachedDetail,
    required int productId,
    required String productName,
    required double unitPrice,
    int qty = 1,
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
  }) {
    final layoutHints = current.displayEntries;
    final detail = _cachedDetailAlignedWithSession(cachedDetail, current);
    if (detail != null) {
      final simulated = simulateDetailAfterAppendSimpleItem(
        orderDetail: detail,
        productId: productId,
        productName: productName,
        unitPrice: unitPrice,
        qty: qty,
        suivreSectionCount: suivreSectionCount,
        suivreSplitHints: suivreSplitHints,
        layoutHints: layoutHints,
      );
      return fromOrderDetail(
        simulated,
        previousDisplayEntries: layoutHints,
        suivreSplitHints: suivreSplitHints,
        suivreCountHint: suivreSectionCount,
      );
    }

    return _predictAppendOnSessionOrder(
      current: current,
      productName: productName,
      unitPrice: unitPrice,
      qty: qty,
    );
  }

  static double _menuSelectionsSupplement(
    List<Map<String, dynamic>> menuSelections,
  ) {
    return menuSelections.fold<double>(
      0,
      (sum, selection) {
        final price = selection['price'];
        if (price is num) return sum + price.toDouble();
        return sum +
            (double.tryParse(price?.toString().replaceAll(',', '.') ?? '') ??
                0);
      },
    );
  }

  static SessionOrder predictAfterAppendComposedProduct({
    required SessionOrder current,
    Map<String, dynamic>? cachedDetail,
    required int productId,
    required String productName,
    required double basePrice,
    required List<Map<String, dynamic>> menuSelections,
    String comment = '',
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final effectiveLayout = layoutHints ?? current.displayEntries;
    final workingCurrent = layoutHints != null
        ? current.copyWith(displayEntries: layoutHints)
        : current;
    final subTotal = basePrice + _menuSelectionsSupplement(menuSelections);
    final detail = _cachedDetailAlignedWithSession(cachedDetail, workingCurrent);
    if (detail != null) {
      final simulated = simulateDetailAfterAppendComposedItem(
        orderDetail: detail,
        productId: productId,
        productName: productName,
        subTotal: subTotal,
        menuSelections: menuSelections,
        comment: comment,
        suivreSectionCount: suivreSectionCount,
        suivreSplitHints: suivreSplitHints,
        layoutHints: effectiveLayout,
      );
      return fromOrderDetail(
        simulated,
        previousDisplayEntries: effectiveLayout,
        suivreSplitHints: suivreSplitHints,
        suivreCountHint: suivreSectionCount,
      );
    }

    return _predictAppendOnSessionOrder(
      current: workingCurrent,
      productName: productName,
      unitPrice: subTotal,
      qty: 1,
      menuItems: menuSelectionLabelsFromMaps(menuSelections),
    );
  }

  static SessionOrder predictAfterCancelLineAtIndex(
    SessionOrder current,
    int lineIndex,
  ) {
    return _predictRemoveLineOnSessionOrder(current, lineIndex);
  }

  static SessionOrder predictAfterAdjustLineQuantityAtIndex({
    required SessionOrder current,
    required int lineIndex,
    required int delta,
  }) {
    return _predictAdjustLineQuantityOnSessionOrder(
      current,
      lineIndex,
      delta,
    );
  }

  static SessionOrder predictAfterSetLineQuantityAtIndex({
    required SessionOrder current,
    required int lineIndex,
    required int qty,
  }) {
    return _predictSetLineQuantityOnSessionOrder(
      current,
      lineIndex,
      qty,
    );
  }

  static Map<String, dynamic>? _cachedDetailAlignedWithSession(
    Map<String, dynamic>? cachedDetail,
    SessionOrder current,
  ) {
    if (cachedDetail == null) return null;
    if (extractProducts(cachedDetail).length != current.products.length) {
      return null;
    }
    return cachedDetail;
  }

  static Map<String, dynamic> simulateDetailAfterAppendSimpleItem({
    required Map<String, dynamic> orderDetail,
    required int productId,
    required String productName,
    required double unitPrice,
    int qty = 1,
    String comment = '',
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final course = resolveAppendCourse(
      working,
      seatNumber: seatNumber,
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
    );
    final itemStatus = _resolveAppendItemStatus(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
    );

    final newItem = _buildNewItemPayload(
      seatNumber: seatNumber,
      courseId: course.id,
      productId: productId,
      qty: qty,
      subTotal: unitPrice * qty,
      status: itemStatus,
      comment: comment,
      forCreate: false,
    );
    if (productName.isNotEmpty) {
      newItem['product'] = {'id': productId, 'name': productName};
    }

    _appendItemToSeatOrders(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
      newItem: newItem,
    );
    _recomputeDetailTotals(working);
    return working;
  }

  static Map<String, dynamic> simulateDetailAfterAppendComposedItem({
    required Map<String, dynamic> orderDetail,
    required int productId,
    required String productName,
    required double subTotal,
    required List<Map<String, dynamic>> menuSelections,
    String comment = '',
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final course = resolveAppendCourse(
      working,
      seatNumber: seatNumber,
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
    );
    final itemStatus = _resolveAppendItemStatus(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
    );

    final newItem = _buildNewItemPayload(
      seatNumber: seatNumber,
      courseId: course.id,
      productId: productId,
      qty: 1,
      subTotal: subTotal,
      status: itemStatus,
      comment: comment,
      menuSelections: menuSelections,
      isStillMenuMissing: false,
      forCreate: false,
    );
    if (productName.isNotEmpty) {
      newItem['product'] = {'id': productId, 'name': productName};
    }

    _appendItemToSeatOrders(
      working,
      seatNumber: seatNumber,
      courseNumber: course.number,
      newItem: newItem,
    );
    _recomputeDetailTotals(working);
    return working;
  }

  static Map<String, dynamic> simulateDetailAfterAdjustLineQuantityAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
    required int delta,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    _mutateVisibleLineAtIndex(working, lineIndex, (item) {
      final currentQty = (item['qty'] as num?)?.toInt() ?? 1;
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        item['status'] = 'cancelled';
        return;
      }
      final unitPrice = _itemUnitPrice(item);
      item['qty'] = newQty;
      item['sub_total'] = unitPrice * newQty;
    });
    _recomputeDetailTotals(working);
    return working;
  }

  static Map<String, dynamic> simulateDetailAfterSetLineQuantityAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
    required int qty,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    _mutateVisibleLineAtIndex(working, lineIndex, (item) {
      if (qty <= 0) {
        item['status'] = 'cancelled';
        return;
      }
      final unitPrice = _itemUnitPrice(item);
      item['qty'] = qty;
      item['sub_total'] = unitPrice * qty;
    });
    _recomputeDetailTotals(working);
    return working;
  }

  static void _recomputeDetailTotals(Map<String, dynamic> orderDetail) {
    var sum = 0.0;
    final seatOrders = orderDetail['seat_orders'];
    if (seatOrders is List) {
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
            if (item['status'] == 'cancelled') continue;
            if (item['is_offer'] == true) continue;
            sum += _parseMoney(item['sub_total']);
          }
        }
      }
    }

    final formatted = sum.toStringAsFixed(2);
    orderDetail['total_price'] = formatted;
    orderDetail['remaining_amount'] = formatted;
  }

  static SessionOrder _predictAppendOnSessionOrder({
    required SessionOrder current,
    required String productName,
    required double unitPrice,
    int qty = 1,
    List<String> menuItems = const [],
  }) {
    final products = List<OrderProduct>.from(current.products);
    final newProduct = OrderProduct(
      quantity: '$qty',
      name: productName,
      price: formatPrice((unitPrice * qty).toStringAsFixed(2)),
      menuItems: menuItems,
    );
    products.add(newProduct);
    final lineIndex = products.length - 1;

    return current.copyWith(
      products: products,
      displayEntries: _appendProductToDisplayEntries(
        current.displayEntries,
        product: newProduct,
        lineIndex: lineIndex,
      ),
      total: _sumFormattedPrices(products),
    );
  }

  static SessionOrder _predictAdjustLineQuantityOnSessionOrder(
    SessionOrder current,
    int lineIndex,
    int delta,
  ) {
    if (lineIndex < 0 || lineIndex >= current.products.length) return current;

    final line = current.products[lineIndex];
    final currentQty = int.tryParse(line.quantity) ?? 1;
    final newQty = currentQty + delta;
    if (newQty <= 0) {
      return _predictRemoveLineOnSessionOrder(current, lineIndex);
    }

    final unitPrice = currentQty > 0
        ? _parseFormattedEuroPrice(line.price) / currentQty
        : 0.0;
    final updatedLine = line.copyWith(
      quantity: '$newQty',
      price: formatPrice((unitPrice * newQty).toStringAsFixed(2)),
    );

    final products = List<OrderProduct>.from(current.products);
    products[lineIndex] = updatedLine;

    return current.copyWith(
      products: products,
      displayEntries: _updateDisplayEntriesForLine(
        current.displayEntries,
        lineIndex: lineIndex,
        product: updatedLine,
      ),
      total: _sumFormattedPrices(products),
    );
  }

  static SessionOrder _predictSetLineQuantityOnSessionOrder(
    SessionOrder current,
    int lineIndex,
    int qty,
  ) {
    if (qty <= 0) {
      return _predictRemoveLineOnSessionOrder(current, lineIndex);
    }
    return _predictAdjustLineQuantityOnSessionOrder(
      current,
      lineIndex,
      qty - (int.tryParse(current.products[lineIndex].quantity) ?? 1),
    );
  }

  static SessionOrder _predictRemoveLineOnSessionOrder(
    SessionOrder current,
    int lineIndex,
  ) {
    if (lineIndex < 0 || lineIndex >= current.products.length) return current;

    final products = List<OrderProduct>.from(current.products)..removeAt(lineIndex);

    return current.copyWith(
      products: products,
      displayEntries: _reindexDisplayEntriesAfterLineRemoval(
        current.displayEntries,
        lineIndex,
      ),
      total: _sumFormattedPrices(products),
    );
  }

  static List<OrderDisplayEntry> _appendProductToDisplayEntries(
    List<OrderDisplayEntry> entries, {
    required OrderProduct product,
    required int lineIndex,
  }) {
    final result = entries.toList();
    var sectionIndex = 0;
    int? courseNumber;

    for (var i = result.length - 1; i >= 0; i--) {
      final entry = result[i];
      if (entry.type == OrderDisplayEntryType.suivreSeparator) {
        sectionIndex = entry.sectionIndex ?? 0;
        courseNumber = (entry.courseNumber ?? 0) + 1;
        break;
      }
      if (entry.type == OrderDisplayEntryType.product && courseNumber == null) {
        sectionIndex = entry.sectionIndex ?? 0;
        courseNumber = entry.courseNumber;
      }
    }

    result.add(
      OrderDisplayEntry.product(
        product: product,
        lineIndex: lineIndex,
        sectionIndex: sectionIndex,
        courseNumber: courseNumber,
      ),
    );
    return result;
  }

  static List<OrderDisplayEntry> _updateDisplayEntriesForLine(
    List<OrderDisplayEntry> entries, {
    required int lineIndex,
    required OrderProduct product,
  }) {
    return [
      for (final entry in entries)
        if (entry.type == OrderDisplayEntryType.product &&
            entry.lineIndex == lineIndex)
          OrderDisplayEntry.product(
            product: product,
            lineIndex: lineIndex,
            sectionIndex: entry.sectionIndex ?? 0,
            courseNumber: entry.courseNumber,
          )
        else
          entry,
    ];
  }

  static List<OrderDisplayEntry> _reindexDisplayEntriesAfterLineRemoval(
    List<OrderDisplayEntry> entries,
    int removedLineIndex,
  ) {
    final result = <OrderDisplayEntry>[];
    for (final entry in entries) {
      if (entry.type == OrderDisplayEntryType.product) {
        final index = entry.lineIndex;
        if (index == null) {
          result.add(entry);
          continue;
        }
        if (index == removedLineIndex) continue;
        if (index > removedLineIndex) {
          result.add(
            OrderDisplayEntry.product(
              product: entry.product!,
              lineIndex: index - 1,
              sectionIndex: entry.sectionIndex ?? 0,
              courseNumber: entry.courseNumber,
            ),
          );
          continue;
        }
      }
      result.add(entry);
    }
    return result;
  }

  static String _sumFormattedPrices(List<OrderProduct> products) {
    var sum = 0.0;
    for (final product in products) {
      sum += _parseFormattedEuroPrice(product.price);
    }
    return formatPrice(sum.toStringAsFixed(2));
  }

  static double _parseFormattedEuroPrice(String price) {
    return double.tryParse(
      price.replaceAll('€', '').replaceAll(',', '.').trim(),
    ) ??
        0;
  }
}
