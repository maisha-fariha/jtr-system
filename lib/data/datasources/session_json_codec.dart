import 'dart:convert';

/// Top-level helpers for [compute] — keep heavy JSON off the UI isolate.
String encodeOpenOrdersListJson(List<Map<String, dynamic>> orders) {
  return jsonEncode(orders);
}

List<Map<String, dynamic>> decodeOpenOrdersListJson(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded.whereType<Map<String, dynamic>>().toList();
}
