import '../mappers/order_mapper.dart';

class DayStatisticsInfo {
  const DayStatisticsInfo({
    required this.totalRevenue,
    required this.openTables,
    required this.printedTickets,
    required this.averagePerTable,
    this.raw,
  });

  final double totalRevenue;
  final int openTables;
  final int printedTickets;
  final double averagePerTable;
  final Map<String, dynamic>? raw;

  String get formattedTotalRevenue => OrderMapper.formatPrice('$totalRevenue');
  String get formattedAveragePerTable =>
      OrderMapper.formatPrice('$averagePerTable');

  factory DayStatisticsInfo.fromJson(Map<String, dynamic> json) {
    final totalRevenue = _readDouble(json, const [
      'total_revenue',
      'totalRevenue',
      'revenue',
      'total_sales',
      'total_amount',
      'total',
    ]);
    final openTables = _readInt(json, const [
      'open_tables',
      'openTables',
      'tables_open',
      'open_orders_count',
      'open_orders',
      'tables_count',
    ]);
    final printedTickets = _readInt(json, const [
      'printed_tickets',
      'printedTickets',
      'tickets_printed',
      'receipts_printed',
      'printed_receipts',
    ]);
    final averagePerTable = _readDouble(json, const [
      'average_per_table',
      'averagePerTable',
      'avg_per_table',
      'average_ticket',
    ]);

    final computedAvg = openTables > 0 ? totalRevenue / openTables : 0.0;

    return DayStatisticsInfo(
      totalRevenue: totalRevenue,
      openTables: openTables,
      printedTickets: printedTickets,
      averagePerTable:
          averagePerTable > 0 ? averagePerTable : computedAvg,
      raw: json,
    );
  }

  static double _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  static int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }
}
