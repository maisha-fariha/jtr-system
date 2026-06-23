import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'api_service.dart';
import 'database_service.dart';
import '../utils/api_response.dart';

/// Sync queue item
class SyncItem {
  final String id;
  final String method;
  final String endpoint;
  final dynamic data;
  final DateTime timestamp;

  SyncItem({
    required this.id,
    required this.method,
    required this.endpoint,
    this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'endpoint': endpoint,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SyncItem.fromJson(Map<String, dynamic> json) => SyncItem(
        id: json['id'] as String,
        method: json['method'] as String,
        endpoint: json['endpoint'] as String,
        data: json['data'],
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Simple Sync Service for offline queue
class SyncService {
  final ApiService apiService;
  final DatabaseService databaseService;
  final Connectivity connectivity;
  static const String _syncQueueKey = 'sync_queue';

  SyncService(this.apiService, this.databaseService, this.connectivity);

  /// Initialize (no-op, kept for compatibility)
  Future<void> initialize() async {}

  /// Add item to sync queue
  Future<void> addToQueue(SyncItem item) async {
    final queue = await getQueue();
    queue.add(item);
    await _saveQueue(queue);
  }

  /// Get sync queue
  Future<List<SyncItem>> getQueue() async {
    final queueJson = databaseService.get<String>(_syncQueueKey);
    if (queueJson == null) return [];
    try {
      final queue = jsonDecode(queueJson) as List;
      return queue
          .map((item) => SyncItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Sync queue (call manually when online)
  Future<void> syncQueue() async {
    try {
      final result = await connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) return;
    } catch (e) {
      return;
    }

    final queue = await getQueue();
    if (queue.isEmpty) return;

    final failedItems = <SyncItem>[];

    for (final item in queue) {
      try {
        ApiResponse response;
        switch (item.method.toUpperCase()) {
          case 'POST':
            response = await apiService.post(item.endpoint, data: item.data);
            break;
          case 'PUT':
            response = await apiService.put(item.endpoint, data: item.data);
            break;
          case 'PATCH':
            response = await apiService.patch(item.endpoint, data: item.data);
            break;
          case 'DELETE':
            response = await apiService.delete(item.endpoint);
            break;
          default:
            continue;
        }
        if (!response.success) failedItems.add(item);
      } catch (e) {
        failedItems.add(item);
      }
    }

    await _saveQueue(failedItems);
  }

  Future<void> clearQueue() async {
    await databaseService.delete(_syncQueueKey);
  }

  Future<void> _saveQueue(List<SyncItem> queue) async {
    await databaseService.save(
      _syncQueueKey,
      jsonEncode(queue.map((item) => item.toJson()).toList()),
    );
  }
}
