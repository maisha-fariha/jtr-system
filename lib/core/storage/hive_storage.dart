import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/storage_constants.dart';

class HiveStorage extends GetxService {
  Box<dynamic>? _box;

  Future<HiveStorage> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(StorageConstants.authBox);
    return this;
  }

  Box<dynamic> get box {
    final value = _box;
    if (value == null) {
      throw StateError('HiveStorage not initialized. Call init() first.');
    }
    return value;
  }

  Future<void> writeString(String key, String value) async {
    await box.put(key, value);
  }

  String? readString(String key) => box.get(key) as String?;

  Future<void> delete(String key) async {
    await box.delete(key);
  }

  Future<void> clearAuth() async {
    await box.delete(StorageConstants.authSessionKey);
    await box.delete(StorageConstants.authTokenKey);
  }
}
