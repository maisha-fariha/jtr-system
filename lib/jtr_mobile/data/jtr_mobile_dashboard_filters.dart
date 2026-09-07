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
      'date_from': _formatDate(dateFrom),
      'date_to': _formatDate(dateTo),
    };
    if (waiterId != null) params['waiter_id'] = waiterId;
    if (salesZoneId != null) params['sales_zone_id'] = salesZoneId;
    if (bustCache) {
      params['_'] = DateTime.now().millisecondsSinceEpoch;
    }
    return params;
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
