import 'dart:convert';

import '../../core/constants/storage_constants.dart';
import '../../core/storage/hive_storage.dart';

class OrderLocalDataSource {
  OrderLocalDataSource(this._storage);

  final HiveStorage _storage;

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
}
