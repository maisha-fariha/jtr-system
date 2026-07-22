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
    await _storage.delete(_suivreSplitKey(orderId));
    await _storage.delete(_suivreCountKey(orderId));
    await _storage.delete(_demandedSectionKey(orderId));
  }

  String _suivreSplitKey(int orderId) =>
      '${StorageConstants.orderDetailsPrefix}suivre_split_$orderId';

  String _suivreCountKey(int orderId) =>
      '${StorageConstants.orderDetailsPrefix}suivre_count_$orderId';

  String _demandedSectionKey(int orderId) =>
      '${StorageConstants.orderDetailsPrefix}demanded_sections_$orderId';

  Future<void> saveSuivreSplitHint(int orderId, List<int> splitPositions) async {
    final key = _suivreSplitKey(orderId);
    final valid = splitPositions.where((splitAt) => splitAt > 0).toList();
    if (valid.isEmpty) {
      await _storage.delete(key);
      return;
    }
    await _storage.writeString(key, valid.join(','));
  }

  List<int> readSuivreSplitHint(int orderId) {
    final raw = _storage.readString(_suivreSplitKey(orderId));
    if (raw == null || raw.isEmpty) return const [];

    return raw
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((splitAt) => splitAt > 0)
        .toList();
  }

  Future<void> saveSuivreCountHint(int orderId, int count) async {
    final key = _suivreCountKey(orderId);
    if (count <= 0) {
      await _storage.delete(key);
      return;
    }
    await _storage.writeString(key, '$count');
  }

  int readSuivreCountHint(int orderId) {
    final raw = _storage.readString(_suivreCountKey(orderId));
    if (raw == null || raw.isEmpty) return 0;
    return int.tryParse(raw) ?? 0;
  }

  Future<void> saveDemandedSectionHint(
    int orderId,
    Set<int> sectionIndices,
  ) async {
    final key = _demandedSectionKey(orderId);
    final valid = sectionIndices.where((index) => index > 0).toList()..sort();
    if (valid.isEmpty) {
      await _storage.delete(key);
      return;
    }
    await _storage.writeString(key, valid.join(','));
  }

  Set<int> readDemandedSectionHint(int orderId) {
    final raw = _storage.readString(_demandedSectionKey(orderId));
    if (raw == null || raw.isEmpty) return const {};

    return raw
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((index) => index > 0)
        .toSet();
  }
}
