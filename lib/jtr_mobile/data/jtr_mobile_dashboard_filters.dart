import '../utils/jtr_mobile_formatters.dart';

class JtrMobileDashboardFilters {
  const JtrMobileDashboardFilters({
    required this.dateFrom,
    required this.dateTo,
    this.waiterId,
    this.salesZoneId,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final int? waiterId;
  final int? salesZoneId;

  Map<String, dynamic> toQueryParams({bool bustCache = true}) {
    final params = <String, dynamic>{
      'date_from': JtrMobileFormatters.isoDate(dateFrom),
      'date_to': JtrMobileFormatters.isoDate(dateTo),
    };
    if (waiterId != null) params['waiter_id'] = waiterId;
    if (salesZoneId != null) params['sales_zone_id'] = salesZoneId;
    if (bustCache) {
      params['_'] = DateTime.now().millisecondsSinceEpoch;
    }
    return params;
  }
}
