/// Active sales zone from [GET /api/sales-zones/shortlist] (desktop-compatible).
class SalesZoneInfo {
  const SalesZoneInfo({
    required this.id,
    required this.name,
    this.code,
    this.type,
    this.hasTables = true,
    this.hasFloorPlan = false,
    this.hasClientCardex = false,
    this.displayOrder = 0,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final String? code;
  final String? type;
  final bool hasTables;
  final bool hasFloorPlan;
  final bool hasClientCardex;
  final int displayOrder;
  final bool isDefault;

  /// Table / floor-plan zones use the existing table-number flow.
  bool get usesTableFlow => hasTables || hasFloorPlan;

  String get displayLabel {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'ZONE';
    return trimmed.toUpperCase();
  }

  factory SalesZoneInfo.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final name = (json['name'] ?? json['label'] ?? '').toString().trim();
    return SalesZoneInfo(
      id: id,
      name: name.isEmpty ? 'Zone $id' : name,
      code: json['code']?.toString(),
      type: json['type']?.toString(),
      hasTables: json['has_tables'] == true,
      hasFloorPlan: json['has_floor_plan'] == true,
      hasClientCardex: json['has_client_cardex'] == true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] == true,
    );
  }

  static List<SalesZoneInfo> listFromPayload(dynamic data) {
    List<dynamic>? raw;
    if (data is List) {
      raw = data;
    } else if (data is Map<String, dynamic>) {
      final nested = data['sales_zones'] ??
          data['salesZones'] ??
          data['zones'] ??
          data['data'];
      if (nested is List) raw = nested;
    }
    if (raw == null) return const [];

    final zones = raw
        .whereType<Map>()
        .map((e) => SalesZoneInfo.fromJson(Map<String, dynamic>.from(e)))
        .where((z) => z.id > 0)
        .toList();

    zones.sort((a, b) {
      final byOrder = a.displayOrder.compareTo(b.displayOrder);
      if (byOrder != 0) return byOrder;
      return a.id.compareTo(b.id);
    });
    return zones;
  }

  /// Default zone: `is_default`, else `display_order == 0`, else first.
  static SalesZoneInfo? pickDefault(List<SalesZoneInfo> zones) {
    if (zones.isEmpty) return null;
    for (final z in zones) {
      if (z.isDefault) return z;
    }
    for (final z in zones) {
      if (z.displayOrder == 0) return z;
    }
    return zones.first;
  }
}
