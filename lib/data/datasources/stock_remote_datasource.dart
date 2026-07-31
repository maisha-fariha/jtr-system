import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../models/api_envelope.dart';
import '../models/stock/product_stock_limit.dart';

class StockRemoteDataSource {
  StockRemoteDataSource(this._client);

  final ApiClient _client;

  Future<Map<int, ProductStockLimit>> fetchLimits() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.stockLimits,
    );
    final data = _unwrapData(response.data);
    return parseStockLimits(data);
  }

  Future<ProductStockStatus> fetchProductStatus(int productId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.stockProductStatus(productId),
    );
    final data = _unwrapData(response.data);
    final status = parseProductStatus(productId, data);
    if (status == null) {
      throw ApiException(
        message: 'Statut stock introuvable pour ce produit.',
      );
    }
    return status;
  }

  Future<void> setLimit({
    required int productId,
    required int dailyLimit,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.stockLimits,
      data: {
        'product_id': productId,
        // Doc uses daily_limit; Postman historically used limit_qty.
        'daily_limit': dailyLimit,
        'limit_qty': dailyLimit,
      },
    );
    _ensureSuccess(response.data, fallback: 'Impossible d\'enregistrer le stock.');
  }

  Future<void> removeLimit(int productId) async {
    final response = await _client.delete<Map<String, dynamic>>(
      ApiEndpoints.stockLimitForProduct(productId),
    );
    _ensureSuccess(response.data, fallback: 'Impossible de supprimer le stock.');
  }

  Future<void> blockProduct(int productId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.stockProductBlock(productId),
    );
    _ensureSuccess(response.data, fallback: 'Impossible de bloquer le produit.');
  }

  Future<void> freeProduct(int productId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.stockProductFree(productId),
    );
    _ensureSuccess(response.data, fallback: 'Impossible de remettre en vente.');
  }

  /// [deltas]: negative = consume, positive = restore.
  Future<void> applyDeltas(Map<int, int> deltas) async {
    if (deltas.isEmpty) return;
    final payload = <String, int>{
      for (final entry in deltas.entries)
        if (entry.value != 0) '${entry.key}': entry.value,
    };
    if (payload.isEmpty) return;

    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.stockApplyDeltas,
      data: {'deltas': payload},
    );
    _ensureSuccess(
      response.data,
      fallback: 'Impossible d\'appliquer les deltas stock.',
    );
  }

  // ── Parsing (tolerant; exposed for unit tests) ─────────────────────────────

  static Map<int, ProductStockLimit> parseStockLimits(Object? raw) {
    final result = <int, ProductStockLimit>{};
    if (raw == null) return result;

    void ingest(Object? row) {
      final limit = _limitFromRow(row);
      if (limit != null) result[limit.productId] = limit;
    }

    if (raw is List) {
      for (final row in raw) {
        ingest(row);
      }
      return result;
    }

    if (raw is! Map) return result;
    final map = Map<String, dynamic>.from(raw);

    for (final key in const [
      'limits',
      'items',
      'products',
      'data',
      'rows',
    ]) {
      final nested = map[key];
      if (nested is List) {
        for (final row in nested) {
          ingest(row);
        }
        if (result.isNotEmpty) return result;
      }
    }

    // product_id-keyed map: { "42": { current_stock: 5 }, ... }
    var keyedHits = 0;
    for (final entry in map.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id == null || id <= 0) continue;
      if (entry.value is! Map) continue;
      final row = Map<String, dynamic>.from(entry.value as Map);
      row.putIfAbsent('product_id', () => id);
      ingest(row);
      keyedHits++;
    }
    if (keyedHits > 0) return result;

    ingest(map);
    return result;
  }

  static ProductStockStatus? parseProductStatus(int productId, Object? raw) {
    final map = _asMap(raw);
    if (map == null) return null;

    final nested = _asMap(map['stock']) ??
        _asMap(map['status']) ??
        _asMap(map['product']) ??
        map;

    final id = _readInt(
          nested['product_id'] ??
              nested['id'] ??
              map['product_id'] ??
              map['id'],
        ) ??
        productId;

    final current = _readInt(
          nested['current_stock'] ??
              nested['available_qty'] ??
              nested['available'] ??
              nested['remaining_qty'] ??
              nested['remaining'] ??
              nested['current_qty'] ??
              nested['stock_qty'] ??
              nested['qty'],
        ) ??
        0;

    final dailyLimit = _readInt(
      nested['daily_limit'] ??
          nested['limit_qty'] ??
          nested['limit'] ??
          nested['stock_limit'] ??
          nested['max_qty'],
    );

    final isFreed = nested['is_freed'] == true || nested['freed'] == true;
    final isBlocked = nested['is_blocked'] == true ||
        nested['blocked'] == true ||
        nested['is_out_of_stock'] == true;
    final hasLimit = nested['has_limit'] == true ||
        dailyLimit != null ||
        nested.containsKey('current_stock') ||
        nested.containsKey('available_qty');

    final name = nested['product_name']?.toString() ??
        nested['name']?.toString() ??
        _asMap(nested['product'])?['name']?.toString();

    return ProductStockStatus(
      productId: id,
      productName: name,
      currentStock: current,
      dailyLimit: dailyLimit,
      isFreed: isFreed,
      isBlocked: isBlocked,
      hasLimit: hasLimit,
    );
  }

  static ProductStockLimit? _limitFromRow(Object? row) {
    final map = _asMap(row);
    if (map == null) return null;

    final product = _asMap(map['product']);
    final id = _readInt(
      map['product_id'] ??
          map['id'] ??
          product?['id'] ??
          map['productId'],
    );
    if (id == null || id <= 0) return null;

    final current = _readInt(
          map['current_stock'] ??
              map['available_qty'] ??
              map['available'] ??
              map['remaining_qty'] ??
              map['remaining'] ??
              map['current_qty'] ??
              map['stock_qty'] ??
              map['qty'],
        ) ??
        0;

    final dailyLimit = _readInt(
      map['daily_limit'] ??
          map['limit_qty'] ??
          map['limit'] ??
          map['stock_limit'] ??
          map['max_qty'],
    );

    final isFreed = map['is_freed'] == true || map['freed'] == true;
    final isBlocked = map['is_blocked'] == true ||
        map['blocked'] == true ||
        map['is_out_of_stock'] == true;

    final name = map['product_name']?.toString() ??
        map['name']?.toString() ??
        product?['name']?.toString();

    return ProductStockLimit(
      productId: id,
      productName: name,
      currentStock: current,
      dailyLimit: dailyLimit,
      isFreed: isFreed,
      isBlocked: isBlocked,
    );
  }

  static Object? _unwrapData(Map<String, dynamic>? body) {
    if (body == null) return null;
    final envelope = ApiEnvelope.parseResponse(
      body,
      fromJsonT: (json) => json,
    );
    if (!envelope.success && envelope.data == null) {
      throw ApiException(
        message: envelope.message ?? 'Erreur stock.',
        statusCode: envelope.status,
      );
    }
    return envelope.data ?? body;
  }

  static void _ensureSuccess(
    Map<String, dynamic>? body, {
    required String fallback,
  }) {
    if (body == null) return;
    final envelope = ApiEnvelope.parseResponse(body);
    if (!envelope.success) {
      throw ApiException(
        message: envelope.message ?? fallback,
        statusCode: envelope.status,
      );
    }
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
