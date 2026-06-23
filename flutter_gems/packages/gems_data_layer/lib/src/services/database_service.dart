import 'package:hive_flutter/hive_flutter.dart';

/// Hive Database Service
class DatabaseService {
  static const String _defaultBoxName = 'gems_database';
  Box? _defaultBox;
  final Map<String, Box> _boxes = {};

  /// Initialize database
  Future<void> initialize({String? boxName}) async {
    await Hive.initFlutter();
    _defaultBox = await Hive.openBox(boxName ?? _defaultBoxName);
  }

  /// Open a named box
  Future<Box> openBox(String boxName) async {
    if (_boxes.containsKey(boxName)) {
      return _boxes[boxName]!;
    }
    final box = await Hive.openBox(boxName);
    _boxes[boxName] = box;
    return box;
  }

  /// Get default box
  Box get box {
    if (_defaultBox == null) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return _defaultBox!;
  }

  /// Save data
  Future<void> save<T>(String key, T value, {String? boxName}) async {
    final targetBox = boxName != null ? await openBox(boxName) : box;
    await targetBox.put(key, value);
  }

  /// Get data
  T? get<T>(String key, {String? boxName}) {
    final targetBox = boxName != null ? _boxes[boxName] : box;
    if (targetBox == null) return null;
    return targetBox.get(key) as T?;
  }

  /// Get all keys
  Iterable<dynamic> getAllKeys({String? boxName}) {
    final targetBox = boxName != null ? _boxes[boxName] : box;
    if (targetBox == null) return [];
    return targetBox.keys;
  }

  /// Get all values
  Iterable<dynamic> getAllValues({String? boxName}) {
    final targetBox = boxName != null ? _boxes[boxName] : box;
    if (targetBox == null) return [];
    return targetBox.values;
  }

  /// Get all as map
  Map<dynamic, dynamic> getAll({String? boxName}) {
    final targetBox = boxName != null ? _boxes[boxName] : box;
    if (targetBox == null) return {};
    return targetBox.toMap();
  }

  /// Check if key exists
  bool containsKey(String key, {String? boxName}) {
    final targetBox = boxName != null ? _boxes[boxName] : box;
    if (targetBox == null) return false;
    return targetBox.containsKey(key);
  }

  /// Delete data
  Future<void> delete(String key, {String? boxName}) async {
    final targetBox = boxName != null ? await openBox(boxName) : box;
    await targetBox.delete(key);
  }

  /// Clear box
  Future<void> clear({String? boxName}) async {
    final targetBox = boxName != null ? await openBox(boxName) : box;
    await targetBox.clear();
  }

  /// Register Hive adapter
  void registerAdapter<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }
}

