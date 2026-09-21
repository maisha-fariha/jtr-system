import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/storage/device_secure_storage.dart';
import 'rapport_saved_restaurant.dart';

/// Persists multiple restaurant bindings for **JTR Rapport only**.
///
/// POS flavor must not use this store. Active device credentials remain in
/// [DeviceSecureStorage]; this list is an additional index for switching.
class RapportRestaurantStore {
  RapportRestaurantStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _keyList = 'jtr_rapport_restaurants_v1';
  static const _keySelectedId = 'jtr_rapport_selected_restaurant_id_v1';

  final FlutterSecureStorage _storage;

  Future<List<RapportSavedRestaurant>> readAll() async {
    final raw = await _storage.read(key: _keyList);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => RapportSavedRestaurant.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((r) =>
              r.id.isNotEmpty &&
              r.deviceId.isNotEmpty &&
              r.deviceToken.isNotEmpty &&
              r.tenantSchema.isNotEmpty &&
              r.apiBaseUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> readSelectedId() => _storage.read(key: _keySelectedId);

  Future<void> writeSelectedId(String id) =>
      _storage.write(key: _keySelectedId, value: id);

  Future<void> _writeAll(List<RapportSavedRestaurant> restaurants) async {
    final payload =
        jsonEncode(restaurants.map((r) => r.toJson()).toList(growable: false));
    await _storage.write(key: _keyList, value: payload);
  }

  /// Insert or replace by [RapportSavedRestaurant.id], mark as selected.
  Future<RapportSavedRestaurant> upsertAndSelect(
    RapportSavedRestaurant restaurant,
  ) async {
    final list = [...await readAll()];
    final index = list.indexWhere((r) => r.id == restaurant.id);
    if (index >= 0) {
      list[index] = restaurant;
    } else {
      list.add(restaurant);
    }
    await _writeAll(list);
    await writeSelectedId(restaurant.id);
    return restaurant;
  }

  /// Seed list from the currently active device binding (first Rapport launch).
  Future<void> ensureSeededFromActive(DeviceCredentials? active) async {
    if (active == null) return;
    final list = await readAll();
    final seeded = RapportSavedRestaurant.fromCredentials(active);
    if (list.any((r) => r.id == seeded.id)) {
      final selected = await readSelectedId();
      if (selected == null || selected.isEmpty) {
        await writeSelectedId(seeded.id);
      }
      return;
    }
    await upsertAndSelect(seeded);
  }

  Future<RapportSavedRestaurant?> findById(String id) async {
    final list = await readAll();
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> removeById(String id) async {
    final list = await readAll()..removeWhere((r) => r.id == id);
    await _writeAll(list);
    final selected = await readSelectedId();
    if (selected == id) {
      if (list.isEmpty) {
        await _storage.delete(key: _keySelectedId);
      } else {
        await writeSelectedId(list.first.id);
      }
    }
  }

  /// Wipe the multi-restaurant index (does not clear POS device fingerprint).
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _keyList),
      _storage.delete(key: _keySelectedId),
    ]);
  }
}
