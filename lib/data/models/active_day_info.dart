import '../../utils/date_formatter.dart';

class ActiveDayInfo {
  const ActiveDayInfo({
    required this.id,
    required this.displayDate,
    this.sessionNumber,
    this.salesZoneLabel = 'SUR PLACE',
  });

  final int id;
  final String displayDate;
  final String? sessionNumber;
  final String salesZoneLabel;

  factory ActiveDayInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int? ?? 0;
    final dateRaw = json['date'] as String? ??
        json['opened_at'] as String? ??
        json['created_at'] as String?;
    final parsed = DateFormatter.tryParseApiDate(dateRaw) ?? DateTime.now();

    final salesZone = json['sales_zone'];
    var zoneLabel = 'SUR PLACE';
    if (salesZone is Map<String, dynamic>) {
      zoneLabel = (salesZone['name'] as String? ?? zoneLabel).toUpperCase();
    } else if (json['sales_zone_name'] is String) {
      zoneLabel = (json['sales_zone_name'] as String).toUpperCase();
    }

    final sessionNumber = json['number']?.toString() ?? json['day_number']?.toString();

    return ActiveDayInfo(
      id: id,
      displayDate: DateFormatter.formatFrenchLongDate(parsed),
      sessionNumber: sessionNumber ?? (id > 0 ? '$id' : null),
      salesZoneLabel: zoneLabel,
    );
  }

  factory ActiveDayInfo.fallback() {
    return ActiveDayInfo(
      id: 0,
      displayDate: DateFormatter.formatFrenchLongDate(DateTime.now()),
      sessionNumber: '—',
    );
  }
}
