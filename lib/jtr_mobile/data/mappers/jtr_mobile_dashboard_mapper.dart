import '../../../utils/date_formatter.dart';
import '../../models/dashboard_models.dart';
import '../../models/detail_models.dart';
import '../../theme/jtr_mobile_theme.dart';
import '../../utils/jtr_mobile_formatters.dart';
import '../jtr_mobile_dashboard_filters.dart';

class JtrMobileDashboardMapper {
  JtrMobileDashboardMapper._();

  static final _gapTypes = [
    ('annulations', 'Annulations', JtrMobileTheme.danger),
    ('remises', 'Remises', JtrMobileTheme.warning),
    ('offerts', 'Offerts', JtrMobileTheme.pro),
    ('pertes', 'Pertes', JtrMobileTheme.info),
  ];

  static DateTime parseActiveDayDate(Map<String, dynamic> activeDayJson) {
    final dateRaw = activeDayJson['date'] as String? ??
        activeDayJson['opened_at'] as String? ??
        activeDayJson['created_at'] as String?;
    return DateFormatter.tryParseApiDate(dateRaw) ?? DateTime.now();
  }

  static JtrDashboardData mapDashboard({
    required Map<String, dynamic> orderSummary,
    required Map<String, dynamic> revenueByHour,
    required List<Map<String, dynamic>> revenueByZone,
    required JtrMobileDashboardFilters filters,
    required String storeName,
    required String dateLabel,
  }) {
    final recap = _map(recapFrom(orderSummary));
    final indicators = _map(orderSummary['cashier_indicators']);
    final comparison = _map(orderSummary['period_comparison']);

    final revenue = _dbl(recap['chiffre_affaires']);
    final collected = _dbl(recap['total_encaissement']);

    final gapSegments = _gapSegmentsFromRecap(recap);
    final gapTotal = (revenue - collected).clamp(0.0, double.infinity);
    final hourly = _hourlyChart(revenueByHour);

    return JtrDashboardData(
      storeName: storeName,
      dateLabel: dateLabel,
      periodLabel: _formatPeriodLabel(filters.dateFrom, filters.dateTo),
      kpis: JtrDashboardKpis(
        revenue: revenue,
        collected: collected,
        trendLabel: _trendLabel(comparison),
        trendPositive: _dbl(comparison['change_percent']) >= 0,
      ),
      payments: _payments(indicators),
      gapSegments: gapSegments,
      gapTotal: gapTotal,
      categories: _categories(indicators, revenue),
      zones: _zones(revenueByZone),
      activity: JtrActivityStats(
        tickets: _int(indicators['order_count']),
        avgTicket: _dbl(indicators['average_ticket']),
        covers: _int(indicators['covers_total']),
        avgCover: _dbl(indicators['average_per_cover']),
      ),
      movements: _movements(indicators),
      hourlyBars: hourly.bars,
      peakCaption: hourly.peakCaption,
      periodFrom: filters.dateFrom,
      periodTo: filters.dateTo,
    );
  }

  static ({List<JtrHourlyBar> bars, String peakCaption}) _hourlyChart(
    Map<String, dynamic> revenueByHour,
  ) {
    final bars = _hourlyBars(revenueByHour);
    JtrHourlyBar? peakBar;
    for (final bar in bars) {
      if (bar.isPeak) {
        peakBar = bar;
        break;
      }
    }
    if (peakBar != null && peakBar.amount > 0) {
      final label = peakBar.hourLabel.isNotEmpty
          ? peakBar.hourLabel
          : 'pic';
      return (
        bars: bars,
        peakCaption:
            'Pic à $label · ${JtrMobileFormatters.currency(peakBar.amount)}',
      );
    }
    return (bars: bars, peakCaption: _peakCaption(revenueByHour));
  }

  static List<JtrProductFamily> mapFamilies(Map<String, dynamic> payload) {
    final families = payload['families'];
    if (families is! List) return const [];

    return families.whereType<Map>().map((raw) {
      final family = Map<String, dynamic>.from(raw);
      final products = family['products'];
      final articles = <JtrFamilyArticle>[];
      if (products is List) {
        for (final p in products.whereType<Map>()) {
          final product = Map<String, dynamic>.from(p);
          articles.add(
            JtrFamilyArticle(
              name: product['name']?.toString() ?? '—',
              quantity: _int(product['quantity']),
              amount: _dbl(product['total_revenue']),
            ),
          );
        }
      }
      return JtrProductFamily(
        name: family['name']?.toString() ?? '—',
        totalQuantity: _int(family['total_quantity']),
        totalAmount: _dbl(family['total_revenue']),
        articles: articles,
      );
    }).toList();
  }

  static Future<List<JtrGapCategoryDetail>> mapGapCategories(
    List<Map<String, dynamic>> eventListPayloads,
  ) async {
    final result = <JtrGapCategoryDetail>[];
    for (var i = 0; i < _gapTypes.length; i++) {
      final (type, label, color) = _gapTypes[i];
      final payload = i < eventListPayloads.length
          ? eventListPayloads[i]
          : <String, dynamic>{};
      final items = payload['items'];
      final totals = _map(payload['totals']);

      final transactions = <JtrGapTransaction>[];
      if (items is List) {
        for (final raw in items.whereType<Map>()) {
          transactions.add(_mapGapTransaction(Map<String, dynamic>.from(raw), type));
        }
      }

      result.add(
        JtrGapCategoryDetail(
          label: label,
          color: color,
          totalAmount: _dbl(totals['amount']),
          transactions: transactions,
        ),
      );
    }
    return result;
  }

  static List<JtrGapCategoryDetail> mapGapCategoriesSync(
    Map<String, Map<String, dynamic>> payloadsByType,
  ) {
    return _gapTypes.map((entry) {
      final (type, label, color) = entry;
      final payload = payloadsByType[type] ?? const {};
      final items = payload['items'];
      final totals = _map(payload['totals']);
      final transactions = <JtrGapTransaction>[];
      if (items is List) {
        for (final raw in items.whereType<Map>()) {
          transactions.add(
            _mapGapTransaction(Map<String, dynamic>.from(raw), type),
          );
        }
      }
      return JtrGapCategoryDetail(
        label: label,
        color: color,
        totalAmount: _dbl(totals['amount']),
        transactions: transactions,
      );
    }).toList();
  }

  static JtrGapTransaction _mapGapTransaction(
    Map<String, dynamic> item,
    String type,
  ) {
    final eventAt = DateTime.tryParse(item['event_at']?.toString() ?? '');
    final meta = _eventMeta(item, eventAt);
    int? discountPercent;
    if (type == 'remises') {
      final discountType = item['discount_type']?.toString().toLowerCase();
      final discountValue = _dbl(item['discount_value']);
      if (discountType == 'percent' || discountType == 'percentage') {
        discountPercent = discountValue.round();
      } else if (discountValue > 0 && discountValue <= 100) {
        discountPercent = discountValue.round();
      }
    }

    return JtrGapTransaction(
      meta: meta,
      label: item['product_name']?.toString() ?? '—',
      quantity: _nullableInt(item['quantity']),
      tag: item['reason']?.toString(),
      discountPercent: discountPercent,
      amount: _dbl(item['amount']),
    );
  }

  static String _eventMeta(Map<String, dynamic> item, DateTime? eventAt) {
    final parts = <String>[];
    if (eventAt != null) {
      parts.add(
        '${eventAt.day.toString().padLeft(2, '0')}/'
        '${eventAt.month.toString().padLeft(2, '0')}',
      );
      parts.add(
        '${eventAt.hour.toString().padLeft(2, '0')}:'
        '${eventAt.minute.toString().padLeft(2, '0')}',
      );
    } else if (item['pos_day_date'] != null) {
      parts.add(item['pos_day_date'].toString());
    }

    final table = item['table_number'];
    if (table != null && table.toString().isNotEmpty) {
      parts.add('Table $table');
    } else if (item['sales_zone'] is Map) {
      final zone = Map<String, dynamic>.from(item['sales_zone'] as Map);
      final name = zone['name']?.toString();
      if (name != null && name.isNotEmpty) parts.add(name);
    }

    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  static Map<String, dynamic> recapFrom(Map<String, dynamic> orderSummary) =>
      _map(orderSummary['recap']);

  static List<JtrGapSegment> _gapSegmentsFromRecap(Map<String, dynamic> recap) {
    return [
      JtrGapSegment(
        label: 'Annulations',
        amount: _dbl(recap['total_annulation']),
        color: JtrMobileTheme.danger,
      ),
      JtrGapSegment(
        label: 'Remises',
        amount: _dbl(recap['total_remises']),
        color: JtrMobileTheme.warning,
      ),
      JtrGapSegment(
        label: 'Offerts',
        amount: _dbl(recap['total_offres']),
        color: JtrMobileTheme.pro,
      ),
      JtrGapSegment(
        label: 'Pertes',
        amount: _dbl(recap['total_pertes']),
        color: JtrMobileTheme.info,
      ),
    ];
  }

  static List<JtrPaymentBreakdownItem> _payments(Map<String, dynamic> indicators) {
    final modes = indicators['payment_modes'];
    if (modes is! List || modes.isEmpty) return const [];

    final parsed = modes.whereType<Map>().map((raw) {
      final mode = Map<String, dynamic>.from(raw);
      return (
        label: mode['name']?.toString() ?? '—',
        amount: _dbl(mode['amount']),
      );
    }).toList();

    final total = parsed.fold<double>(0, (s, e) => s + e.amount);
    return parsed
        .map(
          (e) => JtrPaymentBreakdownItem(
            label: e.label,
            amount: e.amount,
            percent: total > 0 ? (e.amount / total) * 100 : 0,
          ),
        )
        .toList();
  }

  static List<JtrCategoryRevenue> _categories(
    Map<String, dynamic> indicators,
    double revenue,
  ) {
    final types = indicators['product_types'];
    if (types is! List || types.isEmpty) return const [];

    final palette = JtrMobileTheme.categoryPalette;
    return types.whereType<Map>().toList().asMap().entries.map((entry) {
      final raw = Map<String, dynamic>.from(entry.value);
      final amount = _dbl(raw['total_revenue']);
      return JtrCategoryRevenue(
        name: raw['name']?.toString() ?? '—',
        amount: amount,
        percent: revenue > 0 ? (amount / revenue) * 100 : 0,
        color: palette[entry.key % palette.length],
      );
    }).toList();
  }

  static List<JtrZoneRevenue> _zones(List<Map<String, dynamic>> zones) {
    if (zones.isEmpty) return const [];
    final palette = JtrMobileTheme.categoryPalette;
    return zones.asMap().entries.map((entry) {
      final raw = entry.value;
      return JtrZoneRevenue(
        name: raw['name']?.toString() ?? '—',
        amount: _dbl(raw['total_revenue']),
        percent: _dbl(raw['percentage']),
        color: palette[entry.key % palette.length],
      );
    }).toList();
  }

  static List<JtrMovementRow> _movements(Map<String, dynamic> indicators) {
    final openAmount = _dbl(indicators['open_orders_amount']);
    return [
      JtrMovementRow(
        label: 'Notes soldées',
        value: JtrMobileFormatters.integer(_int(indicators['orders_paid_count'])),
        subValue: null,
        color: JtrMobileTheme.success,
      ),
      JtrMovementRow(
        label: 'Notes ouvertes',
        value: JtrMobileFormatters.integer(_int(indicators['orders_open_count'])),
        subValue: openAmount > 0
            ? JtrMobileFormatters.currency(openAmount)
            : null,
        color: JtrMobileTheme.warning,
      ),
      JtrMovementRow(
        label: 'Transferts table',
        value: JtrMobileFormatters.integer(
          _int(indicators['table_transfers_count']),
        ),
        subValue: null,
        color: JtrMobileTheme.info,
      ),
      JtrMovementRow(
        label: 'Transferts article',
        value: JtrMobileFormatters.integer(
          _int(indicators['item_transfers_count']),
        ),
        subValue: null,
        color: JtrMobileTheme.pro,
      ),
      JtrMovementRow(
        label: 'Annulations paiement',
        value: JtrMobileFormatters.integer(
          _int(indicators['payment_cancellations_count']),
        ),
        subValue: null,
        color: JtrMobileTheme.danger,
        highlightDanger: true,
      ),
    ];
  }

  static List<JtrHourlyBar> _hourlyBars(Map<String, dynamic> payload) {
    final hours = payload['hours'];
    if (hours is! List) return const [];

    final byHour = <int, Map<String, dynamic>>{};
    for (final raw in hours.whereType<Map>()) {
      final hour = Map<String, dynamic>.from(raw);
      byHour[_int(hour['hour'])] = hour;
    }

    final apiPeakHour = payload['peak'] is Map
        ? _int(Map<String, dynamic>.from(payload['peak'] as Map)['hour'])
        : -1;

    // Build amounts for the visible window, then pick the tallest bar for accent.
    const startHour = 10;
    const endHour = 23;
    final amounts = <int, double>{};
    var maxRevenue = 0.0;
    for (var h = startHour; h <= endHour; h++) {
      final slot = byHour[h];
      final revenue = slot != null ? _dbl(slot['revenue']) : 0.0;
      amounts[h] = revenue;
      if (revenue > maxRevenue) maxRevenue = revenue;
    }

    var visualPeakHour = -1;
    if (maxRevenue > 0) {
      if (apiPeakHour >= startHour &&
          apiPeakHour <= endHour &&
          (amounts[apiPeakHour] ?? 0) >= maxRevenue) {
        visualPeakHour = apiPeakHour;
      } else {
        for (var h = startHour; h <= endHour; h++) {
          if ((amounts[h] ?? 0) >= maxRevenue) {
            visualPeakHour = h;
            break;
          }
        }
      }
    }

    final bars = <JtrHourlyBar>[];
    for (var h = startHour; h <= endHour; h++) {
      final isPeak = h == visualPeakHour;
      bars.add(
        JtrHourlyBar(
          hourLabel: (h.isEven || isPeak) ? '${h}h' : '',
          amount: amounts[h] ?? 0.0,
          isPeak: isPeak,
        ),
      );
    }
    return bars;
  }

  static String _peakCaption(Map<String, dynamic> payload) {
    final peak = payload['peak'];
    if (peak is! Map) return '';
    final map = Map<String, dynamic>.from(peak);
    final label = map['hour_label']?.toString();
    final revenue = _dbl(map['revenue']);
    if (label == null || label.isEmpty || revenue <= 0) return '';
    final compact = JtrMobileFormatters.currency(revenue);
    return 'Pic à $label · $compact';
  }

  static String _trendLabel(Map<String, dynamic> comparison) {
    if (comparison.isEmpty) return '';
    final percent = _dbl(comparison['change_percent']);
    final label = comparison['previous_label']?.toString();
    final sign = percent >= 0 ? '+' : '';
    final pct = JtrMobileFormatters.percent(percent).replaceAll('%', '');
    if (label != null && label.isNotEmpty) {
      return '$sign$pct% vs $label';
    }
    return '$sign$pct%';
  }

  static String _formatPeriodLabel(DateTime from, DateTime to) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    if (from.year == to.year &&
        from.month == to.month &&
        from.day == to.day) {
      return '${from.day} ${months[from.month - 1]} ${from.year}';
    }
    if (from.year == to.year && from.month == to.month) {
      return '${months[from.month - 1]} ${from.year}';
    }
    return '${from.day}/${from.month} – ${to.day}/${to.month} ${to.year}';
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static double _dbl(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    return _int(value);
  }
}
