import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../models/order_display_entry.dart';
import '../../models/order_product.dart';
import '../../models/session_order.dart';
import '../models/local_draft_line.dart';
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

  /// True when [order] is owned by [waiterId], or owner is unknown (list APIs
  /// often omit `waiter_id` — excluding those caused an empty session flash).
  static bool orderBelongsToWaiter(
    Map<String, dynamic> order,
    int waiterId,
  ) {
    if (waiterId <= 0) return true;
    final orderWaiterId = waiterIdFromOrderMap(order);
    if (orderWaiterId == null) return true;
    return orderWaiterId == waiterId;
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

    final products = data.containsKey('seat_orders')
        ? extractProducts(data)
        : const <OrderProduct>[];

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
      products: products,
      itemCount: _itemCountFromListMap(data, products.length),
      displayEntries: const [],
      waiterId: waiterIdFromOrderMap(data),
    );
  }

  static int _itemCountFromListMap(
    Map<String, dynamic> data,
    int productsLength,
  ) {
    for (final key in [
      'items_count',
      'itemsCount',
      'products_count',
      'productsCount',
      'line_items_count',
      'visible_items_count',
      'items_qty',
    ]) {
      final raw = data[key];
      if (raw is num && raw >= 0) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed >= 0) return parsed;
      }
    }
    if (data.containsKey('seat_orders')) {
      return countVisibleLineItems(data);
    }
    return productsLength;
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
  ///
  /// Always clears course [items] so a create-seed leftover never reappears in
  /// UI when this shell is loaded from Hive / enrich.
  static Map<String, dynamic> asOpenEmptyOrderShell(
    Map<String, dynamic> orderDetail,
  ) {
    final copy = withAllCourseItemsCleared(orderDetail);
    ensureMinimalSeatCourseStructure(copy);
    copy['status'] = preserveOpenOrderStatus(orderDetail);
    copy['payment_status'] = 'not_paid';
    copy['payment_status_detailed'] = 'not_paid';
    copy['total_price'] = '0';
    copy['remaining_amount'] = '0';
    copy['total_ht'] = copy['total_ht'] ?? '0';
    copy['total_tva'] = copy['total_tva'] ?? '0';
    copy['total_paid'] = '0';
    return copy;
  }

  /// Guarantees seat 1 / course 1 exist so re-add after delete-all can PUT.
  static void ensureMinimalSeatCourseStructure(Map<String, dynamic> detail) {
    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List || seatOrders.isEmpty) {
      detail['seat_orders'] = [
        {
          'seat_number': 1,
          'courses': [
            {
              'id': 0,
              'course_number': 1,
              'seat_number': 1,
              'items': <dynamic>[],
            },
          ],
        },
      ];
      return;
    }

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is List && courses.isNotEmpty) return;
      seat['courses'] = [
        {
          'id': 0,
          'course_number': 1,
          'seat_number': (seat['seat_number'] as num?)?.toInt() ?? 1,
          'items': <dynamic>[],
        },
      ];
      return;
    }
  }

  /// Session / table-details presentation: hide create-seed-only tickets.
  static SessionOrder sessionOrderHidingCreateSeed(
    Map<String, dynamic> detail, {
    int? seedProductId,
    List<OrderDisplayEntry>? previousDisplayEntries,
    List<int> suivreSplitHints = const [],
    int suivreCountHint = 0,
    Set<int> demandedSectionIndices = const {},
    bool applyKitchenDemande = false,
  }) {
    if (hasOnlyEmptyCreateSeed(detail, seedProductId: seedProductId)) {
      final shell = asOpenEmptyOrderShell(detail);
      final order = fromOrderDetail(
        shell,
        previousDisplayEntries: previousDisplayEntries,
        suivreSplitHints: suivreSplitHints,
        suivreCountHint: suivreCountHint,
        demandedSectionIndices: demandedSectionIndices,
        applyKitchenDemande: applyKitchenDemande,
      );
      return order.copyWith(
        products: const [],
        displayEntries: const [],
        itemCount: 0,
        total: formatPrice('0'),
      );
    }
    return fromOrderDetail(
      detail,
      previousDisplayEntries: previousDisplayEntries,
      suivreSplitHints: suivreSplitHints,
      suivreCountHint: suivreCountHint,
      demandedSectionIndices: demandedSectionIndices,
      applyKitchenDemande: applyKitchenDemande,
    );
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

  /// Skip dialog only when another waiter owns the table (order or session lock).
  ///
  /// Own active order / orphan session must never skip — after cancel the tables
  /// list can still show in-use briefly; the create path reclaims or reopens it.
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

    // Own leftover active_order after delete/close — do not Skip; reclaim below.
    final orderOwner = activeOrderOwnerId(tables, tableNumber);
    if (orderOwner != null && orderOwner == waiterId) {
      return false;
    }

    return isAssignedToOtherWaiter(
      tables,
      tableNumber,
      waiterId: waiterId,
    );
  }

  /// Active order id on [tableNumber] when owned by [waiterId] (or owner unknown).
  static int? ownReusableActiveOrderId(
    List<Map<String, dynamic>> tables,
    String tableNumber, {
    required int waiterId,
  }) {
    if (waiterId <= 0) return null;
    if (isAssignedToOtherWaiter(
      tables,
      tableNumber,
      waiterId: waiterId,
    )) {
      return null;
    }

    final owner = activeOrderOwnerId(tables, tableNumber);
    if (owner != null && owner > 0 && owner != waiterId) return null;

    final resolved = resolveTableForNewOrder(tables, tableNumber);
    final id = resolved?.existingOrderId;
    if (id == null || id <= 0) return null;
    // Known other owner already excluded; null owner + not assigned elsewhere → reuse.
    if (owner == null || owner == waiterId) return id;
    return null;
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
    Set<int> demandedSectionIndices = const {},
    bool applyKitchenDemande = false,
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
      demandedSectionIndices: demandedSectionIndices,
      applyKitchenDemande: applyKitchenDemande,
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
      itemCount: products.length,
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
        for (final item in _visibleItemsInStableAddOrder(course['items'])) {
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
    OrderDisplayEntry? lastDivider;
    var productsUnderLastDivider = false;
    for (final entry in entries) {
      if (entry.isSectionDivider) {
        lastDivider = entry;
        productsUnderLastDivider = false;
      } else if (entry.type == OrderDisplayEntryType.product &&
          lastDivider != null) {
        productsUnderLastDivider = true;
      }
    }

    if (lastDivider != null) {
      final above = lastDivider.courseNumber ?? lastDivider.sectionIndex ?? 1;
      if (productsUnderLastDivider) {
        return above > 0 ? above + 1 : 2;
      }
      return above > 0 ? above : 1;
    }

    return 1;
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

  static bool _sectionHasPendingSuivre(
    List<OrderDisplayEntry> entries,
    int sectionIndex,
  ) {
    for (final entry in entries) {
      if (entry.type == OrderDisplayEntryType.suivreSeparator &&
          entry.sectionIndex == sectionIndex) {
        return true;
      }
    }
    return false;
  }

  /// True when the ticket ends with a waiter-opened À SUIVRE (no items yet).
  /// True when an open À SUIVRE has at least one product line under it.
  static bool layoutHasProductsUnderPendingSuivre(
    List<OrderDisplayEntry> entries,
  ) {
    var underPending = false;
    for (final entry in entries) {
      if (entry.type == OrderDisplayEntryType.suivreSeparator) {
        underPending = true;
        continue;
      }
      if (entry.type == OrderDisplayEntryType.demandeSeparator) {
        underPending = false;
        continue;
      }
      if (underPending && entry.type == OrderDisplayEntryType.product) {
        return true;
      }
    }
    return false;
  }

  static bool layoutHasTrailingPendingSuivre(
    List<OrderDisplayEntry>? layout,
  ) {
    if (layout == null || layout.isEmpty) return false;
    return layout.last.type == OrderDisplayEntryType.suivreSeparator;
  }

  /// First open À SUIVRE on the ticket (session "Demander la suite").
  static int? firstPendingSuivreSectionIndex(List<OrderDisplayEntry> entries) {
    for (final entry in entries) {
      if (entry.type != OrderDisplayEntryType.suivreSeparator) continue;
      final sectionIndex = entry.sectionIndex ?? 0;
      if (sectionIndex > 0) return sectionIndex;
    }
    return null;
  }

  /// Exactly one course id — the next suite to demand (session screen).
  ///
  /// Uses the first pending À SUIVRE in waiter layout order, never every
  /// unrequested course on the ticket.
  static List<int> extractSingleNextCourseIdForDemande(
    Map<String, dynamic> data, {
    List<OrderDisplayEntry>? layout,
  }) {
    final layoutHints = coalesceLayoutHints(layout);
    if (layoutHints != null) {
      for (final entry in layoutHints) {
        if (entry.type != OrderDisplayEntryType.suivreSeparator) continue;
        final sectionIndex = entry.sectionIndex ?? 0;
        if (sectionIndex <= 0) continue;

        final fromLayout = extractRequestableCourseIdsForSuivreLayout(
          data,
          layout: layoutHints,
          sectionIndex: sectionIndex,
        );
        if (fromLayout.isNotEmpty) return [fromLayout.first];

        final above = entry.courseNumber ?? sectionIndex;
        final preferred = above > 0 ? above + 1 : sectionIndex + 1;
        final targetCourse = resolveWritableSuivreCourseNumber(
          data,
          preferredCourseNumber: preferred,
        );
        final fromNumber = extractRequestableCourseIdsForSuivreSection(
          data,
          courseNumber: targetCourse,
        );
        if (fromNumber.isNotEmpty) return [fromNumber.first];
      }
    }

    final fallback = extractRequestableCourseIds(data);
    if (fallback.isEmpty) return const [];
    return [fallback.first];
  }

  /// Converts À SUIVRE → DEMANDÉE for explicitly demanded suite sections.
  ///
  /// Bulk Envoyer does not call request-courses. Only sections in
  /// [demandedSectionIndices] (or legacy API guest-demand when no local layout)
  /// show DEMANDÉE.
  static List<OrderDisplayEntry> applyDemandeSeparatorsFromApi(
    Map<String, dynamic> data,
    List<OrderDisplayEntry> entries, {
    List<OrderDisplayEntry>? preservePendingSuivreFrom,
    Set<int> demandedSectionIndices = const {},
    bool trustLocalSuiteLayout = false,
    bool applyKitchenDemande = false,
  }) {
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

      Map<String, dynamic>? courseFired;
      if (sectionIndex > 0) {
        courseFired = _findRequestedCourseUnderSuivreSection(
          data,
          entries,
          sectionIndex: sectionIndex,
        );
      }
      if (courseFired == null && courseNumber > 0) {
        courseFired = findCourseInOrderDetail(data, courseNumber + 1);
      }

      final explicitlyDemanded =
          demandedSectionIndices.contains(sectionIndex);

      // Pending suite the waiter opened — never auto-demand on item add.
      if (!applyKitchenDemande &&
          preservePendingSuivreFrom != null &&
          _sectionHasPendingSuivre(preservePendingSuivreFrom, sectionIndex)) {
        result.add(entry);
        continue;
      }

      // Fresh install / no local layout: manual Demande leaves requested_at on
      // follow-up courses without bulk `status: requested`.
      final apiFollowUpDemanded = !trustLocalSuiteLayout &&
          !applyKitchenDemande &&
          !explicitlyDemanded &&
          courseFired != null &&
          isFollowUpApiCourse(data, courseFired) &&
          courseWasManuallyRequested(courseFired);

      final legacyGuestDemanded = !trustLocalSuiteLayout &&
          !explicitlyDemanded &&
          courseFired != null &&
          courseWasGuestDemanded(courseFired);
      final manualKitchenDemande = applyKitchenDemande &&
          courseFired != null &&
          (_courseWasRequestedToKitchen(courseFired) ||
              formatDemandeTime(courseFired['requested_at']) != null);

      if (!explicitlyDemanded &&
          !legacyGuestDemanded &&
          !manualKitchenDemande &&
          !apiFollowUpDemanded) {
        result.add(entry);
        continue;
      }

      var timeLabel = courseFired == null
          ? null
          : formatDemandeTime(courseFired['requested_at']);
      if (timeLabel == null && manualKitchenDemande) {
        timeLabel =
            formatDemandeTime(DateTime.now().toUtc().toIso8601String());
      }
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

  /// Next requested course after [afterCourseNumber] with visible items.
  static Map<String, dynamic>? _findNextRequestedCourseWithItems(
    Map<String, dynamic> data, {
    required int afterCourseNumber,
    int? skipSectionIndex,
    List<OrderDisplayEntry>? layout,
  }) {
    Map<String, dynamic>? best;
    var bestNumber = 1 << 30;
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return null;

    Set<int>? usedCourseNumbers;
    if (layout != null && skipSectionIndex != null && skipSectionIndex > 0) {
      usedCourseNumbers = <int>{};
      for (var s = 1; s < skipSectionIndex; s++) {
        final fired = _findRequestedCourseUnderSuivreSection(
          data,
          layout,
          sectionIndex: s,
        );
        if (fired != null) {
          final n = (fired['course_number'] as num?)?.toInt() ?? 0;
          if (n > 0) usedCourseNumbers.add(n);
        }
      }
    }

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number <= afterCourseNumber) continue;
        if (usedCourseNumbers != null && usedCourseNumbers.contains(number)) {
          continue;
        }
        if (_visibleItemCountInCourse(course) <= 0) continue;
        if (!_courseWasRequestedToKitchen(course)) continue;
        if (number < bestNumber) {
          bestNumber = number;
          best = course;
        }
      }
    }
    return best;
  }

  /// Course holding products under a pending À SUIVRE when that course was fired.
  static Map<String, dynamic>? _findRequestedCourseUnderSuivreSection(
    Map<String, dynamic> data,
    List<OrderDisplayEntry> layout, {
    required int sectionIndex,
  }) {
    final under = productEntriesUnderSection(layout, sectionIndex);
    if (under.isEmpty) return null;

    final courseNumbers = _resolveCourseNumbersForLayoutSection(
      data,
      layout,
      sectionIndex: sectionIndex,
      products: under,
    );
    if (courseNumbers.isEmpty) return null;

    Map<String, dynamic>? best;
    var bestNumber = 1 << 30;
    for (final number in courseNumbers) {
      final course = findCourseInOrderDetail(data, number);
      if (course == null) continue;
      if (!_courseWasRequestedToKitchen(course)) continue;
      if (number < bestNumber) {
        bestNumber = number;
        best = course;
      }
    }
    return best;
  }

  static Set<int> _resolveCourseNumbersForLayoutSection(
    Map<String, dynamic> data,
    List<OrderDisplayEntry> layout, {
    required int sectionIndex,
    required List<OrderDisplayEntry> products,
  }) {
    final courseNumbers = <int>{};
    for (final entry in products) {
      final n = entry.courseNumber ?? 0;
      if (n > 0) courseNumbers.add(n);
    }

    if (courseNumbers.isEmpty || courseNumbers.length > 1) {
      final seatNumber = resolveDefaultSeatNumber(data);
      final remaining = _visibleItemsWithCourseNumbers(
        data,
        seatNumber: seatNumber,
      );
      for (final entry in productsAboveSection(layout, sectionIndex)) {
        _takeMatchedOrderItem(remaining, entry);
      }
      courseNumbers.clear();
      for (final entry in products) {
        final match = _takeMatchedOrderItem(remaining, entry);
        if (match != null && match.courseNumber > 0) {
          courseNumbers.add(match.courseNumber);
        }
      }
    }

    if (courseNumbers.isEmpty) {
      for (final entry in layout) {
        if (entry.isSectionDivider && entry.sectionIndex == sectionIndex) {
          final above = entry.courseNumber ?? sectionIndex;
          if (above > 0) courseNumbers.add(above + 1);
          break;
        }
      }
    }
    return courseNumbers;
  }

  /// Force À SUIVRE → DEMANDÉE for one section after an explicit Demande success.
  static List<OrderDisplayEntry> convertSuivreSectionToDemande(
    List<OrderDisplayEntry> entries, {
    required int sectionIndex,
    String? demandeTimeLabel,
  }) {
    if (sectionIndex <= 0) return entries;
    final label = demandeTimeLabel ??
        formatDemandeTime(DateTime.now().toUtc().toIso8601String()) ??
        '--:--:--';

    return [
      for (final entry in entries)
        if (entry.type == OrderDisplayEntryType.suivreSeparator &&
            entry.sectionIndex == sectionIndex)
          OrderDisplayEntry.demande(
            sectionIndex: sectionIndex,
            courseNumber: entry.courseNumber ?? sectionIndex,
            demandeTimeLabel: label,
          )
        else
          entry,
    ];
  }

  /// Flip pending À SUIVRE whose under-course was fired (manual Demande only).
  static List<OrderDisplayEntry> convertAllPendingSuivreWithItemsToDemande(
    List<OrderDisplayEntry> entries, {
    Map<String, dynamic>? detail,
    String? fallbackDemandeTimeLabel,
  }) {
    if (detail == null) return entries;

    final fallback = fallbackDemandeTimeLabel ??
        formatDemandeTime(DateTime.now().toUtc().toIso8601String()) ??
        '--:--:--';

    final result = <OrderDisplayEntry>[];
    var changed = false;
    for (final entry in entries) {
      if (entry.type != OrderDisplayEntryType.suivreSeparator) {
        result.add(entry);
        continue;
      }
      final sectionIndex = entry.sectionIndex ?? 0;
      if (sectionIndex <= 0 ||
          productEntriesUnderSection(entries, sectionIndex).isEmpty) {
        result.add(entry);
        continue;
      }

      final course = _findRequestedCourseUnderSuivreSection(
        detail,
        entries,
        sectionIndex: sectionIndex,
      );
      if (course == null) {
        result.add(entry);
        continue;
      }

      final timeLabel =
          formatDemandeTime(course['requested_at']) ?? fallback;
      changed = true;
      result.add(
        OrderDisplayEntry.demande(
          sectionIndex: sectionIndex,
          courseNumber: entry.courseNumber ?? sectionIndex,
          demandeTimeLabel: timeLabel,
        ),
      );
    }
    return changed ? result : entries;
  }

  /// Keep live pending À SUIVRE when a sync wrongly returns DEMANDÉE.
  /// Never downgrade a live DEMANDÉE back to À SUIVRE.
  static List<OrderDisplayEntry> preferLivePendingSuivre({
    required List<OrderDisplayEntry> live,
    required List<OrderDisplayEntry> next,
  }) {
    final liveSuivreSections = <int>{
      for (final entry in live)
        if (entry.type == OrderDisplayEntryType.suivreSeparator)
          entry.sectionIndex ?? -1,
    }..removeWhere((id) => id < 0);
    final liveDemandeBySection = <int, OrderDisplayEntry>{
      for (final entry in live)
        if (entry.type == OrderDisplayEntryType.demandeSeparator &&
            (entry.sectionIndex ?? 0) > 0)
          entry.sectionIndex!: entry,
    };

    if (liveSuivreSections.isEmpty && liveDemandeBySection.isEmpty) {
      return next;
    }

    return [
      for (final entry in next)
        if (entry.type == OrderDisplayEntryType.demandeSeparator &&
            liveSuivreSections.contains(entry.sectionIndex) &&
            !liveDemandeBySection.containsKey(entry.sectionIndex))
          OrderDisplayEntry.suivre(
            sectionIndex: entry.sectionIndex ?? 0,
            courseNumber: entry.courseNumber ?? entry.sectionIndex ?? 0,
          )
        else if (entry.type == OrderDisplayEntryType.suivreSeparator &&
            liveDemandeBySection.containsKey(entry.sectionIndex))
          liveDemandeBySection[entry.sectionIndex]!
        else
          entry,
    ];
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

  /// Items in add order: `created_at`, then `id` (stable across soft vs menu).
  static List<Map<String, dynamic>> _visibleItemsInStableAddOrder(
    dynamic items,
  ) {
    if (items is! List) return const [];

    final visible = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      if (item['status'] == 'cancelled') continue;
      visible.add(item);
    }

    visible.sort((a, b) {
      final aCreated = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bCreated = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (aCreated != null && bCreated != null) {
        final byTime = aCreated.compareTo(bCreated);
        if (byTime != 0) return byTime;
      } else if (aCreated != null) {
        return -1;
      } else if (bCreated != null) {
        return 1;
      }

      final aId = (a['id'] as num?)?.toInt() ?? 0;
      final bId = (b['id'] as num?)?.toInt() ?? 0;
      return aId.compareTo(bId);
    });

    return visible;
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

      for (var courseIndex = 0; courseIndex < courses.length; courseIndex++) {
        final course = courses[courseIndex];
        final courseNumber =
            (course['course_number'] as num?)?.toInt() ?? firstCourseNumber;
        final visibleItems =
            _visibleItemsInStableAddOrder(course['items']);

        final isFollowUpCourse =
            courseIndex > 0 || courseNumber > firstCourseNumber;
        var activeSection = 0;

        // Only show a divider for follow-up courses that already have items.
        // Empty API courses must NOT auto-insert À SUIVRE — that steals later
        // adds into a suite the waiter never opened. Trailing empty À SUIVRE is
        // restored only from local layout hints in finalizeDisplayEntries.
        if (isFollowUpCourse) {
          if (visibleItems.isEmpty) {
            continue;
          }
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
        }

        for (final item in visibleItems) {
          entries.add(
            OrderDisplayEntry.product(
              product: orderProductFromItem(item),
              lineIndex: lineIndex++,
              sectionIndex: activeSection,
              courseNumber: courseNumber,
              itemId: (item['id'] as num?)?.toInt(),
            ),
          );
        }
      }
    }

    return entries;
  }

  /// One line for `POST …/seat-orders/:seat/items` (API accepts many per call).
  static Map<String, dynamic> seatOrderItemPayload({
    required int productId,
    required int qty,
    required double subTotal,
    String comment = '',
  }) {
    return {
      'product_id': productId,
      'qty': qty,
      'sub_total': subTotal,
      'comment': comment,
    };
  }

  static Map<String, dynamic> buildSeatOrderItemsPostPayload({
    required int courseNumber,
    required List<Map<String, dynamic>> items,
  }) {
    return {
      'course_number': courseNumber,
      'items': items,
    };
  }

  /// Convenience for a single-item POST body.
  static Map<String, dynamic> buildSeatOrderItemPostPayload({
    required int courseNumber,
    required int productId,
    required int qty,
    required double subTotal,
    String comment = '',
  }) {
    return buildSeatOrderItemsPostPayload(
      courseNumber: courseNumber,
      items: [
        seatOrderItemPayload(
          productId: productId,
          qty: qty,
          subTotal: subTotal,
          comment: comment,
        ),
      ],
    );
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

  /// Rebuild ticket rows from persisted split hints (relogin / cold load).
  ///
  /// Uses stable add order across all courses — not API course grouping — so
  /// duplicate tops wrongly parked on course 2 stay above À SUIVRE/DEMANDÉE.
  static List<OrderDisplayEntry> rebuildDisplayEntriesFromSplitHints(
    Map<String, dynamic> data,
    List<int> splitHints, {
    Set<int> demandedSectionIndices = const {},
  }) {
    if (splitHints.isEmpty) return const [];

    final seatNumber = resolveDefaultSeatNumber(data);
    final located = _visibleItemsWithCourseNumbers(
      data,
      seatNumber: seatNumber,
    );
    if (located.isEmpty) return const [];

    located.sort((a, b) {
      final aCreated =
          DateTime.tryParse(a.item['created_at']?.toString() ?? '');
      final bCreated =
          DateTime.tryParse(b.item['created_at']?.toString() ?? '');
      if (aCreated != null && bCreated != null) {
        final byTime = aCreated.compareTo(bCreated);
        if (byTime != 0) return byTime;
      } else if (aCreated != null) {
        return -1;
      } else if (bCreated != null) {
        return 1;
      }
      final aId = (a.item['id'] as num?)?.toInt() ?? 0;
      final bId = (b.item['id'] as num?)?.toInt() ?? 0;
      return aId.compareTo(bId);
    });

    final products = <OrderDisplayEntry>[];
    var lineIndex = 0;
    for (final row in located) {
      products.add(
        OrderDisplayEntry.product(
          product: orderProductFromItem(row.item),
          lineIndex: lineIndex++,
          sectionIndex: 0,
          courseNumber: row.courseNumber,
          itemId: (row.item['id'] as num?)?.toInt(),
        ),
      );
    }

    final validSplits = splitHints
        .where((splitAt) => splitAt > 0 && splitAt <= products.length)
        .toList();
    if (validSplits.isEmpty) return products;

    return _rebuildEntriesWithSuivreSplits(
      products,
      validSplits,
      demandedSectionIndices: demandedSectionIndices,
      data: data,
    );
  }

  static List<OrderDisplayEntry> _rebuildEntriesWithSuivreSplits(
    List<OrderDisplayEntry> entries,
    List<int> splitPositions, {
    Set<int> demandedSectionIndices = const {},
    Map<String, dynamic>? data,
  }) {
    if (splitPositions.isEmpty) return entries;

    final products = entries
        .where((entry) => entry.type == OrderDisplayEntryType.product)
        .toList();
    if (products.isEmpty) return entries;

    final validSplits = splitPositions
        .where((splitAt) => splitAt > 0 && splitAt <= products.length)
        .toList();
    if (validSplits.isEmpty) return entries;

    final rebuilt = <OrderDisplayEntry>[];
    var lineIndex = 0;
    var sectionIndex = 0;
    var splitIdx = 0;

    // Allow duplicate split indices — DEMANDÉE + À SUIVRE can share a boundary.
    for (var i = 0; i <= products.length; i++) {
      while (splitIdx < validSplits.length && validSplits[splitIdx] == i) {
        sectionIndex++;
        final demandCourseNumber = sectionIndex;
        if (demandedSectionIndices.contains(sectionIndex)) {
          Map<String, dynamic>? course;
          if (data != null) {
            course = findCourseInOrderDetail(data, demandCourseNumber + 1);
          }
          rebuilt.add(
            OrderDisplayEntry.demande(
              sectionIndex: sectionIndex,
              courseNumber: demandCourseNumber,
              demandeTimeLabel: course == null
                  ? '--:--:--'
                  : formatDemandeTime(course['requested_at']) ?? '--:--:--',
            ),
          );
        } else {
          rebuilt.add(
            _suivreEntry(
              sectionIndex,
              courseNumber: demandCourseNumber,
            ),
          );
        }
        splitIdx++;
      }
      if (i >= products.length) continue;

      final productEntry = products[i];
      rebuilt.add(
        OrderDisplayEntry.product(
          product: productEntry.product!,
          lineIndex: lineIndex++,
          sectionIndex: sectionIndex,
          courseNumber: productEntry.courseNumber,
          itemId: productEntry.itemId,
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

  static int demandeSeparatorCount(List<OrderDisplayEntry> entries) {
    return entries
        .where((entry) => entry.type == OrderDisplayEntryType.demandeSeparator)
        .length;
  }

  /// À SUIVRE + DEMANDÉE rows (follow-up course slots on the ticket).
  static int sectionDividerCount(List<OrderDisplayEntry> entries) {
    return entries.where((entry) => entry.isSectionDivider).length;
  }

  /// Sections the waiter explicitly demanded (DEMANDÉE), not merely sent.
  static Set<int> demandedSectionIndicesFromEntries(
    List<OrderDisplayEntry> entries,
  ) {
    return {
      for (final entry in entries)
        if (entry.type == OrderDisplayEntryType.demandeSeparator &&
            (entry.sectionIndex ?? 0) > 0)
          entry.sectionIndex!,
    };
  }

  /// Session list row already has full detail for expand (dividers or hydrated products).
  static bool sessionListDetailIsHydrated(SessionOrder order) {
    if (order.displayEntries.isEmpty) return false;
    if (sectionDividerCount(order.displayEntries) > 0) return true;
    if (demandeSeparatorCount(order.displayEntries) > 0) return true;

    final productEntries = order.displayEntries
        .where((entry) => entry.type == OrderDisplayEntryType.product)
        .toList();
    if (productEntries.isEmpty) return false;
    if (productEntries.length != order.products.length) return true;

    // Flat list — only skip detail fetch when every visible line has a server id.
    return productEntries.every((entry) => (entry.itemId ?? 0) > 0);
  }

  static List<OrderDisplayEntry> coalesceDisplayEntriesWithProducts(
    List<OrderProduct> products,
    List<OrderDisplayEntry> entries,
  ) {
    final covered = productEntryCount(entries);
    if (products.isEmpty || covered >= products.length) return entries;

    if (entries.isEmpty) {
      return [
        for (var i = 0; i < products.length; i++)
          OrderDisplayEntry.product(
            product: products[i],
            lineIndex: i,
          ),
      ];
    }

    final result = entries.toList();
    for (var i = covered; i < products.length; i++) {
      result.add(
        OrderDisplayEntry.product(
          product: products[i],
          lineIndex: i,
          itemId: 0,
        ),
      );
    }
    return reindexDisplayEntries(result);
  }

  static SessionOrder ensureSessionDisplayHydrated(SessionOrder order) {
    if (order.products.isEmpty) return order;
    // Summary rows keep displayEntries empty until GET detail — never invent a
    // flat fallback layout (that hides À SUIVRE / DEMANDÉE and breaks adds).
    if (order.displayEntries.isEmpty) return order;
    if (productEntryCount(order.displayEntries) >= order.products.length) {
      return order;
    }
    return order.copyWith(
      displayEntries: coalesceDisplayEntriesWithProducts(
        order.products,
        order.displayEntries,
      ),
    );
  }

  static List<OrderDisplayEntry>? layoutHintsFromSessionOrder(
    SessionOrder? order,
  ) {
    if (order == null) return null;
    final fromDisplay = coalesceLayoutHints(order.displayEntries);
    if (fromDisplay != null) return fromDisplay;
    if (order.products.isEmpty || order.displayEntries.isEmpty) return null;
    return coalesceDisplayEntriesWithProducts(
      order.products,
      order.displayEntries,
    );
  }

  /// Guest demanded the follow-up course (`status: requested` + timestamp).
  static bool courseWasGuestDemanded(Map<String, dynamic> course) {
    final status = course['status']?.toString().toLowerCase();
    if (status != 'requested') return false;
    final requestedAt = course['requested_at'];
    return requestedAt != null && requestedAt.toString().trim().isNotEmpty;
  }

  /// Manual `request-courses` on a follow-up course (not bulk send-all).
  static bool courseWasManuallyRequested(Map<String, dynamic> course) {
    final requestedAt = course['requested_at'];
    if (requestedAt == null || requestedAt.toString().trim().isEmpty) {
      return false;
    }
    final status = course['status']?.toString().toLowerCase();
    return status != 'requested';
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

  /// Empty layout lists must not suppress Hive suivre hints (treat as absent).
  static List<OrderDisplayEntry>? coalesceLayoutHints(
    List<OrderDisplayEntry>? entries,
  ) {
    if (entries == null || entries.isEmpty) return null;
    return entries;
  }

  static Set<int> productItemIds(List<OrderDisplayEntry> entries) {
    final ids = <int>{};
    for (final entry in entries) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      final id = entry.itemId ?? 0;
      if (id > 0) ids.add(id);
    }
    return ids;
  }

  static int productEntryCount(List<OrderDisplayEntry> entries) {
    var count = 0;
    for (final entry in entries) {
      if (entry.type == OrderDisplayEntryType.product) count++;
    }
    return count;
  }

  static bool hasOptimisticProductEntries(List<OrderDisplayEntry> entries) {
    for (final entry in entries) {
      if (entry.type == OrderDisplayEntryType.product &&
          (entry.itemId ?? 0) <= 0) {
        return true;
      }
    }
    return false;
  }

  static List<OrderDisplayEntry> reindexDisplayEntries(
    List<OrderDisplayEntry> entries,
  ) {
    var lineIndex = 0;
    return [
      for (final entry in entries)
        if (entry.type == OrderDisplayEntryType.product &&
            entry.product != null)
          OrderDisplayEntry.product(
            product: entry.product!,
            lineIndex: lineIndex++,
            sectionIndex: entry.sectionIndex ?? 0,
            courseNumber: entry.courseNumber,
            itemId: entry.itemId,
          )
        else
          entry,
    ];
  }

  static List<OrderDisplayEntry> _reindexDisplayEntries(
    List<OrderDisplayEntry> entries,
  ) =>
      reindexDisplayEntries(entries);

  /// Merge a server snapshot with the live optimistic ticket so background
  /// sync cannot flash blank, restore deleted lines, or drop local À SUIVRE.
  static SessionOrder mergeLiveOptimisticDetail({
    required SessionOrder server,
    required SessionOrder? live,
    Set<int> suppressItemIds = const {},
    bool preferAdoptingNewServerLines = false,
    int? selectedSuivreSectionIndex,
  }) {
    if (live == null) {
      return _stripSuppressedItems(server, suppressItemIds);
    }

    // Never replace a non-empty ticket with an empty server flash.
    if (server.products.isEmpty && live.products.isNotEmpty) {
      return _stripSuppressedItems(live, suppressItemIds);
    }

    final liveCount = productEntryCount(live.displayEntries);
    // Empty live + suppressed deletes: keep only non-suppressed server lines.
    // (Revive/add after delete-all must not be wiped just because suppress is set.)
    if (liveCount == 0 && suppressItemIds.isNotEmpty) {
      return _stripSuppressedItems(server, suppressItemIds);
    }

    final serverCount = productEntryCount(server.displayEntries);
    final liveSuivre = suivreSeparatorCount(live.displayEntries);
    final serverSuivre = suivreSeparatorCount(server.displayEntries);
    final liveDividers = sectionDividerCount(live.displayEntries);
    final serverDividers = sectionDividerCount(server.displayEntries);
    final serverMultiCourse =
        displayHasRealMultiCourseSections(server.displayEntries);
    // Pending À SUIVRE converted to DEMANDÉE is not "live ahead".
    final liveHasExtraPendingSuivre =
        liveSuivre > serverSuivre && liveDividers > serverDividers;
    final liveAhead = liveCount > serverCount ||
        liveHasExtraPendingSuivre ||
        hasOptimisticProductEntries(live.displayEntries) ||
        layoutHasProductsUnderPendingSuivre(live.displayEntries);

    List<OrderDisplayEntry> display;
    if (liveAhead) {
      // Keep the waiter's current view; pull server ids/order where possible.
      display = live.displayEntries;
      if (server.displayEntries.isNotEmpty) {
        display = preservePreviousProductOrder(
          previous: live.displayEntries,
          next: reconcileSuivreDisplay(
            previous: live.displayEntries,
            next: server.displayEntries,
          ),
        );
        // If server is still missing optimistic lines, fall back to live.
        if (productEntryCount(display) < liveCount ||
            (suivreSeparatorCount(display) < liveSuivre &&
                sectionDividerCount(display) < liveDividers)) {
          display = appendUnmatchedServerProducts(
            liveDisplay: live.displayEntries,
            serverDisplay: server.displayEntries,
          );
        }
      }
    } else if (liveCount < serverCount && liveCount > 0) {
      if (preferAdoptingNewServerLines && suppressItemIds.isEmpty) {
        // Background add sync (menu/catalog): server gained lines live never
        // painted yet — append them under the waiter's open layout.
        display = appendUnmatchedServerProducts(
          liveDisplay: live.displayEntries,
          serverDisplay: server.displayEntries,
          selectedSuivreSectionIndex: selectedSuivreSectionIndex,
        );
        display = reconcileSuivreDisplay(
          previous: live.displayEntries,
          next: display,
        );
        if (liveSuivre > suivreSeparatorCount(display) &&
            liveDividers > sectionDividerCount(display)) {
          display = ensureSuivreSeparatorCount(
            display,
            liveSuivre,
            forceAppend: true,
          );
        }
        display = pinProductsRelativeToDividers(
          previous: live.displayEntries,
          next: display,
        );
      } else {
        // Live deleted some lines the server still returns — keep live's id set.
        final liveIds = productItemIds(live.displayEntries);
        display = [
          for (final entry in server.displayEntries)
            if (entry.type != OrderDisplayEntryType.product)
              entry
            else if ((entry.itemId ?? 0) <= 0 ||
                liveIds.contains(entry.itemId))
              entry,
        ];
        display = reconcileSuivreDisplay(
          previous: live.displayEntries,
          next: display,
        );
        if (liveSuivre > suivreSeparatorCount(display) &&
            liveDividers > sectionDividerCount(display)) {
          display = ensureSuivreSeparatorCount(
            display,
            liveSuivre,
            forceAppend: true,
          );
        }
        if (suivreSeparatorCount(display) > liveSuivre &&
            !(liveSuivre == 0 && serverMultiCourse)) {
          display = limitSuivreSeparatorCount(display, liveSuivre);
        }
      }
    } else {
      display = server.displayEntries;
      if (live.displayEntries.isNotEmpty) {
        display = reconcileSuivreDisplay(
          previous: live.displayEntries,
          next: display.isEmpty ? live.displayEntries : display,
        );
        display = preservePreviousProductOrder(
          previous: live.displayEntries,
          next: display,
        );
      }
    }

    // Add/sync must never flip a live pending À SUIVRE into DEMANDÉE.
    display = preferLivePendingSuivre(
      live: live.displayEntries,
      next: display,
    );

    // Live suite deletes / thinner tickets win over a fatter server snapshot.
    if (suivreSeparatorCount(display) > liveSuivre &&
        !(liveSuivre == 0 && serverMultiCourse)) {
      display = limitSuivreSeparatorCount(display, liveSuivre);
    }
    // No waiter suite on live → drop invented À SUIVRE, unless the server
    // ticket already reflects real API multi-course groups (course 1 + 2+).
    if (liveSuivre == 0 &&
        !serverMultiCourse &&
        !preferAdoptingNewServerLines) {
      display = limitSuivreSeparatorCount(display, 0);
    }
    if (!preferAdoptingNewServerLines &&
        liveCount > 0 &&
        liveCount < serverCount &&
        productEntryCount(display) > liveCount) {
      final liveIds = productItemIds(live.displayEntries);
      display = [
        for (final entry in display)
          if (entry.type != OrderDisplayEntryType.product)
            entry
          else if ((entry.itemId ?? 0) <= 0 || liveIds.contains(entry.itemId))
            entry,
      ];
      display = pinProductsRelativeToDividers(
        previous: live.displayEntries,
        next: display,
      );
    }

    if (suppressItemIds.isNotEmpty) {
      display = [
        for (final entry in display)
          if (entry.type != OrderDisplayEntryType.product)
            entry
          else if ((entry.itemId ?? 0) <= 0 ||
              !suppressItemIds.contains(entry.itemId))
            entry,
      ];
    }

    // Prefer the waiter's exact layout when the visible set matches — avoids
    // reorder flicker after delete/add sync.
    if (_sameVisibleTicketShape(live.displayEntries, display)) {
      display = stabilizeLiveLayoutWithServer(
        live: live.displayEntries,
        server: display,
      );
    }

    display = _reindexDisplayEntries(display);
    final products = [
      for (final entry in display)
        if (entry.type == OrderDisplayEntryType.product && entry.product != null)
          entry.product!,
    ];

    final mergedTotal = products.isEmpty
        ? formatPrice('0')
        : (products.length == server.products.length
            ? (server.products.isNotEmpty ? server.total : live.total)
            : _sumFormattedPrices(products));

    return server.copyWith(
      products: products,
      displayEntries: display,
      itemCount: products.length,
      total: mergedTotal,
    );
  }

  static bool _sameVisibleTicketShape(
    List<OrderDisplayEntry> a,
    List<OrderDisplayEntry> b,
  ) {
    if (productEntryCount(a) != productEntryCount(b)) return false;
    if (suivreSeparatorCount(a) != suivreSeparatorCount(b)) return false;
    if (demandeSeparatorCount(a) != demandeSeparatorCount(b)) return false;
    return true;
  }

  /// Keeps [live] row order/dividers; copies fresher item ids / products from
  /// [server] when the same line can be matched.
  static List<OrderDisplayEntry> stabilizeLiveLayoutWithServer({
    required List<OrderDisplayEntry> live,
    required List<OrderDisplayEntry> server,
  }) {
    final serverProducts = <OrderDisplayEntry>[
      for (final entry in server)
        if (entry.type == OrderDisplayEntryType.product) entry,
    ];
    final remaining = List<OrderDisplayEntry>.from(serverProducts);
    final result = <OrderDisplayEntry>[];
    var lineIndex = 0;

    OrderDisplayEntry? takeMatch(OrderDisplayEntry liveProduct) {
      final id = liveProduct.itemId ?? 0;
      if (id > 0) {
        final byId = remaining.indexWhere((e) => (e.itemId ?? 0) == id);
        if (byId >= 0) return remaining.removeAt(byId);
      }
      final key = _productFingerprint(liveProduct.product);
      if (key != null) {
        final byKey = remaining.indexWhere(
          (e) => _productFingerprint(e.product) == key,
        );
        if (byKey >= 0) return remaining.removeAt(byKey);
      }
      final name = liveProduct.product?.name.trim().toUpperCase();
      if (name != null && name.isNotEmpty) {
        final byName = remaining.indexWhere(
          (e) => e.product?.name.trim().toUpperCase() == name,
        );
        if (byName >= 0) return remaining.removeAt(byName);
      }
      // Never steal the next unmatched product — that pulled suite lines
      // above À SUIVRE when an above-divider row could not be matched.
      return null;
    }

    for (final entry in live) {
      if (entry.isSectionDivider) {
        result.add(entry);
        continue;
      }
      if (entry.type != OrderDisplayEntryType.product) {
        result.add(entry);
        continue;
      }
      final match = takeMatch(entry);
      // Keep the live row when the server has no match — never drop suite
      // lines just because rebake issued new item ids.
      final source = match ?? entry;
      if (source.product == null && entry.product == null) continue;
      result.add(
        OrderDisplayEntry.product(
          product: match?.product ?? entry.product!,
          lineIndex: lineIndex++,
          sectionIndex: entry.sectionIndex ?? 0,
          courseNumber: match?.courseNumber ?? entry.courseNumber,
          itemId: match?.itemId ?? entry.itemId,
        ),
      );
    }
    // Append unmatched server lines under the last live section so they are
    // not dropped, without inventing a position above À SUIVRE.
    if (remaining.isNotEmpty) {
      var lastSection = 0;
      for (final entry in result) {
        if (entry.isSectionDivider ||
            entry.type == OrderDisplayEntryType.product) {
          lastSection = entry.sectionIndex ?? lastSection;
        }
      }
      for (final product in remaining) {
        if (product.product == null) continue;
        result.add(
          OrderDisplayEntry.product(
            product: product.product!,
            lineIndex: lineIndex++,
            sectionIndex: lastSection,
            courseNumber: product.courseNumber,
            itemId: product.itemId,
          ),
        );
      }
    }
    return result;
  }

  /// After Demande: keep the waiter's suite layout, flip À SUIVRE → DEMANDÉE,
  /// and ensure every server product still appears under the right section.
  ///
  /// API extract/pin often flattens suite lines or leaves an empty DEMANDÉE
  /// while [serverOrder.products] still has the items (total / "In order").
  static SessionOrder rebuildOrderAfterSuivreDemande({
    required SessionOrder serverOrder,
    required List<OrderDisplayEntry> liveLayout,
    required int suivreSectionIndex,
    String? demandeTimeLabel,
  }) {
    final timeLabel = demandeTimeLabel ??
        formatDemandeTime(DateTime.now().toUtc().toIso8601String()) ??
        '--:--:--';

    var display = convertSuivreSectionToDemande(
      liveLayout,
      sectionIndex: suivreSectionIndex,
      demandeTimeLabel: timeLabel,
    );

    display = stabilizeLiveLayoutWithServer(
      live: display,
      server: serverOrder.displayEntries,
    );

    display = appendMissingProductsUnderSection(
      display: display,
      candidates: [
        for (final entry in serverOrder.displayEntries)
          if (entry.type == OrderDisplayEntryType.product) entry,
      ],
      sectionIndex: suivreSectionIndex,
    );

    // products[] can still hold lines that pin dropped from displayEntries.
    if (productEntryCount(display) < serverOrder.products.length) {
      display = appendMissingOrderProductsUnderSection(
        display: display,
        products: serverOrder.products,
        sectionIndex: suivreSectionIndex,
      );
    }

    display = reindexDisplayEntries(display);
    final products = [
      for (final entry in display)
        if (entry.type == OrderDisplayEntryType.product &&
            entry.product != null)
          entry.product!,
    ];

    return serverOrder.copyWith(
      displayEntries: display,
      products: products.isNotEmpty ? products : serverOrder.products,
      itemCount:
          products.isNotEmpty ? products.length : serverOrder.itemCount,
    );
  }

  /// Inserts [candidates] not already present in [display] under [sectionIndex].
  static List<OrderDisplayEntry> appendMissingProductsUnderSection({
    required List<OrderDisplayEntry> display,
    required List<OrderDisplayEntry> candidates,
    required int sectionIndex,
  }) {
    if (candidates.isEmpty) return display;

    final presentIds = productItemIds(display);
    final presentKeyCounts = <String, int>{};
    final presentNameCounts = <String, int>{};
    for (final entry in display) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      final key = _productFingerprint(entry.product);
      if (key != null) {
        presentKeyCounts[key] = (presentKeyCounts[key] ?? 0) + 1;
      }
      final name = entry.product?.name.trim().toUpperCase() ?? '';
      if (name.isNotEmpty) {
        presentNameCounts[name] = (presentNameCounts[name] ?? 0) + 1;
      }
    }

    final missing = <OrderDisplayEntry>[];
    for (final candidate in candidates) {
      if (candidate.product == null) continue;
      final id = candidate.itemId ?? 0;
      if (id > 0 && presentIds.contains(id)) continue;
      final key = _productFingerprint(candidate.product);
      if (key != null && (presentKeyCounts[key] ?? 0) > 0) {
        presentKeyCounts[key] = presentKeyCounts[key]! - 1;
        continue;
      }
      final name = candidate.product!.name.trim().toUpperCase();
      if (name.isNotEmpty && (presentNameCounts[name] ?? 0) > 0) {
        presentNameCounts[name] = presentNameCounts[name]! - 1;
        continue;
      }
      missing.add(candidate);
      if (id > 0) presentIds.add(id);
    }
    if (missing.isEmpty) return display;

    return _insertProductsUnderSection(
      display: display,
      products: missing,
      sectionIndex: sectionIndex,
    );
  }

  static List<OrderDisplayEntry> appendMissingOrderProductsUnderSection({
    required List<OrderDisplayEntry> display,
    required List<OrderProduct> products,
    required int sectionIndex,
  }) {
    if (products.isEmpty) return display;

    final presentKeyCounts = <String, int>{};
    final presentNameCounts = <String, int>{};
    for (final entry in display) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      final key = _productFingerprint(entry.product);
      if (key != null) {
        presentKeyCounts[key] = (presentKeyCounts[key] ?? 0) + 1;
      }
      final name = entry.product?.name.trim().toUpperCase() ?? '';
      if (name.isNotEmpty) {
        presentNameCounts[name] = (presentNameCounts[name] ?? 0) + 1;
      }
    }

    final missing = <OrderDisplayEntry>[];
    for (final product in products) {
      final key = _productFingerprint(product);
      if (key != null && (presentKeyCounts[key] ?? 0) > 0) {
        presentKeyCounts[key] = presentKeyCounts[key]! - 1;
        continue;
      }
      final name = product.name.trim().toUpperCase();
      if (name.isNotEmpty && (presentNameCounts[name] ?? 0) > 0) {
        presentNameCounts[name] = presentNameCounts[name]! - 1;
        continue;
      }
      missing.add(
        OrderDisplayEntry.product(
          product: product,
          lineIndex: 0,
          sectionIndex: sectionIndex,
        ),
      );
    }
    if (missing.isEmpty) return display;

    return _insertProductsUnderSection(
      display: display,
      products: missing,
      sectionIndex: sectionIndex,
    );
  }

  static List<OrderDisplayEntry> _insertProductsUnderSection({
    required List<OrderDisplayEntry> display,
    required List<OrderDisplayEntry> products,
    required int sectionIndex,
  }) {
    if (products.isEmpty) return display;

    final result = <OrderDisplayEntry>[];
    var inserted = false;
    var i = 0;
    while (i < display.length) {
      final entry = display[i];
      result.add(entry);
      if (entry.isSectionDivider && entry.sectionIndex == sectionIndex) {
        // Keep existing products under this section, then append missing.
        i++;
        while (i < display.length && !display[i].isSectionDivider) {
          result.add(display[i]);
          i++;
        }
        for (final product in products) {
          if (product.product == null) continue;
          result.add(
            OrderDisplayEntry.product(
              product: product.product!,
              lineIndex: 0,
              sectionIndex: sectionIndex,
              courseNumber: product.courseNumber,
              itemId: product.itemId,
            ),
          );
        }
        inserted = true;
        continue;
      }
      i++;
    }

    if (!inserted) {
      for (final product in products) {
        if (product.product == null) continue;
        result.add(
          OrderDisplayEntry.product(
            product: product.product!,
            lineIndex: 0,
            sectionIndex: sectionIndex,
            courseNumber: product.courseNumber,
            itemId: product.itemId,
          ),
        );
      }
    }

    return reindexDisplayEntries(result);
  }

  /// Copies server item ids onto [live] rows without reordering or rebuilding
  /// sections — used when background add sync completes while the waiter
  /// already sees the correct local ticket.
  static SessionOrder patchServerItemIdsOntoLive({
    required SessionOrder live,
    required SessionOrder server,
    Set<int> suppressItemIds = const {},
  }) {
    final serverProducts = <OrderDisplayEntry>[
      for (final entry in server.displayEntries)
        if (entry.type == OrderDisplayEntryType.product &&
            (entry.itemId ?? 0) > 0 &&
            !suppressItemIds.contains(entry.itemId))
          entry,
    ];
    final remaining = List<OrderDisplayEntry>.from(serverProducts);

    OrderDisplayEntry? takeMatch(OrderDisplayEntry liveProduct) {
      final id = liveProduct.itemId ?? 0;
      if (id > 0) {
        final byId = remaining.indexWhere((e) => (e.itemId ?? 0) == id);
        if (byId >= 0) return remaining.removeAt(byId);
      }
      final key = _productFingerprint(liveProduct.product);
      if (key != null) {
        final byKey = remaining.indexWhere(
          (e) => _productFingerprint(e.product) == key,
        );
        if (byKey >= 0) return remaining.removeAt(byKey);
      }
      return null;
    }

    var lineIndex = 0;
    final display = <OrderDisplayEntry>[];
    for (final entry in live.displayEntries) {
      if (entry.isSectionDivider) {
        display.add(entry);
        continue;
      }
      if (entry.type != OrderDisplayEntryType.product || entry.product == null) {
        display.add(entry);
        continue;
      }
      final match = takeMatch(entry);
      display.add(
        OrderDisplayEntry.product(
          product: match?.product ?? entry.product!,
          lineIndex: lineIndex++,
          sectionIndex: entry.sectionIndex ?? 0,
          courseNumber: match?.courseNumber ?? entry.courseNumber,
          itemId: match?.itemId ?? entry.itemId,
        ),
      );
    }

    final products = [
      for (final entry in display)
        if (entry.type == OrderDisplayEntryType.product && entry.product != null)
          entry.product!,
    ];

    return live.copyWith(
      id: server.id > 0 ? server.id : live.id,
      products: products,
      displayEntries: display,
      itemCount: products.length,
      total: products.isEmpty ? formatPrice('0') : live.total,
    );
  }

  static List<OrderDisplayEntry> appendUnmatchedServerProducts({
    required List<OrderDisplayEntry> liveDisplay,
    required List<OrderDisplayEntry> serverDisplay,
    int? selectedSuivreSectionIndex,
  }) {
    final representedIds = productItemIds(liveDisplay);
    final representedKeys = <String>{
      for (final entry in liveDisplay)
        if (entry.type == OrderDisplayEntryType.product)
          _productFingerprint(entry.product) ?? '',
    }..remove('');

    var result = liveDisplay.toList();
    for (final entry in serverDisplay) {
      if (entry.type != OrderDisplayEntryType.product ||
          entry.product == null) {
        continue;
      }
      final id = entry.itemId ?? 0;
      if (id > 0 && representedIds.contains(id)) continue;
      final key = _productFingerprint(entry.product);
      if (key != null && representedKeys.contains(key)) continue;

      final lineIndex = productEntryCount(result);
      result = _appendProductToDisplayEntries(
        result,
        product: entry.product!,
        lineIndex: lineIndex,
        selectedSuivreSectionIndex: selectedSuivreSectionIndex,
      );
      final last = result.last;
      if (last.type == OrderDisplayEntryType.product) {
        result[result.length - 1] = OrderDisplayEntry.product(
          product: last.product!,
          lineIndex: last.lineIndex ?? lineIndex,
          sectionIndex: last.sectionIndex ?? 0,
          courseNumber: entry.courseNumber ?? last.courseNumber,
          itemId: entry.itemId,
        );
      }
      if (id > 0) representedIds.add(id);
      if (key != null) representedKeys.add(key);
    }
    return result;
  }

  static SessionOrder mergeLiveWithPendingSuivreAdds({
    required SessionOrder server,
    required SessionOrder live,
    int? selectedSuivreSectionIndex,
    bool preferAdoptingNewServerLines = false,
  }) {
    final liveHydrated = ensureSessionDisplayHydrated(live);
    final serverHydrated = ensureSessionDisplayHydrated(server);

    final needsSuivrePreserve =
        layoutHasProductsUnderPendingSuivre(liveHydrated.displayEntries) ||
            hasOptimisticProductEntries(liveHydrated.displayEntries) ||
            suivreSeparatorCount(liveHydrated.displayEntries) >
                suivreSeparatorCount(serverHydrated.displayEntries) ||
            sectionDividerCount(liveHydrated.displayEntries) >
                sectionDividerCount(serverHydrated.displayEntries);

    if (!needsSuivrePreserve) {
      return mergeLiveOptimisticDetail(
        server: serverHydrated,
        live: liveHydrated,
        preferAdoptingNewServerLines: preferAdoptingNewServerLines,
        selectedSuivreSectionIndex: selectedSuivreSectionIndex,
      );
    }

    var patched = patchServerItemIdsOntoLive(
      live: liveHydrated,
      server: serverHydrated,
    );
    var display = appendUnmatchedServerProducts(
      liveDisplay: patched.displayEntries,
      serverDisplay: serverHydrated.displayEntries,
      selectedSuivreSectionIndex: selectedSuivreSectionIndex,
    );
    display = preferLivePendingSuivre(
      live: liveHydrated.displayEntries,
      next: display,
    );
    display = pinProductsRelativeToDividers(
      previous: liveHydrated.displayEntries,
      next: display,
    );

    final products = [
      for (final entry in display)
        if (entry.type == OrderDisplayEntryType.product &&
            entry.product != null)
          entry.product!,
    ];

    final mergedTotal = products.length == serverHydrated.products.length
        ? serverHydrated.total
        : (products.isEmpty
            ? formatPrice('0')
            : _sumFormattedPrices(products));

    return serverHydrated.copyWith(
      products: products,
      displayEntries: display,
      itemCount: products.length,
      total: mergedTotal,
    );
  }

  /// Never drop pending À SUIVRE rows the waiter opened locally when a stale
  /// background sync returns fewer separators than [live].
  static SessionOrder preservePendingSuivreFromLive({
    required SessionOrder live,
    required SessionOrder candidate,
  }) {
    final liveSuivre = suivreSeparatorCount(live.displayEntries);
    final candidateSuivre = suivreSeparatorCount(candidate.displayEntries);
    if (liveSuivre <= candidateSuivre) return candidate;

    final display = preferLivePendingSuivre(
      live: live.displayEntries,
      next: reconcileSuivreDisplay(
        previous: live.displayEntries,
        next: candidate.displayEntries,
      ),
    );
    final products = [
      for (final entry in display)
        if (entry.type == OrderDisplayEntryType.product && entry.product != null)
          entry.product!,
    ];
    return candidate.copyWith(
      products: products,
      displayEntries: display,
      itemCount: products.length,
    );
  }

  static SessionOrder _stripSuppressedItems(
    SessionOrder order,
    Set<int> suppressItemIds,
  ) {
    if (suppressItemIds.isEmpty) return order;
    final display = _reindexDisplayEntries([
      for (final entry in order.displayEntries)
        if (entry.type != OrderDisplayEntryType.product)
          entry
        else if ((entry.itemId ?? 0) <= 0 ||
            !suppressItemIds.contains(entry.itemId))
          entry,
    ]);
    final products = [
      for (final entry in display)
        if (entry.type == OrderDisplayEntryType.product && entry.product != null)
          entry.product!,
    ];
    return order.copyWith(
      products: products,
      displayEntries: display,
      itemCount: products.length,
      total: products.isEmpty ? formatPrice('0') : order.total,
    );
  }

  /// Keeps À SUIVRE rows when a refresh returns fewer separators than before.
  ///
  /// Does not treat false DEMANDÉE (from add-item sync) as authoritative over
  /// a pending À SUIVRE still on [previous].
  /// Never invents more À SUIVRE than [previous] (deleted suites must stay gone).
  static List<OrderDisplayEntry> reconcileSuivreDisplay({
    required List<OrderDisplayEntry> previous,
    required List<OrderDisplayEntry> next,
  }) {
    final previousSplits = suivreSplitPositions(previous);
    final nextSplits = suivreSplitPositions(next);
    final previousCount = suivreSeparatorCount(previous);
    final previousDividers = sectionDividerCount(previous);
    final adoptApiMultiCourse = previousCount == 0 &&
        displayHasRealMultiCourseSections(next);

    var result = preferLivePendingSuivre(live: previous, next: next);

    // Sync/API must not resurrect À SUIVRE the waiter already removed.
    if (suivreSeparatorCount(result) > previousCount && !adoptApiMultiCourse) {
      result = limitSuivreSeparatorCount(result, previousCount);
    }

    if (previousSplits.isNotEmpty &&
        nextSplits.length < previousSplits.length) {
      final mergedSplits = _mergeSuivreSplitPositions(
        extracted: nextSplits,
        hints: previousSplits,
      );
      result = _rebuildEntriesWithSuivreSplits(result, mergedSplits);
      result = preferLivePendingSuivre(live: previous, next: result);
      if (suivreSeparatorCount(result) > previousCount && !adoptApiMultiCourse) {
        result = limitSuivreSeparatorCount(result, previousCount);
      }
    }

    if (previousCount > suivreSeparatorCount(result) &&
        sectionDividerCount(result) < previousDividers) {
      result = ensureSuivreSeparatorCount(
        result,
        previousCount,
        forceAppend: true,
      );
    }

    // Items that were above a suite before sync must stay above — even when the
    // API wrongly parks them in a follow-up course.
    return pinProductsRelativeToDividers(previous: previous, next: result);
  }

  /// Drops empty À SUIVRE rows (including trailing) before opening a new suite.
  static List<OrderDisplayEntry> stripEmptySuivreSectionsForCreate(
    List<OrderDisplayEntry> entries,
  ) {
    return _normalizeSuivreLayout(entries, keepTrailingEmptySuivre: false);
  }

  /// Drops excess À SUIVRE rows (last first), keeping products in place.
  /// DEMANDÉE rows are never removed.
  static List<OrderDisplayEntry> limitSuivreSeparatorCount(
    List<OrderDisplayEntry> entries,
    int maxSuivre,
  ) {
    final maxCount = maxSuivre < 0 ? 0 : maxSuivre;
    var suivreCount = suivreSeparatorCount(entries);
    if (suivreCount <= maxCount) return entries;

    final result = entries.toList();
    for (var i = result.length - 1; i >= 0 && suivreCount > maxCount; i--) {
      if (result[i].type != OrderDisplayEntryType.suivreSeparator) continue;
      result.removeAt(i);
      suivreCount--;
    }
    return reindexDisplayEntries(result);
  }

  /// Rebuilds [next] so products that sat above each divider in [previous]
  /// stay above that divider.
  ///
  /// Matches by item id, then product fingerprint, then stable order — so
  /// optimistic lines (itemId 0) are not dumped under a newly opened À SUIVRE.
  /// Divider type prefers [next] (e.g. DEMANDÉE after kitchen).
  static List<OrderDisplayEntry> pinProductsRelativeToDividers({
    required List<OrderDisplayEntry> previous,
    required List<OrderDisplayEntry> next,
  }) {
    if (!previous.any((entry) => entry.isSectionDivider)) return next;

    final prevSections = <List<OrderDisplayEntry>>[<OrderDisplayEntry>[]];
    final previousDividers = <OrderDisplayEntry>[];
    for (final entry in previous) {
      if (entry.isSectionDivider) {
        previousDividers.add(entry);
        prevSections.add(<OrderDisplayEntry>[]);
      } else if (entry.type == OrderDisplayEntryType.product) {
        prevSections.last.add(entry);
      }
    }
    if (previousDividers.isEmpty) return next;

    final nextProducts = <OrderDisplayEntry>[
      for (final entry in next)
        if (entry.type == OrderDisplayEntryType.product) entry,
    ];
    if (nextProducts.isEmpty) return next;

    final nextDividerBySection = <int, OrderDisplayEntry>{
      for (final entry in next)
        if (entry.isSectionDivider && (entry.sectionIndex ?? 0) > 0)
          entry.sectionIndex!: entry,
    };

    final remaining = List<OrderDisplayEntry>.from(nextProducts);

    OrderDisplayEntry? takeMatch(OrderDisplayEntry prevProduct) {
      final id = prevProduct.itemId ?? 0;
      if (id > 0) {
        final byId = remaining.indexWhere((entry) => (entry.itemId ?? 0) == id);
        if (byId >= 0) return remaining.removeAt(byId);
      }
      final key = _productFingerprint(prevProduct.product);
      if (key != null) {
        final byKey = remaining.indexWhere(
          (entry) => _productFingerprint(entry.product) == key,
        );
        if (byKey >= 0) return remaining.removeAt(byKey);
      }
      final name = prevProduct.product?.name.trim().toUpperCase();
      if (name != null && name.isNotEmpty) {
        final byName = remaining.indexWhere(
          (entry) => entry.product?.name.trim().toUpperCase() == name,
        );
        if (byName >= 0) return remaining.removeAt(byName);
      }
      // Never steal the next unmatched product — that pulled suite lines
      // into the section above À SUIVRE.
      return null;
    }

    final result = <OrderDisplayEntry>[];
    var lineIndex = 0;

    void addProduct(OrderDisplayEntry product, int sectionIndex) {
      result.add(
        OrderDisplayEntry.product(
          product: product.product!,
          lineIndex: lineIndex++,
          sectionIndex: sectionIndex,
          courseNumber: product.courseNumber,
          itemId: product.itemId,
        ),
      );
    }

    for (var section = 0; section < prevSections.length; section++) {
      final activeSection = section == 0
          ? 0
          : (previousDividers[section - 1].sectionIndex ?? section);
      for (final prevProduct in prevSections[section]) {
        final match = takeMatch(prevProduct);
        if (match == null) continue;
        addProduct(match, activeSection);
      }
      if (section < previousDividers.length) {
        final previousDivider = previousDividers[section];
        final sectionKey = previousDivider.sectionIndex ?? (section + 1);
        result.add(nextDividerBySection[sectionKey] ?? previousDivider);
      }
    }

    final lastSection = previousDividers.isEmpty
        ? 0
        : (previousDividers.last.sectionIndex ?? previousDividers.length);
    for (final product in remaining) {
      addProduct(product, lastSection);
    }

    // Never allow a leading divider when previous had products above it.
    if (result.isNotEmpty &&
        result.first.isSectionDivider &&
        prevSections.first.isNotEmpty) {
      return next;
    }

    return reindexDisplayEntries(result);
  }

  /// After kitchen send, a flat pre-send ticket must stay flat above DEMANDÉE.
  ///
  /// The API sometimes parks later lines of the same burst in course 2, which
  /// extracts as `P1 / DEMANDÉE / P2 / P3`. When [previous] had no divider,
  /// keep every pre-send product above the first kitchen divider.
  static List<OrderDisplayEntry> coalesceProductsBeforeFirstDivider({
    required List<OrderDisplayEntry> previous,
    required List<OrderDisplayEntry> next,
  }) {
    if (previous.any((entry) => entry.isSectionDivider)) return next;

    final dividerIndex = next.indexWhere((entry) => entry.isSectionDivider);
    if (dividerIndex < 0) return next;

    final prevProducts = <OrderDisplayEntry>[
      for (final entry in previous)
        if (entry.type == OrderDisplayEntryType.product) entry,
    ];
    if (prevProducts.isEmpty) return next;

    final remaining = <OrderDisplayEntry>[
      for (final entry in next)
        if (entry.type == OrderDisplayEntryType.product) entry,
    ];
    if (remaining.isEmpty) return next;

    OrderDisplayEntry? takeMatch(OrderDisplayEntry prevProduct) {
      final id = prevProduct.itemId ?? 0;
      if (id > 0) {
        final byId = remaining.indexWhere((entry) => (entry.itemId ?? 0) == id);
        if (byId >= 0) return remaining.removeAt(byId);
      }
      final key = _productFingerprint(prevProduct.product);
      if (key != null) {
        final byKey = remaining.indexWhere(
          (entry) => _productFingerprint(entry.product) == key,
        );
        if (byKey >= 0) return remaining.removeAt(byKey);
      }
      final name = prevProduct.product?.name.trim().toUpperCase();
      if (name != null && name.isNotEmpty) {
        final byName = remaining.indexWhere(
          (entry) => entry.product?.name.trim().toUpperCase() == name,
        );
        if (byName >= 0) return remaining.removeAt(byName);
      }
      return null;
    }

    final above = <OrderDisplayEntry>[];
    for (final prevProduct in prevProducts) {
      final match = takeMatch(prevProduct);
      if (match != null) above.add(match);
    }

    final productsBeforeDivider = next
        .take(dividerIndex)
        .where((entry) => entry.type == OrderDisplayEntryType.product)
        .length;
    // Already correct: every pre-send line is above DEMANDÉE.
    if (productsBeforeDivider >= above.length && remaining.isEmpty) {
      return next;
    }

    final firstDivider = next[dividerIndex];
    final belowSection = firstDivider.sectionIndex ?? 1;
    final result = <OrderDisplayEntry>[];
    var lineIndex = 0;

    void addProduct(OrderDisplayEntry product, int sectionIndex) {
      result.add(
        OrderDisplayEntry.product(
          product: product.product!,
          lineIndex: lineIndex++,
          sectionIndex: sectionIndex,
          courseNumber: product.courseNumber,
          itemId: product.itemId,
        ),
      );
    }

    for (final product in above) {
      addProduct(product, 0);
    }
    result.add(firstDivider);
    for (final product in remaining) {
      addProduct(product, belowSection);
    }

    return reindexDisplayEntries(result);
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
    Set<int> demandedSectionIndices = const {},
    bool applyKitchenDemande = false,
  }) {
    var entries = extractOrderDisplayEntries(data);
    final extractedProductCount = productEntryCount(entries);
    final extractedSuivreCount = suivreSeparatorCount(entries);
    final extractedDividerCount = sectionDividerCount(entries);
    final apiFollowUpCourseCount = countFollowUpCoursesWithItems(data);
    final trustLocalSuiteLayout = suivreSplitHints.isNotEmpty ||
        suivreCountHint > 0 ||
        (previousDisplayEntries != null &&
            sectionDividerCount(previousDisplayEntries) > 0);
    final effectiveDemandedSections = demandedSectionIndices.isNotEmpty
        ? demandedSectionIndices
        : (previousDisplayEntries == null
            ? const <int>{}
            : demandedSectionIndicesFromEntries(previousDisplayEntries));

    // Relogin: Hive split hints record where the waiter placed À SUIVRE.
    // Prefer that over API course grouping when tops drifted onto course 2.
    if (suivreSplitHints.isNotEmpty) {
      final fromHints = rebuildDisplayEntriesFromSplitHints(
        data,
        suivreSplitHints,
        demandedSectionIndices: effectiveDemandedSections,
      );
      if (productEntryCount(fromHints) == extractedProductCount) {
        final previousDividers = previousDisplayEntries == null
            ? 0
            : sectionDividerCount(previousDisplayEntries);
        if (previousDisplayEntries == null ||
            previousDisplayEntries.isEmpty ||
            sectionDividerCount(fromHints) >= previousDividers) {
          entries = fromHints;
        }
      }
    }

    entries = applyDemandeSeparatorsFromApi(
      data,
      entries,
      preservePendingSuivreFrom:
          applyKitchenDemande ? null : previousDisplayEntries,
      demandedSectionIndices: effectiveDemandedSections,
      trustLocalSuiteLayout: trustLocalSuiteLayout,
      applyKitchenDemande: applyKitchenDemande,
    );
    final previousDividerCount = previousDisplayEntries == null
        ? 0
        : sectionDividerCount(previousDisplayEntries);
    // After an explicit kitchen send, do not re-overlay pending À SUIVRE counts.
    // When a waiter layout is provided, trust it — never revive deleted suites
    // from a stale Hive count hint.
    final effectiveDividerCount = applyKitchenDemande
        ? 0
        : [
            previousDividerCount,
            suivreCountHint,
            suivreSplitHints.length,
            extractedDividerCount,
          ].reduce((a, b) => a > b ? a : b);
    final trailingPending = !applyKitchenDemande &&
        layoutHasTrailingPendingSuivre(previousDisplayEntries);
    final previousIsFlat = previousDisplayEntries != null &&
        previousDisplayEntries.isNotEmpty &&
        sectionDividerCount(previousDisplayEntries) == 0;

    // Restore local suite dividers the API does not know about yet.
    final currentDividers = sectionDividerCount(entries);
    if (effectiveDividerCount > currentDividers) {
      var pending = effectiveDividerCount - currentDividers;
      while (pending > 0) {
        final before = sectionDividerCount(entries);
        entries = appendSuivreSeparatorAfterRequest(
          entries,
          force: entries.isNotEmpty && _isSectionDivider(entries.last),
        );
        if (sectionDividerCount(entries) <= before) break;
        pending--;
      }
    }

    // Flat waiter layout wins over API course shells; otherwise keep API groups.
    if (!applyKitchenDemande && suivreSplitHints.isEmpty) {
      if (previousIsFlat &&
          !apiHasFirstCourseWithItemsAndFollowUps(data)) {
        entries = limitSuivreSeparatorCount(entries, 0);
      } else if (effectiveDividerCount == 0 &&
          extractedSuivreCount == 0 &&
          apiFollowUpCourseCount == 0) {
        entries = limitSuivreSeparatorCount(entries, 0);
      }
    }

    if (previousDisplayEntries != null && previousDisplayEntries.isNotEmpty) {
      if (applyKitchenDemande) {
        // Keep DEMANDÉE from kitchen send — do not reconcile back to À SUIVRE.
        entries = pinProductsRelativeToDividers(
          previous: previousDisplayEntries,
          next: entries,
        );
        // Flat pre-send ticket: do not leave burst items stranded under DEMANDÉE.
        entries = coalesceProductsBeforeFirstDivider(
          previous: previousDisplayEntries,
          next: entries,
        );
        entries = preservePreviousProductOrder(
          previous: previousDisplayEntries,
          next: entries,
        );
      } else {
        final shouldReconcile = previousDividerCount > 0 ||
            (suivreSplitHints.isEmpty &&
                suivreCountHint == 0 &&
                extractedSuivreCount == 0 &&
                apiFollowUpCourseCount == 0);
        if (shouldReconcile) {
          entries = reconcileSuivreDisplay(
            previous: previousDisplayEntries,
            next: entries,
          );
        }
        entries = preservePreviousProductOrder(
          previous: previousDisplayEntries,
          next: entries,
        );
        if (previousDividerCount == 0 &&
            sectionDividerCount(previousDisplayEntries) == 0 &&
            suivreSplitHints.isEmpty &&
            suivreCountHint == 0 &&
            extractedSuivreCount == 0 &&
            apiFollowUpCourseCount == 0) {
          entries = limitSuivreSeparatorCount(entries, 0);
        }
      }
    }

    // Hard safety: never drop API products because of pin/coalesce mistakes.
    if (productEntryCount(entries) < extractedProductCount) {
      if (suivreSplitHints.isNotEmpty) {
        final fromHints = rebuildDisplayEntriesFromSplitHints(
          data,
          suivreSplitHints,
          demandedSectionIndices: effectiveDemandedSections,
        );
        if (productEntryCount(fromHints) == extractedProductCount) {
          entries = applyDemandeSeparatorsFromApi(
            data,
            fromHints,
            demandedSectionIndices: effectiveDemandedSections,
            trustLocalSuiteLayout: trustLocalSuiteLayout,
            applyKitchenDemande: applyKitchenDemande,
          );
        } else {
          entries = extractOrderDisplayEntries(data);
          entries = applyDemandeSeparatorsFromApi(
            data,
            entries,
            demandedSectionIndices: effectiveDemandedSections,
            trustLocalSuiteLayout: trustLocalSuiteLayout,
            applyKitchenDemande: applyKitchenDemande,
          );
        }
      } else {
        entries = extractOrderDisplayEntries(data);
        entries = applyDemandeSeparatorsFromApi(
          data,
          entries,
          demandedSectionIndices: effectiveDemandedSections,
          trustLocalSuiteLayout: trustLocalSuiteLayout,
          applyKitchenDemande: applyKitchenDemande,
        );
      }
    }

    // Keep a trailing empty À SUIVRE the waiter just opened (before first item).
    return _normalizeSuivreLayout(
      entries,
      keepTrailingEmptySuivre: trailingPending ||
          layoutHasTrailingPendingSuivre(entries),
    );
  }

  /// Reorders products within each course to match [previous] item ids.
  /// New ids (or optimistic id 0) are appended at the end of their course.
  static List<OrderDisplayEntry> preservePreviousProductOrder({
    required List<OrderDisplayEntry> previous,
    required List<OrderDisplayEntry> next,
  }) {
    final previousIds = <int>[];
    final seen = <int>{};
    for (final entry in previous) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      final id = entry.itemId ?? 0;
      if (id <= 0) continue;
      if (seen.add(id)) previousIds.add(id);
    }
    if (previousIds.isEmpty) {
      return _preserveOrderByProductFingerprint(previous: previous, next: next);
    }

    final byCourse = <int?, List<OrderDisplayEntry>>{};
    for (final entry in next) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      byCourse.putIfAbsent(entry.courseNumber, () => []).add(entry);
    }

    for (final courseNumber in byCourse.keys.toList()) {
      final products = byCourse[courseNumber]!;
      final byId = <int, OrderDisplayEntry>{};
      final withoutId = <OrderDisplayEntry>[];
      for (final product in products) {
        final id = product.itemId ?? 0;
        if (id > 0) {
          byId[id] = product;
        } else {
          withoutId.add(product);
        }
      }

      final ordered = <OrderDisplayEntry>[];
      for (final id in previousIds) {
        final match = byId.remove(id);
        if (match != null) ordered.add(match);
      }
      // Keep relative order of any remaining API ids, then optimistic lines.
      for (final product in products) {
        final id = product.itemId ?? 0;
        if (id > 0 && byId.containsKey(id)) {
          ordered.add(byId.remove(id)!);
        }
      }
      ordered.addAll(withoutId);
      byCourse[courseNumber] = ordered;
    }

    return _rebuildEntriesKeepingDividers(
      next: next,
      productsByCourse: byCourse,
    );
  }

  /// Fallback when previous lines have no real item ids yet (optimistic only).
  static List<OrderDisplayEntry> _preserveOrderByProductFingerprint({
    required List<OrderDisplayEntry> previous,
    required List<OrderDisplayEntry> next,
  }) {
    final previousKeys = <String>[];
    for (final entry in previous) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      final key = _productFingerprint(entry.product);
      if (key != null) previousKeys.add(key);
    }
    if (previousKeys.isEmpty) return next;

    final byCourse = <int?, List<OrderDisplayEntry>>{};
    for (final entry in next) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      byCourse.putIfAbsent(entry.courseNumber, () => []).add(entry);
    }

    for (final courseNumber in byCourse.keys.toList()) {
      final products = byCourse[courseNumber]!;
      final remaining = List<OrderDisplayEntry>.from(products);
      final ordered = <OrderDisplayEntry>[];

      for (final key in previousKeys) {
        final idx = remaining.indexWhere(
          (entry) => _productFingerprint(entry.product) == key,
        );
        if (idx < 0) continue;
        ordered.add(remaining.removeAt(idx));
      }
      ordered.addAll(remaining);
      byCourse[courseNumber] = ordered;
    }

    return _rebuildEntriesKeepingDividers(
      next: next,
      productsByCourse: byCourse,
    );
  }

  static String? _productFingerprint(OrderProduct? product) {
    if (product == null) return null;
    // Name + qty only — price formatting ("5" vs "5,00 €") breaks matching.
    return '${product.name.trim().toUpperCase()}|${product.quantity}';
  }

  static List<OrderDisplayEntry> _rebuildEntriesKeepingDividers({
    required List<OrderDisplayEntry> next,
    required Map<int?, List<OrderDisplayEntry>> productsByCourse,
  }) {
    final cursors = <int?, int>{};
    final result = <OrderDisplayEntry>[];
    for (final entry in next) {
      if (entry.type != OrderDisplayEntryType.product) {
        result.add(entry);
        continue;
      }
      final courseNumber = entry.courseNumber;
      final products = productsByCourse[courseNumber];
      if (products == null || products.isEmpty) {
        result.add(entry);
        continue;
      }
      final cursor = cursors[courseNumber] ?? 0;
      if (cursor >= products.length) {
        result.add(entry);
        continue;
      }
      result.add(products[cursor]);
      cursors[courseNumber] = cursor + 1;
    }
    return result;
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
      // Only collapse accidental double À SUIVRE — keep DEMANDÉE + À SUIVRE pairs.
      if (entry.type == OrderDisplayEntryType.suivreSeparator &&
          result.isNotEmpty &&
          result.last.type == OrderDisplayEntryType.suivreSeparator) {
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
      var followedByDivider = false;
      for (var j = i + 1; j < entries.length; j++) {
        if (_isSectionDivider(entries[j])) {
          followedByDivider = true;
          break;
        }
        if (entries[j].type == OrderDisplayEntryType.product) {
          hasProducts = true;
          break;
        }
      }

      if (hasProducts || followedByDivider) {
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
  ///
  /// Never stacks consecutive À SUIVRE rows (even with [force]) — that created
  /// duplicate suites after delete/recreate. [force] only allows appending after
  /// a DEMANDÉE (or other non-suivre) divider.
  static List<OrderDisplayEntry> appendSuivreSeparatorAfterRequest(
    List<OrderDisplayEntry> entries, {
    bool force = false,
  }) {
    if (entries.isEmpty) return entries;

    if (entries.last.type == OrderDisplayEntryType.suivreSeparator) {
      return entries;
    }

    if (!force && layoutHasTrailingPendingSuivre(entries)) {
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

  /// POST /api/orders with all locally drafted lines (no seed product).
  static Map<String, dynamic> buildCreateOrderFromDraftLines({
    required int waiterId,
    required int numberOfGuests,
    required int tableId,
    int? salesZoneId,
    required List<LocalDraftLine> lines,
  }) {
    if (lines.isEmpty) {
      throw ArgumentError('Cannot create an order without items.');
    }

    const defaultSeat = 1;
    final byCourse = <int, List<LocalDraftLine>>{};
    for (final line in lines) {
      final courseNumber = line.courseNumber > 0 ? line.courseNumber : 1;
      byCourse.putIfAbsent(courseNumber, () => []).add(line);
    }

    final courseNumbers = byCourse.keys.toList()..sort();
    final courses = [
      for (final courseNumber in courseNumbers)
        {
          'id': 0,
          'course_number': courseNumber,
          'seat_number': defaultSeat,
          'items': [
            for (final line in byCourse[courseNumber]!)
              _buildNewItemPayload(
                seatNumber: line.seatNumber > 0 ? line.seatNumber : defaultSeat,
                courseId: 0,
                productId: line.productId,
                qty: line.qty,
                subTotal: line.unitPrice * line.qty,
                status: 'to_be_continued',
                comment: line.comment,
                menuSelections: line.menuSelections,
                forCreate: true,
              ),
          ],
        },
    ];

    final payload = <String, dynamic>{
      'waiter_id': waiterId,
      'number_of_guests': numberOfGuests,
      'table_id': tableId,
      'seat_orders': [
        {
          'seat_number': defaultSeat,
          'courses': courses,
        },
      ],
    };
    if (salesZoneId != null) payload['sales_zone_id'] = salesZoneId;
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

  /// Parses a waiter-entered table key (`42`, `T42`) for open-by-number.
  static int? parseTableNumberForOpenByNumber(String tableNumber) {
    final normalized = normalizeTableKey(tableNumber);
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  /// POST /api/tables/open-by-number request body.
  static Map<String, dynamic> buildOpenTableByNumberPayload({
    required int tableNumber,
    required int numberOfGuests,
    required int waiterId,
    String? waiterName,
    int? salesZoneId,
  }) {
    final payload = <String, dynamic>{
      'table_number': tableNumber,
      'number_of_guests': numberOfGuests < 1 ? 1 : numberOfGuests,
      'waiter_id': waiterId,
    };
    final name = waiterName?.trim();
    if (name != null && name.isNotEmpty) {
      payload['waiter_name'] =
          name.length > 255 ? name.substring(0, 255) : name;
    }
    if (salesZoneId != null && salesZoneId > 0) {
      payload['sales_zone_id'] = salesZoneId;
    }
    return payload;
  }

  /// Table row from open-by-number success or conflict `data`.
  static ResolvedTable resolvedTableFromPayload(
    Map<String, dynamic> data, {
    int? fallbackTableNumber,
  }) {
    return _toResolvedTable(data);
  }

  /// Active order id from a 409 open-by-number response (table or nested data).
  static int? activeOrderIdFromConflictBody(Object? body) {
    if (body is! Map<String, dynamic>) return null;

    int? fromMap(Map<String, dynamic> map) {
      final fromTable = _activeOrderId(map);
      if (fromTable != null && fromTable > 0) return fromTable;

      final active = map['active_order'];
      if (active is Map<String, dynamic>) {
        final id = (active['id'] as num?)?.toInt();
        if (id != null && id > 0) return id;
      }

      final direct = map['order_id'] ?? map['active_order_id'];
      if (direct is num && direct > 0) return direct.toInt();
      return null;
    }

    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final nested = fromMap(data);
      if (nested != null) return nested;
    }
    return fromMap(body);
  }

  static ResolvedTable? resolvedTableFromConflictBody(
    Object? body, {
    required int fallbackTableNumber,
  }) {
    if (body is! Map<String, dynamic>) return null;

    Map<String, dynamic>? tableMap;
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      if (data.containsKey('id') || data.containsKey('table_number')) {
        tableMap = data;
      }
    }
    tableMap ??= body.containsKey('id') || body.containsKey('table_number')
        ? body
        : null;
    if (tableMap == null) return null;
    return _toResolvedTable(tableMap);
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

  /// Highest `course_number` on the order (including empty shells).
  static int maxCourseNumberInDetail(Map<String, dynamic> detail) {
    var maxNumber = 0;
    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List) return 0;
    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number > maxNumber) maxNumber = number;
      }
    }
    return maxNumber;
  }

  /// Course that can receive new suite lines / a Demande.
  ///
  /// After delete-suite the old follow-up course often remains as an **empty
  /// shell**. Prefer reusing a shell that still has a real server `id` so adds /
  /// Demande land on it — skipping it created a second empty course and Laravel
  /// rejected the PUT (`courses.N.items field is required`).
  static int resolveWritableSuivreCourseNumber(
    Map<String, dynamic> detail, {
    required int preferredCourseNumber,
  }) {
    if (preferredCourseNumber <= 0) {
      return maxCourseNumberInDetail(detail) + 1;
    }

    final existing = findCourseInOrderDetail(detail, preferredCourseNumber);
    if (existing == null) return preferredCourseNumber;

    if (_visibleItemCountInCourse(existing) <= 0) {
      // Reuse the preferred empty slot (even with id:0). Rebake/add attach
      // items so the PUT is valid; skipping to N+1 caused local/remote drift.
      return preferredCourseNumber;
    }
    if (_courseWasRequestedToKitchen(existing) &&
        !_courseNeedsKitchenSend(existing)) {
      return maxCourseNumberInDetail(detail) + 1;
    }
    return preferredCourseNumber;
  }

  /// Products shown before [sectionIndex]'s divider.
  static List<OrderDisplayEntry> productsAboveSection(
    List<OrderDisplayEntry> layout,
    int sectionIndex,
  ) {
    final above = <OrderDisplayEntry>[];
    for (final entry in layout) {
      if (entry.isSectionDivider && entry.sectionIndex == sectionIndex) break;
      if (entry.type == OrderDisplayEntryType.product) above.add(entry);
    }
    return above;
  }

  static List<OrderDisplayEntry> productsAbovePendingSuivre(
    List<OrderDisplayEntry> layout,
  ) {
    int? sectionIndex;
    for (var i = layout.length - 1; i >= 0; i--) {
      if (layout[i].type == OrderDisplayEntryType.suivreSeparator) {
        sectionIndex = layout[i].sectionIndex;
        break;
      }
    }
    if (sectionIndex == null || sectionIndex <= 0) return const [];
    return productsAboveSection(layout, sectionIndex);
  }

  static bool courseHoldsAnyMatchingLayoutProducts(
    Map<String, dynamic> detail, {
    required int courseNumber,
    required List<OrderDisplayEntry> layoutProducts,
  }) {
    if (courseNumber <= 0 || layoutProducts.isEmpty) return false;
    final course = findCourseInOrderDetail(detail, courseNumber);
    if (course == null) return false;
    final pool = <({Map<String, dynamic> item, int courseNumber})>[
      for (final item in _visibleItemsInStableAddOrder(course['items']))
        (item: item, courseNumber: courseNumber),
    ];
    if (pool.isEmpty) return false;
    for (final entry in layoutProducts) {
      if (_poolIndexForDisplayEntry(pool, entry) != null) return true;
    }
    return false;
  }

  /// Prefer a fresh course when the preferred one still holds lines shown
  /// above À SUIVRE (routing only — no item rewrite).
  static int resolveSuivreCourseAvoidingAboveCollision(
    Map<String, dynamic> detail, {
    required int preferredCourseNumber,
    required List<OrderDisplayEntry> layout,
    int? sectionIndex,
  }) {
    var preferred = preferredCourseNumber;
    if (preferred <= 0) {
      preferred = maxCourseNumberInDetail(detail) + 1;
    }
    final above = sectionIndex != null && sectionIndex > 0
        ? productsAboveSection(layout, sectionIndex)
        : productsAbovePendingSuivre(layout);
    if (above.isEmpty) return preferred;
    if (!courseHoldsAnyMatchingLayoutProducts(
      detail,
      courseNumber: preferred,
      layoutProducts: above,
    )) {
      return preferred;
    }
    return maxCourseNumberInDetail(detail) + 1;
  }

  /// Reparent items shown **above** the open À SUIVRE onto course 1 in-place.
  static ({Map<String, dynamic> detail, bool changed})
      alignAboveSuivreItemsOntoCourse1(
    Map<String, dynamic> orderDetail, {
    required List<OrderDisplayEntry> layoutHints,
  }) {
    final above = productsAbovePendingSuivre(layoutHints);
    if (above.isEmpty) return (detail: orderDetail, changed: false);

    final working = copyOrderDetail(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final seatOrders = working['seat_orders'];
    if (seatOrders is! List) return (detail: working, changed: false);

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      if ((seat['seat_number'] as num?)?.toInt() != seatNumber) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;

      Map<String, dynamic>? course1;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        if ((course['course_number'] as num?)?.toInt() == 1) {
          course1 = course;
          break;
        }
      }
      if (course1 == null) return (detail: working, changed: false);

      final pool = <({Map<String, dynamic> item, int courseNumber})>[];
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number <= 1) continue;
        for (final item in _visibleItemsInStableAddOrder(course['items'])) {
          pool.add((item: item, courseNumber: number));
        }
      }

      final moving = <Map<String, dynamic>>[];
      for (final entry in above) {
        final idx = _poolIndexForDisplayEntry(pool, entry);
        if (idx == null) continue;
        moving.add(Map<String, dynamic>.from(pool.removeAt(idx).item));
      }
      if (moving.isEmpty) return (detail: working, changed: false);

      final moveIds = <int>{
        for (final item in moving)
          if (((item['id'] as num?)?.toInt() ?? 0) > 0)
            (item['id'] as num).toInt(),
      };

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number <= 1) continue;
        final items = course['items'];
        if (items is! List) continue;
        final kept = <dynamic>[];
        for (final item in items) {
          if (item is! Map<String, dynamic>) {
            kept.add(item);
            continue;
          }
          if (item['status'] == 'cancelled') {
            kept.add(item);
            continue;
          }
          final id = (item['id'] as num?)?.toInt() ?? 0;
          if (id > 0 && moveIds.contains(id)) continue;
          kept.add(item);
        }
        course['items'] = kept;
      }

      final pendingKeys = <String>[
        for (final item in moving)
          if (((item['id'] as num?)?.toInt() ?? 0) <= 0)
            '${_apiItemProductName(item)}|${(item['qty'] as num?)?.toInt() ?? 1}',
      ];
      if (pendingKeys.isNotEmpty) {
        for (final course in courses) {
          if (course is! Map<String, dynamic>) continue;
          final number = (course['course_number'] as num?)?.toInt() ?? 0;
          if (number <= 1) continue;
          final items = course['items'];
          if (items is! List) continue;
          final kept = <dynamic>[];
          for (final item in items) {
            if (item is! Map<String, dynamic>) {
              kept.add(item);
              continue;
            }
            if (item['status'] == 'cancelled') {
              kept.add(item);
              continue;
            }
            final id = (item['id'] as num?)?.toInt() ?? 0;
            if (id > 0) {
              kept.add(item);
              continue;
            }
            final key =
                '${_apiItemProductName(item)}|${(item['qty'] as num?)?.toInt() ?? 1}';
            final pendingAt = pendingKeys.indexOf(key);
            if (pendingAt >= 0) {
              pendingKeys.removeAt(pendingAt);
              continue;
            }
            kept.add(item);
          }
          course['items'] = kept;
        }
      }

      final course1Id = _courseRecordId(course1) ?? 0;
      final course1Items = course1['items'];
      final dest = course1Items is List
          ? List<dynamic>.from(course1Items)
          : <dynamic>[];
      for (final item in moving) {
        if (course1Id > 0) item['course_id'] = course1Id;
        dest.add(item);
      }
      course1['items'] = dest;
      return (detail: working, changed: true);
    }

    return (detail: working, changed: false);
  }

  /// In-place move of suite lines onto [targetCourseNumber] (same item ids).
  static ({Map<String, dynamic> detail, bool changed})
      alignSuivreSectionItemsOntoCourse(
    Map<String, dynamic> orderDetail, {
    required List<OrderDisplayEntry> layout,
    required int sectionIndex,
    required int targetCourseNumber,
  }) {
    if (sectionIndex <= 0 || targetCourseNumber <= 0) {
      return (detail: orderDetail, changed: false);
    }
    final under = productEntriesUnderSection(layout, sectionIndex);
    if (under.isEmpty) return (detail: orderDetail, changed: false);
    if (suiteItemsFullyOnCourse(
      orderDetail,
      layout: layout,
      sectionIndex: sectionIndex,
      courseNumber: targetCourseNumber,
    )) {
      return (detail: orderDetail, changed: false);
    }

    final working = copyOrderDetail(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    _ensureCourseShellExists(
      working,
      seatNumber: seatNumber,
      courseNumber: targetCourseNumber,
    );

    final seatOrders = working['seat_orders'];
    if (seatOrders is! List) return (detail: working, changed: false);

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      if ((seat['seat_number'] as num?)?.toInt() != seatNumber) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;

      Map<String, dynamic>? targetCourse;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        if ((course['course_number'] as num?)?.toInt() == targetCourseNumber) {
          targetCourse = course;
          break;
        }
      }
      if (targetCourse == null) return (detail: working, changed: false);

      if (_courseWasRequestedToKitchen(targetCourse) &&
          !_courseNeedsKitchenSend(targetCourse) &&
          _visibleItemCountInCourse(targetCourse) > 0) {
        return (detail: working, changed: false);
      }

      final pool = <({Map<String, dynamic> item, int courseNumber})>[];
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number == targetCourseNumber) continue;
        if (_courseWasRequestedToKitchen(course) &&
            !_courseNeedsKitchenSend(course)) {
          continue;
        }
        for (final item in _visibleItemsInStableAddOrder(course['items'])) {
          pool.add((item: item, courseNumber: number));
        }
      }
      for (final entry in productsAboveSection(layout, sectionIndex)) {
        final idx = _poolIndexForDisplayEntry(pool, entry);
        if (idx != null) pool.removeAt(idx);
      }

      final moving = <Map<String, dynamic>>[];
      for (final entry in under) {
        final idx = _poolIndexForDisplayEntry(pool, entry);
        if (idx == null) continue;
        moving.add(Map<String, dynamic>.from(pool.removeAt(idx).item));
      }
      if (moving.isEmpty) return (detail: working, changed: false);

      final moveIds = <int>{
        for (final item in moving)
          if (((item['id'] as num?)?.toInt() ?? 0) > 0)
            (item['id'] as num).toInt(),
      };

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number == targetCourseNumber) continue;
        if (_courseWasRequestedToKitchen(course) &&
            !_courseNeedsKitchenSend(course)) {
          continue;
        }
        final items = course['items'];
        if (items is! List) continue;
        final kept = <dynamic>[];
        for (final item in items) {
          if (item is! Map<String, dynamic>) {
            kept.add(item);
            continue;
          }
          if (item['status'] == 'cancelled') {
            kept.add(item);
            continue;
          }
          final id = (item['id'] as num?)?.toInt() ?? 0;
          if (id > 0 && moveIds.contains(id)) continue;
          kept.add(item);
        }
        course['items'] = kept;
      }

      final targetId = _courseRecordId(targetCourse) ?? 0;
      final destItems = targetCourse['items'];
      final dest =
          destItems is List ? List<dynamic>.from(destItems) : <dynamic>[];
      for (final item in moving) {
        if (targetId > 0) item['course_id'] = targetId;
        dest.add(item);
      }
      targetCourse['items'] = dest;
      return (detail: working, changed: true);
    }

    return (detail: working, changed: false);
  }

  /// Align local multi-suite layout onto remote courses before Send All.
  static ({Map<String, dynamic> detail, bool changed})
      alignPendingSuivreLayoutOntoCourses(
    Map<String, dynamic> orderDetail, {
    required List<OrderDisplayEntry> layout,
  }) {
    if (layout.isEmpty) return (detail: orderDetail, changed: false);

    var working = orderDetail;
    var changed = false;

    if (layoutHasTrailingPendingSuivre(layout) ||
        layoutHasProductsUnderPendingSuivre(layout)) {
      final above = alignAboveSuivreItemsOntoCourse1(
        working,
        layoutHints: layout,
      );
      working = above.detail;
      if (above.changed) changed = true;
    }

    for (final entry in layout) {
      if (entry.type != OrderDisplayEntryType.suivreSeparator &&
          entry.type != OrderDisplayEntryType.demandeSeparator) {
        continue;
      }
      final sectionIndex = entry.sectionIndex ?? 0;
      if (sectionIndex <= 0) continue;
      if (productEntriesUnderSection(layout, sectionIndex).isEmpty) continue;

      final aboveCourse = entry.courseNumber ?? sectionIndex;
      final targetCourse = aboveCourse > 0 ? aboveCourse + 1 : sectionIndex + 1;
      final moved = alignSuivreSectionItemsOntoCourse(
        working,
        layout: layout,
        sectionIndex: sectionIndex,
        targetCourseNumber: targetCourse,
      );
      working = moved.detail;
      if (moved.changed) changed = true;
    }

    return (detail: working, changed: changed);
  }

  /// Product rows displayed under a given À SUIVRE / DEMANDÉE section.
  static List<OrderDisplayEntry> productEntriesUnderSection(
    List<OrderDisplayEntry> entries,
    int sectionIndex,
  ) {
    final under = <OrderDisplayEntry>[];
    var inSection = false;
    for (final entry in entries) {
      if (entry.isSectionDivider) {
        if (inSection) break;
        inSection = entry.sectionIndex == sectionIndex;
        continue;
      }
      if (!inSection) continue;
      if (entry.type == OrderDisplayEntryType.product) under.add(entry);
    }
    return under;
  }

  /// Display rows already grouped into course 1 + follow-up sections.
  static bool displayHasRealMultiCourseSections(
    List<OrderDisplayEntry> entries,
  ) {
    if (suivreSeparatorCount(entries) <= 0) return false;
    var hasFirstSectionProducts = false;
    var hasFollowUpSectionProducts = false;
    for (final entry in entries) {
      if (entry.type != OrderDisplayEntryType.product) continue;
      final section = entry.sectionIndex ?? 0;
      if (section <= 0) {
        hasFirstSectionProducts = true;
      } else {
        hasFollowUpSectionProducts = true;
      }
      if (hasFirstSectionProducts && hasFollowUpSectionProducts) return true;
    }
    return false;
  }

  /// True when [course] is after the earliest course that has visible items.
  static bool isFollowUpApiCourse(
    Map<String, dynamic> data,
    Map<String, dynamic> course,
  ) {
    final number = (course['course_number'] as num?)?.toInt() ?? 0;
    if (number <= 0) return false;
    final minWithItems = minCourseNumberWithVisibleItems(data);
    if (minWithItems <= 0) return number > 1;
    return number > minWithItems;
  }

  static int minCourseNumberWithVisibleItems(Map<String, dynamic> data) {
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return 0;

    var min = 1 << 30;
    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number <= 0 || _visibleItemCountInCourse(course) <= 0) continue;
        if (number < min) min = number;
      }
    }
    return min == (1 << 30) ? 0 : min;
  }

  /// Earliest course has items and at least one later course does too — real
  /// multi-course structure (not API parking everything on course 2+ only).
  static bool apiHasFirstCourseWithItemsAndFollowUps(
    Map<String, dynamic> data,
  ) {
    if (countFollowUpCoursesWithItems(data) <= 0) return false;

    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return false;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List || courses.isEmpty) continue;

      var minCourseNumber = 1 << 30;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number > 0 && number < minCourseNumber) {
          minCourseNumber = number;
        }
      }
      if (minCourseNumber == (1 << 30)) continue;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number != minCourseNumber) continue;
        if (_visibleItemCountInCourse(course) > 0) return true;
        break;
      }
    }
    return false;
  }

  /// Follow-up courses (after the first) that already contain visible items.
  static int countFollowUpCoursesWithItems(Map<String, dynamic> data) {
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return 0;

    var count = 0;
    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List || courses.isEmpty) continue;

      var minCourseNumber = 1 << 30;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number > 0 && number < minCourseNumber) {
          minCourseNumber = number;
        }
      }
      if (minCourseNumber == (1 << 30)) minCourseNumber = 1;

      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final number = (course['course_number'] as num?)?.toInt() ?? 0;
        if (number <= minCourseNumber) continue;
        if (_visibleItemCountInCourse(course) > 0) count++;
      }
    }
    return count;
  }

  static List<({Map<String, dynamic> item, int courseNumber})>
      _visibleItemsWithCourseNumbers(
    Map<String, dynamic> detail, {
    required int seatNumber,
  }) {
    final located = <({Map<String, dynamic> item, int courseNumber})>[];
    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List) return located;

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      if ((seat['seat_number'] as num?)?.toInt() != seatNumber) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        final courseNumber =
            (course['course_number'] as num?)?.toInt() ?? 0;
        for (final item in _visibleItemsInStableAddOrder(course['items'])) {
          located.add((item: item, courseNumber: courseNumber));
        }
      }
    }
    return located;
  }

  static ({Map<String, dynamic> item, int courseNumber})? _takeMatchedOrderItem(
    List<({Map<String, dynamic> item, int courseNumber})> remaining,
    OrderDisplayEntry entry,
  ) {
    final id = entry.itemId ?? 0;
    if (id > 0) {
      final byId = remaining.indexWhere(
        (row) => (row.item['id'] as num?)?.toInt() == id,
      );
      if (byId >= 0) return remaining.removeAt(byId);
    }
    final key = _productFingerprint(entry.product);
    if (key != null) {
      final byKey = remaining.indexWhere((row) {
        final product = orderProductFromItem(row.item);
        return _productFingerprint(product) == key;
      });
      if (byKey >= 0) return remaining.removeAt(byKey);
    }
    final name = entry.product?.name.trim().toUpperCase();
    if (name != null && name.isNotEmpty) {
      final byName = remaining.indexWhere(
        (row) => _apiItemProductName(row.item) == name,
      );
      if (byName >= 0) return remaining.removeAt(byName);
    }
    return null;
  }

  /// Course ids from items shown under a suite (ignores stale courseNumber+1).
  static List<int> extractRequestableCourseIdsForSuivreLayout(
    Map<String, dynamic> data, {
    required List<OrderDisplayEntry> layout,
    required int sectionIndex,
  }) {
    final under = productEntriesUnderSection(layout, sectionIndex);
    if (under.isEmpty) return const [];

    final above = <OrderDisplayEntry>[];
    for (final entry in layout) {
      if (entry.isSectionDivider && entry.sectionIndex == sectionIndex) break;
      if (entry.type == OrderDisplayEntryType.product) above.add(entry);
    }

    final seatNumber = resolveDefaultSeatNumber(data);
    final remaining = _visibleItemsWithCourseNumbers(
      data,
      seatNumber: seatNumber,
    );
    for (final entry in above) {
      _takeMatchedOrderItem(remaining, entry);
    }

    final underCourseNumbers = <int>{};
    final underItemIds = <int>{};
    for (final entry in under) {
      final match = _takeMatchedOrderItem(remaining, entry);
      if (match == null) continue;
      if (match.courseNumber > 0) underCourseNumbers.add(match.courseNumber);
      final id = (match.item['id'] as num?)?.toInt() ?? 0;
      if (id > 0) underItemIds.add(id);
    }
    if (underCourseNumbers.length != 1 || underItemIds.isEmpty) {
      return const [];
    }

    final courseNumber = underCourseNumbers.single;
    final course = findCourseInOrderDetail(data, courseNumber);
    if (course == null || !_courseNeedsKitchenSend(course)) return const [];

    // Only fire when that course holds solely the suite lines.
    final items = course['items'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        if (item['status'] == 'cancelled') continue;
        final id = (item['id'] as num?)?.toInt() ?? 0;
        if (id > 0 && !underItemIds.contains(id)) return const [];
      }
    }

    final courseId = _courseRecordId(course);
    return courseId != null ? [courseId] : const [];
  }

  static String? _apiItemProductName(Map<String, dynamic> item) {
    final product = item['product'];
    if (product is Map) {
      final name = product['name'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim().toUpperCase();
      }
    }
    return null;
  }

  static int? _poolIndexForDisplayEntry(
    List<({Map<String, dynamic> item, int courseNumber})> pool,
    OrderDisplayEntry entry,
  ) {
    final id = entry.itemId ?? 0;
    if (id > 0) {
      final byId = pool.indexWhere(
        (row) => (row.item['id'] as num?)?.toInt() == id,
      );
      if (byId >= 0) return byId;
    }
    final key = _productFingerprint(entry.product);
    if (key != null) {
      final byKey = pool.indexWhere((row) {
        final product = orderProductFromItem(row.item);
        return _productFingerprint(product) == key;
      });
      if (byKey >= 0) return byKey;
    }
    final name = entry.product?.name.trim().toUpperCase();
    if (name != null && name.isNotEmpty) {
      final byName = pool.indexWhere(
        (row) => _apiItemProductName(row.item) == name,
      );
      if (byName >= 0) return byName;
    }
    return null;
  }

  /// True when every suite line in [layout] already sits on [courseNumber].
  static bool suiteItemsFullyOnCourse(
    Map<String, dynamic> data, {
    required List<OrderDisplayEntry> layout,
    required int sectionIndex,
    required int courseNumber,
  }) {
    final under = productEntriesUnderSection(layout, sectionIndex);
    if (under.isEmpty) return false;

    final seatNumber = resolveDefaultSeatNumber(data);
    final pool = _visibleItemsWithCourseNumbers(
      data,
      seatNumber: seatNumber,
    ).where((row) => row.courseNumber == courseNumber).toList();

    var matched = 0;
    final remaining =
        List<({Map<String, dynamic> item, int courseNumber})>.from(pool);
    for (final entry in under) {
      final idx = _poolIndexForDisplayEntry(remaining, entry);
      if (idx == null) continue;
      remaining.removeAt(idx);
      matched++;
    }
    return matched >= under.length;
  }

  /// Course record id for [courseNumber] (falls back to item.course_id).
  static int? courseRecordIdForNumber(
    Map<String, dynamic> data,
    int courseNumber,
  ) {
    if (courseNumber <= 0) return null;
    final course = findCourseInOrderDetail(data, courseNumber);
    if (course == null) return null;
    return _courseRecordId(course);
  }

  /// Cancel suite lines and recreate them on [targetCourseNumber].
  ///
  /// Needed when the UI shows items under À SUIVRE but the API still has them
  /// on course 1 while Demande targets an empty follow-up shell.
  ///
  /// Matching is **count-based** (first N stay above, next M move) — never
  /// name-match, or duplicate products above/below À SUIVRE steal the wrong
  /// rows and Demande still sees an empty shell.
  static ({Map<String, dynamic> detail, bool changed})
      rebakeSuivreSectionOntoCourse(
    Map<String, dynamic> orderDetail, {
    required List<OrderDisplayEntry> layout,
    required int sectionIndex,
    required int targetCourseNumber,
  }) {
    if (sectionIndex <= 0 || targetCourseNumber <= 0) {
      return (detail: orderDetail, changed: false);
    }

    final under = productEntriesUnderSection(layout, sectionIndex);
    if (under.isEmpty) return (detail: orderDetail, changed: false);

    final above = <OrderDisplayEntry>[];
    for (final entry in layout) {
      if (entry.isSectionDivider && entry.sectionIndex == sectionIndex) break;
      if (entry.type == OrderDisplayEntryType.product) above.add(entry);
    }

    final working = copyOrderDetail(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final allVisible = _visibleItemsWithCourseNumbers(
      working,
      seatNumber: seatNumber,
    );
    if (allVisible.isEmpty) return (detail: working, changed: false);

    // Pin "above" by id / fingerprint / name only — never steal blindly.
    final pool = List<({Map<String, dynamic> item, int courseNumber})>.from(
      allVisible,
    );
    for (final entry in above) {
      final idx = _poolIndexForDisplayEntry(pool, entry);
      if (idx == null) continue;
      pool.removeAt(idx);
    }

    // Suite rows: ONLY explicitly matched lines. Never take random pool-tail
    // items — that cancelled already-DEMANDÉE products and emptied sections.
    final recipes = <Map<String, dynamic>>[];
    final cancelIds = <int>{};

    void consider(({Map<String, dynamic> item, int courseNumber}) match) {
      if (match.courseNumber == targetCourseNumber) return;
      // Never touch lines that already live on a fully sent kitchen course.
      final sourceCourse =
          findCourseInOrderDetail(working, match.courseNumber);
      if (sourceCourse != null &&
          _courseWasRequestedToKitchen(sourceCourse) &&
          !_courseNeedsKitchenSend(sourceCourse)) {
        return;
      }
      final id = (match.item['id'] as num?)?.toInt() ?? 0;
      if (id > 0) cancelIds.add(id);
      recipes.add(Map<String, dynamic>.from(match.item));
    }

    for (final entry in under) {
      final idx = _poolIndexForDisplayEntry(pool, entry);
      if (idx == null) continue;
      consider(pool.removeAt(idx));
    }

    if (recipes.isEmpty) return (detail: working, changed: false);

    for (final id in cancelIds) {
      cancelOrderLineByItemId(working, id);
    }

    // Ensure target course exists. Only reopen empty shells — never clear
    // requested_at on a course that already has visible sent/unsent mix wrongly.
    var targetCourse = findCourseInOrderDetail(working, targetCourseNumber);
    if (targetCourse == null) {
      final seatOrders = working['seat_orders'];
      if (seatOrders is List) {
        for (final seat in seatOrders) {
          if (seat is! Map<String, dynamic>) continue;
          if ((seat['seat_number'] as num?)?.toInt() != seatNumber) continue;
          final courses = seat['courses'];
          final list = courses is List
              ? courses.whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[];
          list.add({
            'id': 0,
            'course_number': targetCourseNumber,
            'seat_number': seatNumber,
            'status': 'to_be_continued',
            'items': <dynamic>[],
          });
          seat['courses'] = list;
          break;
        }
      }
      targetCourse = findCourseInOrderDetail(working, targetCourseNumber);
    } else if (_visibleItemCountInCourse(targetCourse) <= 0) {
      // Empty leftover shell after suite delete — allow placing suite lines.
      targetCourse['status'] = 'to_be_continued';
      targetCourse.remove('requested_at');
    }

    final targetCourseId =
        targetCourse == null ? 0 : (_courseRecordId(targetCourse) ?? 0);

    for (final item in recipes) {
      final newItem = _buildNewItemPayload(
        seatNumber: seatNumber,
        courseId: targetCourseId,
        productId: _itemProductId(item),
        qty: (item['qty'] as num?)?.toInt() ?? 1,
        subTotal: _parseMoney(item['sub_total']),
        status: 'to_be_continued',
        comment: item['comment'] as String? ?? '',
        menuSelections: item['menu_selections'] is List
            ? (item['menu_selections'] as List)
                .whereType<Map<String, dynamic>>()
                .toList()
            : const [],
        isStillMenuMissing: item['is_still_menu_missing'] == true,
        forCreate: false,
      );
      // Keep product name for local matching until the next GET fills ids.
      final sourceProduct = item['product'];
      if (sourceProduct is Map) {
        final product = Map<String, dynamic>.from(
          newItem['product'] is Map
              ? newItem['product'] as Map
              : <String, dynamic>{},
        );
        product['id'] = _itemProductId(item);
        final name = sourceProduct['name'];
        if (name is String && name.trim().isNotEmpty) {
          product['name'] = name;
        }
        newItem['product'] = product;
      }
      _appendItemToSeatOrders(
        working,
        seatNumber: seatNumber,
        courseNumber: targetCourseNumber,
        newItem: newItem,
      );
    }

    return (detail: working, changed: true);
  }

  /// Ensures suite lines from [layout] exist on [targetCourseNumber].
  ///
  /// 1) Moves matching remote rows (rebake)
  /// 2) Creates missing lines from product ids found on the order / resolver
  ///
  /// This is what Demande needs when the UI has items under À SUIVRE but the
  /// API course shell is still empty (local/remote drift after recreate).
  static ({Map<String, dynamic> detail, bool changed})
      ensureSuivreSectionOnCourse(
    Map<String, dynamic> orderDetail, {
    required List<OrderDisplayEntry> layout,
    required int sectionIndex,
    required int targetCourseNumber,
    int? Function(String productName)? resolveProductId,
    double? Function(String productName)? resolveUnitPrice,
  }) {
    if (sectionIndex <= 0 || targetCourseNumber <= 0) {
      return (detail: orderDetail, changed: false);
    }

    final under = productEntriesUnderSection(layout, sectionIndex);
    if (under.isEmpty) return (detail: orderDetail, changed: false);

    var working = copyOrderDetail(orderDetail);
    var changed = false;

    final rebaked = rebakeSuivreSectionOntoCourse(
      working,
      layout: layout,
      sectionIndex: sectionIndex,
      targetCourseNumber: targetCourseNumber,
    );
    if (rebaked.changed) {
      working = rebaked.detail;
      changed = true;
    }

    if (suiteItemsFullyOnCourse(
      working,
      layout: layout,
      sectionIndex: sectionIndex,
      courseNumber: targetCourseNumber,
    )) {
      return (detail: working, changed: changed);
    }

    final seatNumber = resolveDefaultSeatNumber(working);
    _ensureCourseShellExists(
      working,
      seatNumber: seatNumber,
      courseNumber: targetCourseNumber,
    );

    final targetCourse = findCourseInOrderDetail(working, targetCourseNumber);
    final targetCourseId =
        targetCourse == null ? 0 : (_courseRecordId(targetCourse) ?? 0);

    // How many suite slots already filled on the target course.
    final onTarget = _visibleItemsWithCourseNumbers(
      working,
      seatNumber: seatNumber,
    ).where((row) => row.courseNumber == targetCourseNumber).toList();
    final remainingOnTarget =
        List<({Map<String, dynamic> item, int courseNumber})>.from(onTarget);

    final missing = <OrderDisplayEntry>[];
    for (final entry in under) {
      final idx = _poolIndexForDisplayEntry(remainingOnTarget, entry);
      if (idx != null) {
        remainingOnTarget.removeAt(idx);
        continue;
      }
      missing.add(entry);
    }

    if (missing.isEmpty) {
      return (detail: working, changed: changed);
    }

    // Try moving unmatched suite lines from unsent courses by name (safe).
    final movable = _visibleItemsWithCourseNumbers(
      working,
      seatNumber: seatNumber,
    ).where((row) {
      if (row.courseNumber == targetCourseNumber) return false;
      final course = findCourseInOrderDetail(working, row.courseNumber);
      if (course == null) return true;
      // Do not touch fully-sent DEMANDÉE courses.
      if (_courseWasRequestedToKitchen(course) &&
          !_courseNeedsKitchenSend(course)) {
        return false;
      }
      return true;
    }).toList();

    final stillMissing = <OrderDisplayEntry>[];
    for (final entry in missing) {
      final idx = _poolIndexForDisplayEntry(movable, entry);
      if (idx == null) {
        stillMissing.add(entry);
        continue;
      }
      final match = movable.removeAt(idx);
      final id = (match.item['id'] as num?)?.toInt() ?? 0;
      if (id > 0) cancelOrderLineByItemId(working, id);
      final newItem = _buildNewItemPayload(
        seatNumber: seatNumber,
        courseId: targetCourseId > 0 ? targetCourseId : 0,
        productId: _itemProductId(match.item),
        qty: (match.item['qty'] as num?)?.toInt() ?? 1,
        subTotal: _parseMoney(match.item['sub_total']),
        status: 'to_be_continued',
        comment: match.item['comment'] as String? ?? '',
        forCreate: false,
      );
      final sourceProduct = match.item['product'];
      if (sourceProduct is Map) {
        final product = Map<String, dynamic>.from(
          newItem['product'] is Map
              ? newItem['product'] as Map
              : <String, dynamic>{},
        );
        product['id'] = _itemProductId(match.item);
        final name = sourceProduct['name'];
        if (name is String && name.trim().isNotEmpty) {
          product['name'] = name;
        }
        newItem['product'] = product;
      }
      _appendItemToSeatOrders(
        working,
        seatNumber: seatNumber,
        courseNumber: targetCourseNumber,
        newItem: newItem,
      );
      changed = true;
    }

    // Last resort: create from catalog — never cancel other courses' lines.
    for (final entry in stillMissing) {
      final name = entry.product?.name.trim() ?? '';
      final productId = _findProductIdInOrderDetail(working, name) ??
          resolveProductId?.call(name) ??
          0;
      if (productId <= 0) continue;

      final qty = int.tryParse(entry.product?.quantity ?? '1') ?? 1;
      final unit = resolveUnitPrice?.call(name) ??
          _parseMoney(entry.product?.price);
      final newItem = _buildNewItemPayload(
        seatNumber: seatNumber,
        courseId: targetCourseId > 0 ? targetCourseId : 0,
        productId: productId,
        qty: qty,
        subTotal: unit * qty,
        status: 'to_be_continued',
        comment: entry.product?.message ?? '',
        forCreate: false,
      );
      if (name.isNotEmpty) {
        final product = Map<String, dynamic>.from(
          newItem['product'] is Map
              ? newItem['product'] as Map
              : <String, dynamic>{},
        );
        product['id'] = productId;
        product['name'] = name;
        newItem['product'] = product;
      }
      _appendItemToSeatOrders(
        working,
        seatNumber: seatNumber,
        courseNumber: targetCourseNumber,
        newItem: newItem,
      );
      changed = true;
    }

    return (detail: working, changed: changed);
  }

  static void _ensureCourseShellExists(
    Map<String, dynamic> detail, {
    required int seatNumber,
    required int courseNumber,
  }) {
    if (findCourseInOrderDetail(detail, courseNumber) != null) return;

    final seatOrders = detail['seat_orders'];
    if (seatOrders is! List) return;
    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      if ((seat['seat_number'] as num?)?.toInt() != seatNumber) continue;
      final courses = seat['courses'];
      final list = courses is List
          ? courses.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      list.add({
        'id': 0,
        'course_number': courseNumber,
        'seat_number': seatNumber,
        'status': 'to_be_continued',
        'items': <dynamic>[],
      });
      seat['courses'] = list;
      return;
    }
  }

  /// Find a product id by name anywhere on the order (including cancelled).
  static int? _findProductIdInOrderDetail(
    Map<String, dynamic> detail,
    String productName,
  ) {
    final needle = productName.trim().toUpperCase();
    if (needle.isEmpty) return null;

    final seatOrders = detail['seat_orders'];
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
          if (_apiItemProductName(item) != needle) continue;
          final id = _itemProductId(item);
          if (id > 0) return id;
        }
      }
    }
    return null;
  }

  /// Summarize courses for Demande debug logs.
  static String describeCourseContents(Map<String, dynamic> detail) {
    final buffer = StringBuffer();
    final seatNumber = resolveDefaultSeatNumber(detail);
    final courses = _coursesForSeat(detail, seatNumber: seatNumber);
    for (final course in courses) {
      final number = (course['course_number'] as num?)?.toInt() ?? 0;
      final id = _courseRecordId(course) ?? 0;
      final names = <String>[];
      final items = course['items'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          if (item['status'] == 'cancelled') continue;
          names.add(_apiItemProductName(item) ?? '?');
        }
      }
      buffer.writeln(
        '  course=$number id=$id items=${names.isEmpty ? '—' : names.join(',')}',
      );
    }
    return buffer.toString().trimRight();
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

    if (_courseNeedsKitchenSend(course)) {
      if (_courseRecordId(course) == null) {
        return 'Identifiant du service introuvable.';
      }
      return 'Aucun service à demander pour cette section.';
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

    if (_courseRecordId(course) == null) {
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
        // Allow re-demande when a shell still has unsent lines.
        if (!_courseNeedsKitchenSend(course)) continue;

        if (requireKnownStatus && !_courseWasRequestedToKitchen(course)) {
          final status = course['status'] as String?;
          if (status != null &&
              status != 'to_be_continued' &&
              status != 'pending' &&
              status != 'in_progress') {
            continue;
          }
        }

        final courseIdInt = _courseRecordId(course);
        if (courseIdInt != null) return courseIdInt;
      }
    }

    return null;
  }

  /// Course ids to fire to the kitchen (send / envoyer).
  ///
  /// Returns every course that still needs a kitchen send. When [layoutHints]
  /// is set, also include courses for each pending À SUIVRE section.
  static List<int> extractKitchenSendCourseIds(
    Map<String, dynamic> data, {
    List<OrderDisplayEntry>? layoutHints,
  }) {
    final ids = <int>{};
    final seatOrders = data['seat_orders'];
    if (seatOrders is List) {
      for (final seat in seatOrders) {
        if (seat is! Map<String, dynamic>) continue;
        final courses = seat['courses'];
        if (courses is! List) continue;

        for (final course in courses) {
          if (course is! Map<String, dynamic>) continue;
          if (!_courseNeedsKitchenSend(course)) continue;

          final courseIdInt = _courseRecordId(course);
          if (courseIdInt != null) ids.add(courseIdInt);
        }
      }
    }

    if (layoutHints != null && layoutHints.isNotEmpty) {
      ids.addAll(
        _kitchenSendCourseIdsFromPendingSuivreLayout(data, layoutHints),
      );
    }

    if (ids.isNotEmpty) return ids.toList();
    return _collectAllUnrequestedCourseIds(data);
  }

  static Set<int> _kitchenSendCourseIdsFromPendingSuivreLayout(
    Map<String, dynamic> data,
    List<OrderDisplayEntry> layout,
  ) {
    final ids = <int>{};
    for (final entry in layout) {
      if (entry.type != OrderDisplayEntryType.suivreSeparator) continue;
      final sectionIndex = entry.sectionIndex ?? 0;
      if (sectionIndex <= 0) continue;
      if (productEntriesUnderSection(layout, sectionIndex).isEmpty) continue;

      final fromLayout = extractRequestableCourseIdsForSuivreLayout(
        data,
        layout: layout,
        sectionIndex: sectionIndex,
      );
      ids.addAll(fromLayout);
      if (fromLayout.isNotEmpty) continue;

      final courseNumbers = _resolveCourseNumbersForLayoutSection(
        data,
        layout,
        sectionIndex: sectionIndex,
        products: productEntriesUnderSection(layout, sectionIndex),
      );
      for (final number in courseNumbers) {
        final course = findCourseInOrderDetail(data, number);
        if (course == null || !_courseNeedsKitchenSend(course)) continue;
        final id = _courseRecordId(course);
        if (id != null) ids.add(id);
      }
    }
    return ids;
  }

  static List<int> _collectAllUnrequestedCourseIds(Map<String, dynamic> data) {
    final matches = <({int id, int number})>[];
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

        final courseIdInt = _courseRecordId(course);
        if (courseIdInt == null) continue;
        final courseNumber = (course['course_number'] as num?)?.toInt() ?? 0;
        matches.add((id: courseIdInt, number: courseNumber));
      }
    }

    matches.sort((a, b) => a.number.compareTo(b.number));
    return [for (final m in matches) m.id];
  }

  /// Courses that must be sent to the kitchen before POST /api/orders/:id/pay.
  ///
  /// Includes courses that were already demanded but later received new lines
  /// (common after DEMANDÉE when waiter adds more items).
  static List<int> extractCourseIdsPendingKitchenSendBeforePayment(
    Map<String, dynamic> data,
  ) {
    final ids = <int>{};

    final seatOrders = data['seat_orders'];
    if (seatOrders is List) {
      for (final seat in seatOrders) {
        if (seat is! Map<String, dynamic>) continue;
        final courses = seat['courses'];
        if (courses is! List) continue;

        for (final course in courses) {
          if (course is! Map<String, dynamic>) continue;
          if (!_courseNeedsKitchenSend(course)) continue;
          final courseIdInt = _courseRecordId(course);
          if (courseIdInt != null) ids.add(courseIdInt);
        }
      }
    }

    if (ids.isNotEmpty) return ids.toList();
    return _collectAllUnrequestedCourseIds(data);
  }

  /// Every course with visible items — last-resort fire before payment.
  static List<int> extractAllVisibleCourseIds(Map<String, dynamic> data) {
    final ids = <int>{};
    final seatOrders = data['seat_orders'];
    if (seatOrders is! List) return const [];

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map<String, dynamic>) continue;
        if (_visibleItemCountInCourse(course) <= 0) continue;
        final id = _courseRecordId(course);
        if (id != null) ids.add(id);
      }
    }
    return ids.toList();
  }

  static int? _parsePositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value.toInt() > 0) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  static int? _courseRecordId(Map<String, dynamic> course) {
    final direct = _parsePositiveInt(course['id']);
    if (direct != null) return direct;

    // New courses often return id:0 on the shell while items carry course_id.
    final items = course['items'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        if (item['status'] == 'cancelled') continue;
        final fromItem = _parsePositiveInt(item['course_id']);
        if (fromItem != null) return fromItem;
      }
    }
    return null;
  }

  /// Whether this course still has lines the kitchen has not been asked for.
  static bool _courseNeedsKitchenSend(Map<String, dynamic> course) {
    if (_visibleItemCountInCourse(course) <= 0) return false;

    if (!_courseWasRequestedToKitchen(course)) return true;

    // Course was demanded earlier, but new items may have been added after.
    final requestedAt = DateTime.tryParse(
      course['requested_at']?.toString() ?? '',
    );
    final items = course['items'];
    if (items is! List) return false;
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      if (_itemNeedsKitchenSend(item, courseRequestedAt: requestedAt)) {
        return true;
      }
    }
    return false;
  }

  static bool _itemNeedsKitchenSend(
    Map<String, dynamic> item, {
    DateTime? courseRequestedAt,
  }) {
    final status = item['status']?.toString().toLowerCase();
    if (status == 'cancelled') return false;

    final sentAt = item['requested_at'] ??
        item['sent_at'] ??
        item['fired_at'] ??
        item['printed_at'];
    if (sentAt != null && sentAt.toString().trim().isNotEmpty) return false;

    const alreadySent = {
      'sent',
      'requested',
      'preparing',
      'prepared',
      'ready',
      'served',
      'completed',
      'done',
      'delivered',
    };
    if (status != null && alreadySent.contains(status)) return false;

    const unsent = {
      'pending',
      'in_progress',
      'to_be_continued',
      'draft',
      'open',
      'new',
      'created',
    };
    if (status != null && unsent.contains(status)) return true;

    // Item added after the course was demanded → must be re-fired.
    if (courseRequestedAt != null) {
      final created = DateTime.tryParse(item['created_at']?.toString() ?? '');
      if (created != null && created.isAfter(courseRequestedAt)) return true;
      // Present at demande time with no unsent marker → treat as already sent.
      return false;
    }

    // Course never demanded: any visible line still needs a send.
    return true;
  }

  static bool requiresKitchenSendBeforePayment(Map<String, dynamic> data) {
    return extractCourseIdsPendingKitchenSendBeforePayment(data).isNotEmpty;
  }

  static bool isSendBeforePaymentError(ApiException error) {
    final message = error.message.toLowerCase();
    return (message.contains('envoyer') &&
            (message.contains('payer') || message.contains('paiement'))) ||
        (message.contains('send') && message.contains('before') && message.contains('pay'));
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
  ///
  /// Structure only — never trust stale `product.courseNumber` from the API.
  /// - No divider → course 1
  /// - [selectedSectionIndex] when set → course under that À SUIVRE row
  /// - Otherwise last divider → course above + 1
  static int? resolveAppendCourseNumberFromLayout(
    List<OrderDisplayEntry> layoutHints, {
    int? selectedSectionIndex,
  }) {
    if (layoutHints.isEmpty) return null;

    OrderDisplayEntry? targetDivider;
    if (selectedSectionIndex != null && selectedSectionIndex > 0) {
      for (final entry in layoutHints) {
        if (entry.isSectionDivider &&
            entry.sectionIndex == selectedSectionIndex) {
          targetDivider = entry;
          break;
        }
      }
    }

    if (targetDivider == null) {
      for (final entry in layoutHints) {
        if (entry.isSectionDivider) targetDivider = entry;
      }
    }

    if (targetDivider == null) {
      return 1;
    }

    final above = targetDivider.courseNumber;
    if (above != null && above > 0) return above + 1;

    final section = targetDivider.sectionIndex ?? 1;
    return section >= 1 ? section + 1 : 2;
  }

  /// Course that should receive newly added items (latest open course).
  static ({int? id, int number}) resolveAppendCourse(
    Map<String, dynamic> detail, {
    int? seatNumber,
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
    int? selectedSuivreSectionIndex,
  }) {
    final targetSeat = seatNumber ?? resolveDefaultSeatNumber(detail);
    final courses = _coursesForSeat(detail, seatNumber: targetSeat);
    if (courses.isEmpty) {
      return (id: null, number: 1);
    }

    if (layoutHints != null && layoutHints.isNotEmpty) {
      final fromLayout = resolveAppendCourseNumberFromLayout(
        layoutHints,
        selectedSectionIndex: selectedSuivreSectionIndex,
      );
      if (fromLayout != null && fromLayout > 0) {
        var writable = resolveWritableSuivreCourseNumber(
          detail,
          preferredCourseNumber: fromLayout,
        );
        if (layoutHasTrailingPendingSuivre(layoutHints) ||
            layoutHasProductsUnderPendingSuivre(layoutHints)) {
          writable = resolveSuivreCourseAvoidingAboveCollision(
            detail,
            preferredCourseNumber: writable,
            layout: layoutHints,
          );
        }
        return _resolveCourseTarget(courses, writable);
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

    // Open next course only when the waiter left a trailing À SUIVRE.
    final manualSuiteOpen = layoutHasTrailingPendingSuivre(layoutHints) ||
        (layoutHints == null &&
            suivreSectionCount > 0 &&
            suivreSectionCount >= coursesWithItems);

    if (manualSuiteOpen &&
        suivreSectionCount > 0 &&
        suivreSectionCount >= coursesWithItems) {
      final nextNumber = latestWithItemsNumber > 0
          ? latestWithItemsNumber + 1
          : maxCourseNumber + 1;
      return _resolveCourseTarget(courses, nextNumber);
    }

    // Prefer an empty follow-up course only with an open trailing À SUIVRE.
    if (manualSuiteOpen) {
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
    }

    if (latestCourseWithItems != null) {
      // Keep appending to the latest course even after DEMANDÉE.
      return (
        id: (latestCourseWithItems['id'] as num?)?.toInt(),
        number: latestWithItemsNumber,
      );
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
    int? selectedSuivreSectionIndex,
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
      selectedSuivreSectionIndex: selectedSuivreSectionIndex,
    );
  }

  static Map<String, dynamic> setLineQuantityAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
    required int qty,
  }) {
    // Mutates [orderDetail] in place — caller should pass a deep copy.
    _mutateVisibleLineAtIndex(orderDetail, lineIndex, (item) {
      if (qty <= 0) {
        item['status'] = 'cancelled';
        return;
      }

      final unitPrice = _itemUnitPrice(item);
      item['qty'] = qty;
      item['sub_total'] = unitPrice * qty;
    });
    return buildOrderUpdatePayload(orderDetail, keepOpenWhenEmpty: true);
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
    // Remove the À SUIVRE / DEMANDÉE row, then its products.
    result.removeAt(dividerIndex);
    while (dividerIndex < result.length &&
        !result[dividerIndex].isSectionDivider) {
      result.removeAt(dividerIndex);
    }
    return reindexDisplayEntries(result);
  }

  /// Rebuilds display rows using a trimmed suivre layout and fresh API products.
  ///
  /// Preserves divider types from [trimmedLayout] (DEMANDÉE stays DEMANDÉE).
  /// Never rebuilds every divider as À SUIVRE.
  static List<OrderDisplayEntry> applyTrimmedSuivreLayout({
    required List<OrderProduct> products,
    required List<OrderDisplayEntry> trimmedLayout,
  }) {
    if (products.isEmpty) return const [];

    final dividers = <({int splitAt, OrderDisplayEntry divider})>[];
    var seenProducts = 0;
    for (final entry in trimmedLayout) {
      if (entry.isSectionDivider) {
        dividers.add((splitAt: seenProducts, divider: entry));
      } else if (entry.type == OrderDisplayEntryType.product) {
        seenProducts++;
      }
    }

    final result = <OrderDisplayEntry>[];
    var lineIndex = 0;
    var dividerIdx = 0;
    var activeSection = 0;
    int? activeCourse;

    void insertDueDividers(int productIndex) {
      while (dividerIdx < dividers.length &&
          dividers[dividerIdx].splitAt == productIndex) {
        final divider = dividers[dividerIdx].divider;
        result.add(divider);
        activeSection = divider.sectionIndex ?? activeSection;
        activeCourse = divider.courseNumber != null
            ? (divider.courseNumber! + 1)
            : activeCourse;
        dividerIdx++;
      }
    }

    for (var i = 0; i < products.length; i++) {
      insertDueDividers(i);
      // Prefer course/section from the matching trimmed product slot.
      var sectionIndex = activeSection;
      int? courseNumber = activeCourse;
      var trimmedProductIdx = 0;
      for (final entry in trimmedLayout) {
        if (entry.type != OrderDisplayEntryType.product) continue;
        if (trimmedProductIdx == i) {
          sectionIndex = entry.sectionIndex ?? sectionIndex;
          courseNumber = entry.courseNumber ?? courseNumber;
          break;
        }
        trimmedProductIdx++;
      }

      result.add(
        OrderDisplayEntry.product(
          product: products[i],
          lineIndex: lineIndex++,
          sectionIndex: sectionIndex,
          courseNumber: courseNumber,
        ),
      );
    }

    // Keep remaining DEMANDÉE dividers; drop empty trailing À SUIVRE.
    while (dividerIdx < dividers.length) {
      final divider = dividers[dividerIdx].divider;
      if (divider.type == OrderDisplayEntryType.demandeSeparator) {
        result.add(divider);
      }
      dividerIdx++;
    }

    return reindexDisplayEntries(result);
  }

  /// Cancels every visible line (used to clear auto-added create defaults).
  static const emptyCreateSeedCancelReason =
      'Commande vide — article automatique annulé';

  /// Builds the server `cancel_reason` from the table-delete note dialog.
  static String buildCancelReason({
    required String note,
    required String reportedTo,
  }) {
    final trimmedNote = note.trim();
    final trimmedTo = reportedTo.trim();
    if (trimmedNote.isEmpty && trimmedTo.isEmpty) {
      return emptyCreateSeedCancelReason;
    }
    if (trimmedNote.isEmpty) return 'Signalé par $trimmedTo';
    if (trimmedTo.isEmpty) return trimmedNote;
    return '$trimmedNote — signalé par $trimmedTo';
  }

  /// True when the ticket still has ONLY the empty-create seed line(s).
  static bool hasOnlyEmptyCreateSeed(
    Map<String, dynamic> orderDetail, {
    int? seedProductId,
  }) {
    if (orderDetailHasNoVisibleItems(orderDetail)) return false;

    if (seedProductId != null && seedProductId > 0) {
      final seatOrders = orderDetail['seat_orders'];
      if (seatOrders is List) {
        var sawSeed = false;
        var sawOther = false;
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
              if (_itemProductId(item) == seedProductId) {
                sawSeed = true;
              } else {
                sawOther = true;
              }
            }
          }
        }
        if (sawSeed && !sawOther) return true;
      }
      // Known seed id was planted but the API may use a different product —
      // fall through to the free single-line heuristic.
    }

    // Fallback: single free simple line left from create seed.
    // Offered lines also have sub_total 0 — they are NOT create-seed.
    if (countVisibleLineItems(orderDetail) != 1) return false;
    final item = firstVisibleItem(orderDetail);
    if (item == null) return false;
    if (_isOfferedLineItem(item)) return false;
    if (!_isSimpleLineItem(item)) return false;
    return _parseMoney(item['sub_total']) <= 0.0001;
  }

  static bool _isOfferedLineItem(Map<String, dynamic> item) {
    if (item['is_offer'] == true ||
        item['is_offered'] == true ||
        item['offered'] == true) {
      return true;
    }
    final reason = item['offer_reason']?.toString().trim() ?? '';
    return reason.isNotEmpty;
  }

  /// True when the ticket has a non-cancelled line that is not create-seed.
  static bool hasRealNonSeedVisibleItems(
    Map<String, dynamic> orderDetail, {
    int? seedProductId,
  }) {
    if (orderDetailHasNoVisibleItems(orderDetail)) return false;
    if (hasOnlyEmptyCreateSeed(orderDetail, seedProductId: seedProductId)) {
      return false;
    }
    return true;
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

  /// Deep-copies JSON-like maps without `jsonEncode` (that path ANRs on large
  /// tickets when called on the UI isolate during rapid taps).
  static Map<String, dynamic> _deepCopyOrderMap(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(
      source.map((key, value) => MapEntry(key, _deepCopyJsonValue(value))),
    );
  }

  static dynamic _deepCopyJsonValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map(
          (key, nested) => MapEntry(key.toString(), _deepCopyJsonValue(nested)),
        ),
      );
    }
    if (value is List) {
      return [for (final item in value) _deepCopyJsonValue(item)];
    }
    return value;
  }

  /// Fast optimistic append for catalog taps — session lists only, no API-detail
  /// simulation (that path is too heavy for the UI isolate).
  static SessionOrder predictAppendSimpleProductFast({
    required SessionOrder current,
    required String productName,
    required double unitPrice,
    int qty = 1,
    int? selectedSuivreSectionIndex,
  }) {
    return _predictAppendOnSessionOrder(
      current: current,
      productName: productName,
      unitPrice: unitPrice,
      qty: qty,
      selectedSuivreSectionIndex: selectedSuivreSectionIndex,
    );
  }

  static Map<String, dynamic> cancelOrderLinesAtIndices({
    required Map<String, dynamic> orderDetail,
    required Set<int> lineIndices,
  }) {
    if (lineIndices.isEmpty) {
      return buildOrderUpdatePayload(orderDetail);
    }

    // Mutates [orderDetail] in place — caller should pass a deep copy.
    var currentIndex = 0;
    final seatOrders = orderDetail['seat_orders'];
    if (seatOrders is! List) {
      return buildOrderUpdatePayload(orderDetail);
    }

    for (final seat in seatOrders) {
      if (seat is! Map<String, dynamic>) continue;
      final courses = _sortedCoursesList(seat['courses']);

      for (final course in courses) {
        for (final item in _visibleItemsInStableAddOrder(course['items'])) {
          if (lineIndices.contains(currentIndex)) {
            item['status'] = 'cancelled';
          }
          currentIndex++;
        }
      }
    }

    return buildOrderUpdatePayload(orderDetail, keepOpenWhenEmpty: true);
  }

  static Map<String, dynamic> cancelOrderLineAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
  }) {
    // Mutates [orderDetail] in place — caller should pass a deep copy.
    _mutateVisibleLineAtIndex(orderDetail, lineIndex, (item) {
      item['status'] = 'cancelled';
    });
    return buildOrderUpdatePayload(orderDetail, keepOpenWhenEmpty: true);
  }

  /// Cancels a visible line by backend item id. Returns `false` if already gone.
  static bool cancelOrderLineByItemId(
    Map<String, dynamic> orderDetail,
    int itemId,
  ) {
    if (itemId <= 0) return false;
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
          final id = (item['id'] as num?)?.toInt() ?? 0;
          if (id != itemId) continue;
          item['status'] = 'cancelled';
          return true;
        }
      }
    }
    return false;
  }

  static Map<String, dynamic> adjustLineQuantityAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
    required int delta,
  }) {
    // Mutates [orderDetail] in place — caller should pass a deep copy.
    _mutateVisibleLineAtIndex(orderDetail, lineIndex, (item) {
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
    return buildOrderUpdatePayload(orderDetail, keepOpenWhenEmpty: true);
  }

  static Map<String, dynamic> applyOfferAtLineIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
  }) {
    // Mutates [orderDetail] in place — caller should pass a deep copy.
    _mutateVisibleLineAtIndex(orderDetail, lineIndex, (item) {
      item['is_offer'] = true;
      item['offer_reason'] = 'Article offert';
      item['offer_datetime'] = DateTime.now().toUtc().toIso8601String();
      item['sub_total'] = '0.00';
    });
    final payload = buildOrderUpdatePayload(orderDetail);
    final status = orderDetail['status']?.toString().trim().toLowerCase();
    payload['status'] = (status == null ||
            status.isEmpty ||
            status == 'offered' ||
            status == 'closed' ||
            status == 'cancelled')
        ? 'open'
        : orderDetail['status'];
    return payload;
  }

  /// Sets the API `comment` field on a visible line (message / pencil).
  static Map<String, dynamic> updateLineCommentAtIndex({
    required Map<String, dynamic> orderDetail,
    required int lineIndex,
    required String comment,
  }) {
    // Mutates [orderDetail] in place — caller should pass a deep copy.
    final trimmed = comment.trim();
    _mutateVisibleLineAtIndex(orderDetail, lineIndex, (item) {
      item['comment'] = trimmed;
    });
    return buildOrderUpdatePayload(orderDetail);
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
        // Must match extractProducts / UI lineIndex (created_at, then id).
        for (final item in _visibleItemsInStableAddOrder(course['items'])) {
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

  /// Deep copy of an order detail map (mutation fallback / safe edits).
  static Map<String, dynamic> copyOrderDetail(Map<String, dynamic> source) =>
      _deepCopyOrderMap(source);

  static double parseOrderPayableAmount(Map<String, dynamic> data) {
    final order = unwrapOrderDetail(data);
    final remaining = order['remaining_amount'];
    if (remaining is num && remaining > 0) return remaining.toDouble();
    if (remaining is String) {
      final parsed =
          double.tryParse(remaining.replaceAll(',', '.').replaceAll('€', '').trim());
      if (parsed != null && parsed > 0) return parsed;
    }

    final total = parseOrderTotalAmount(data);
    if (total > 0) return total;

    // Fallback: sum visible line totals when header amounts are missing/zero.
    return _sumVisibleLineAmounts(order);
  }

  static double _sumVisibleLineAmounts(Map<String, dynamic> order) {
    var sum = 0.0;
    final seatOrders = order['seat_orders'];
    if (seatOrders is! List) return 0;

    for (final seat in seatOrders) {
      if (seat is! Map) continue;
      final courses = seat['courses'];
      if (courses is! List) continue;
      for (final course in courses) {
        if (course is! Map) continue;
        final items = course['items'];
        if (items is! List) continue;
        for (final item in items) {
          if (item is! Map) continue;
          if (item['status']?.toString().toLowerCase() == 'cancelled') continue;
          if (item['is_offered'] == true || item['offered'] == true) continue;
          final raw = item['total_price'] ??
              item['total'] ??
              item['price'] ??
              item['unit_price'];
          if (raw is num) {
            final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
            // total_price is usually already qty * unit; unit_price needs qty.
            if (item['total_price'] != null || item['total'] != null) {
              sum += raw.toDouble();
            } else {
              sum += raw.toDouble() * qty;
            }
          } else if (raw is String) {
            final parsed = double.tryParse(
              raw.replaceAll(',', '.').replaceAll('€', '').trim(),
            );
            if (parsed != null) sum += parsed;
          }
        }
      }
    }
    return sum;
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
    int? selectedSuivreSectionIndex,
  }) {
    return appendSimpleItems(
      orderDetail: orderDetail,
      items: [
        (
          productId: productId,
          unitPrice: unitPrice,
          qty: qty,
          comment: comment,
        ),
      ],
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
      selectedSuivreSectionIndex: selectedSuivreSectionIndex,
    );
  }

  /// Append many simple lines locally, then build **one** PUT payload.
  static Map<String, dynamic> appendSimpleItems({
    required Map<String, dynamic> orderDetail,
    required List<
            ({
              int productId,
              double unitPrice,
              int qty,
              String comment,
            })>
        items,
    int suivreSectionCount = 0,
    List<int> suivreSplitHints = const [],
    List<OrderDisplayEntry>? layoutHints,
    int? selectedSuivreSectionIndex,
  }) {
    var working = copyOrderDetail(orderDetail);
    if (items.isEmpty) {
      return buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
    }

    if (layoutHints != null &&
        (layoutHasTrailingPendingSuivre(layoutHints) ||
            layoutHasProductsUnderPendingSuivre(layoutHints))) {
      final aligned = alignAboveSuivreItemsOntoCourse1(
        working,
        layoutHints: layoutHints,
      );
      working = aligned.detail;
    }

    for (final line in items) {
      final seatNumber = resolveDefaultSeatNumber(working);
      final course = resolveAppendCourse(
        working,
        seatNumber: seatNumber,
        suivreSectionCount: suivreSectionCount,
        suivreSplitHints: suivreSplitHints,
        layoutHints: layoutHints,
        selectedSuivreSectionIndex: selectedSuivreSectionIndex,
      );
      final itemStatus = _resolveAppendItemStatus(
        working,
        seatNumber: seatNumber,
        courseNumber: course.number,
      );

      final newItem = _buildNewItemPayload(
        seatNumber: seatNumber,
        courseId: course.id,
        productId: line.productId,
        qty: line.qty,
        subTotal: line.unitPrice * line.qty,
        status: itemStatus,
        comment: line.comment,
        forCreate: false,
      );

      _appendItemToSeatOrders(
        working,
        seatNumber: seatNumber,
        courseNumber: course.number,
        newItem: newItem,
      );
    }

    if (layoutHints != null && layoutHints.isNotEmpty) {
      final aligned = alignPendingSuivreLayoutOntoCourses(
        working,
        layout: layoutHints,
      );
      working = aligned.detail;
    }

    return buildOrderUpdatePayload(working, keepOpenWhenEmpty: true);
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
    int? selectedSuivreSectionIndex,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final course = resolveAppendCourse(
      working,
      seatNumber: seatNumber,
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
      selectedSuivreSectionIndex: selectedSuivreSectionIndex,
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

    if (layoutHints != null && layoutHints.isNotEmpty) {
      final aligned = alignPendingSuivreLayoutOntoCourses(
        working,
        layout: layoutHints,
      );
      if (aligned.changed) {
        return buildOrderUpdatePayload(aligned.detail);
      }
    }

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
    // Laravel: `courses.*.items` is `required` — empty `[]` fails validation.
    // Drop empty course shells (typical leftover after delete À SUIVRE).
    copy['courses'] = courses is List
        ? courses
            .whereType<Map<String, dynamic>>()
            .map(_sanitizeCourseForUpdate)
            .where(_coursePayloadHasItems)
            .toList()
        : <dynamic>[];
    return copy;
  }

  /// True when a sanitized course still has an `items` list Laravel will accept.
  static bool _coursePayloadHasItems(Map<String, dynamic> course) {
    final items = course['items'];
    return items is List && items.isNotEmpty;
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
    // Always emit `items` as a list (never omit the key on kept courses).
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
      // Stable sort key before the API assigns a real timestamp/id.
      'created_at': DateTime.now().toUtc().toIso8601String(),
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
    int? selectedSuivreSectionIndex,
  }) {
    final effectiveLayout = layoutHints ?? current.displayEntries;
    final workingCurrent = ensureSessionDisplayHydrated(
      layoutHints != null
          ? current.copyWith(displayEntries: layoutHints)
          : current,
    );
    final subTotal = basePrice + _menuSelectionsSupplement(menuSelections);

    // Open À SUIVRE: append on the session ticket like simple catalog taps.
    if ((selectedSuivreSectionIndex != null && selectedSuivreSectionIndex > 0) ||
        layoutHasTrailingPendingSuivre(effectiveLayout) ||
        layoutHasProductsUnderPendingSuivre(effectiveLayout)) {
      return _predictAppendOnSessionOrder(
        current: workingCurrent,
        productName: productName,
        unitPrice: subTotal,
        qty: 1,
        menuItems: menuSelectionLabelsFromMaps(menuSelections),
        selectedSuivreSectionIndex: selectedSuivreSectionIndex,
      );
    }

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
        selectedSuivreSectionIndex: selectedSuivreSectionIndex,
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
      selectedSuivreSectionIndex: selectedSuivreSectionIndex,
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
    int? selectedSuivreSectionIndex,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final course = resolveAppendCourse(
      working,
      seatNumber: seatNumber,
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
      selectedSuivreSectionIndex: selectedSuivreSectionIndex,
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
    int? selectedSuivreSectionIndex,
  }) {
    final working = Map<String, dynamic>.from(orderDetail);
    final seatNumber = resolveDefaultSeatNumber(working);
    final course = resolveAppendCourse(
      working,
      seatNumber: seatNumber,
      suivreSectionCount: suivreSectionCount,
      suivreSplitHints: suivreSplitHints,
      layoutHints: layoutHints,
      selectedSuivreSectionIndex: selectedSuivreSectionIndex,
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
    int? selectedSuivreSectionIndex,
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

    final baseEntries = coalesceDisplayEntriesWithProducts(
      current.products,
      current.displayEntries,
    );

    return current.copyWith(
      products: products,
      displayEntries: _appendProductToDisplayEntries(
        baseEntries,
        product: newProduct,
        lineIndex: lineIndex,
        selectedSuivreSectionIndex: selectedSuivreSectionIndex,
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
    int? selectedSuivreSectionIndex,
  }) {
    final result = entries.toList();
    var sectionIndex = 0;
    int? courseNumber;
    var insertAt = result.length;

    if (selectedSuivreSectionIndex != null && selectedSuivreSectionIndex > 0) {
      for (var i = 0; i < result.length; i++) {
        final entry = result[i];
        if (entry.isSectionDivider &&
            entry.sectionIndex == selectedSuivreSectionIndex) {
          sectionIndex = selectedSuivreSectionIndex;
          final above = entry.courseNumber;
          courseNumber = (above != null && above > 0)
              ? above + 1
              : selectedSuivreSectionIndex + 1;
          insertAt = i + 1;
          while (insertAt < result.length &&
              !result[insertAt].isSectionDivider) {
            insertAt++;
          }
          break;
        }
      }
    }

    if (courseNumber == null) {
      for (var i = result.length - 1; i >= 0; i--) {
        final entry = result[i];
        if (entry.type == OrderDisplayEntryType.suivreSeparator ||
            entry.type == OrderDisplayEntryType.demandeSeparator) {
          sectionIndex = entry.sectionIndex ?? 0;
          courseNumber = (entry.courseNumber ?? 0) + 1;
          insertAt = result.length;
          break;
        }
        if (entry.type == OrderDisplayEntryType.product) {
          sectionIndex = entry.sectionIndex ?? 0;
          courseNumber = entry.courseNumber;
          if (courseNumber == null && sectionIndex > 0) {
            for (var j = i - 1; j >= 0; j--) {
              final above = result[j];
              if (!above.isSectionDivider) continue;
              final aboveCourse = above.courseNumber;
              courseNumber = (aboveCourse != null && aboveCourse > 0)
                  ? aboveCourse + 1
                  : sectionIndex + 1;
              break;
            }
            courseNumber ??= sectionIndex + 1;
          }
          insertAt = result.length;
          break;
        }
      }
    }

    result.insert(
      insertAt,
      OrderDisplayEntry.product(
        product: product,
        lineIndex: lineIndex,
        sectionIndex: sectionIndex,
        courseNumber: courseNumber ?? 1,
        itemId: 0,
      ),
    );
    return reindexDisplayEntries(result);
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
            itemId: entry.itemId,
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
              itemId: entry.itemId,
            ),
          );
          continue;
        }
      }
      result.add(entry);
    }
    // Drop empty À SUIVRE left after removing the last item in a suite.
    return _normalizeSuivreLayout(result, keepTrailingEmptySuivre: false);
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
