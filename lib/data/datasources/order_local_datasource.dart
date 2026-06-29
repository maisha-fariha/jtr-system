import 'dart:convert';

import '../../core/constants/storage_constants.dart';
import '../../core/storage/hive_storage.dart';
import '../models/open_order_summary.dart';

class OrderLocalDataSource {
  OrderLocalDataSource(this._storage);

  final HiveStorage _storage;

  Future<void> saveOpenOrders(List<OpenOrderSummary> orders) async {
    final jsonList = orders.map((order) => order.toJson()).toList();
    await _storage.writeString(
      StorageConstants.openOrdersKey,
      jsonEncode(jsonList),
    );
  }

  List<OpenOrderSummary> readOpenOrders() {
    final raw = _storage.readString(StorageConstants.openOrdersKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(OpenOrderSummary.fromJson)
        .toList();
  }

  String _detailKey(int orderId) =>
      '${StorageConstants.orderDetailsPrefix}$orderId';

  Future<void> saveOrderDetail(int orderId, Map<String, dynamic> detail) async {
    await _storage.writeString(_detailKey(orderId), jsonEncode(detail));
  }

  Map<String, dynamic>? readOrderDetail(int orderId) {
    final raw = _storage.readString(_detailKey(orderId));
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    return decoded;
  }

  Future<void> removeOrderDetail(int orderId) async {
    await _storage.delete(_detailKey(orderId));
  }

  Future<void> removeFromOpenOrders(int orderId) async {
    final current = readOpenOrders();
    final updated =
        current.where((order) => order.id != orderId).toList(growable: false);
    await saveOpenOrders(updated);
  }
}
