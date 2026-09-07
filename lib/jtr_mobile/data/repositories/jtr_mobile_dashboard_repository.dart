import '../../../core/config/api_config.dart';
import '../../../core/storage/device_secure_storage.dart';
import '../../../utils/date_formatter.dart';
import '../../models/dashboard_models.dart';
import '../../models/detail_models.dart';
import '../jtr_mobile_dashboard_filters.dart';
import '../jtr_mobile_dashboard_remote_datasource.dart';
import '../mappers/jtr_mobile_dashboard_mapper.dart';

class JtrMobileDashboardRepository {
  JtrMobileDashboardRepository({
    required JtrMobileDashboardRemoteDataSource remote,
    required DeviceSecureStorage secureStorage,
  })  : _remote = remote,
        _secureStorage = secureStorage;

  final JtrMobileDashboardRemoteDataSource _remote;
  final DeviceSecureStorage _secureStorage;

  static const _gapEventTypes = [
    'annulations',
    'remises',
    'offerts',
    'pertes',
  ];

  /// Resolves the default filter range from the active POS day (network only).
  Future<JtrMobileDashboardFilters> resolveDefaultFilters() async {
    final activeDay = await _remote.fetchActiveDay();
    final date = JtrMobileDashboardMapper.parseActiveDayDate(activeDay);
    final day = DateTime(date.year, date.month, date.day);
    return JtrMobileDashboardFilters(dateFrom: day, dateTo: day);
  }

  Future<JtrDashboardData> fetchDashboard({
    required JtrMobileDashboardFilters filters,
  }) async {
    final results = await Future.wait([
      _remote.fetchOrderSummary(filters),
      _remote.fetchRevenueByHour(filters),
      _remote.fetchRevenueBySalesZone(filters),
      _remote.fetchActiveDay(),
    ]);

    final orderSummary = results[0] as Map<String, dynamic>;
    final revenueByHour = results[1] as Map<String, dynamic>;
    final revenueByZone = results[2] as List<Map<String, dynamic>>;
    final activeDay = results[3] as Map<String, dynamic>;

    final activeDate = JtrMobileDashboardMapper.parseActiveDayDate(activeDay);
    final storeName = await _resolveStoreName();
    final dateLabel = _buildDateLabel(activeDate);

    return JtrMobileDashboardMapper.mapDashboard(
      orderSummary: orderSummary,
      revenueByHour: revenueByHour,
      revenueByZone: revenueByZone,
      filters: filters,
      storeName: storeName,
      dateLabel: dateLabel,
    );
  }

  Future<List<JtrProductFamily>> fetchProductFamilies({
    required JtrMobileDashboardFilters filters,
  }) async {
    final payload = await _remote.fetchProductFamilySummary(filters);
    return JtrMobileDashboardMapper.mapFamilies(payload);
  }

  Future<List<JtrGapCategoryDetail>> fetchGapCategories({
    required JtrMobileDashboardFilters filters,
    int limit = 20,
  }) async {
    final payloads = await Future.wait(
      _gapEventTypes.map(
        (type) => _remote.fetchEventList(
          filters,
          type: type,
          limit: limit,
        ),
      ),
    );

    final byType = <String, Map<String, dynamic>>{};
    for (var i = 0; i < _gapEventTypes.length; i++) {
      byType[_gapEventTypes[i]] = payloads[i];
    }
    return JtrMobileDashboardMapper.mapGapCategoriesSync(byType);
  }

  Future<String> _resolveStoreName() async {
    final creds = await _secureStorage.readCredentials();
    final label = creds?.label?.trim();
    if (label != null && label.isNotEmpty) return label;

    final tenant = ApiConfig.tenantSchema.trim();
    if (tenant.isNotEmpty) {
      return tenant
          .split(RegExp(r'[_\-.]'))
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join(' ');
    }
    return 'Restaurant';
  }

  String _buildDateLabel(DateTime activeDate) {
    final now = DateTime.now();
    final isToday = activeDate.year == now.year &&
        activeDate.month == now.month &&
        activeDate.day == now.day;
    if (isToday) return "Aujourd'hui · en direct";
    return '${DateFormatter.formatFrenchLongDate(activeDate)} · en direct';
  }
}
