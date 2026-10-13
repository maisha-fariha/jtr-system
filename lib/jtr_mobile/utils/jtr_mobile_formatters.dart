class JtrMobileFormatters {
  JtrMobileFormatters._();

  /// API + UI date format: `YYYY-MM-DD`.
  static String isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Single day → `YYYY-MM-DD`; range → `YYYY-MM-DD – YYYY-MM-DD`.
  static String isoDateRange(DateTime from, DateTime to) {
    final a = isoDate(from);
    final b = isoDate(to);
    return a == b ? a : '$a – $b';
  }

  static String integer(int value) {
    final negative = value < 0;
    final core = _groupDigits(value.abs());
    return negative ? '-$core' : core;
  }

  /// Exact amount with thousand separators — keeps decimals (no round/floor).
  static String currency(double value, {bool compact = false}) {
    final negative = value < 0;
    final core = _formatExactNumber(value.abs());
    return '${negative ? '-' : ''}$core';
  }

  static String decimal(double value) {
    final negative = value < 0;
    final core = _formatExactNumber(value.abs());
    return '${negative ? '-' : ''}$core';
  }

  /// Exact percent label (no integer round, no thousand grouping).
  static String percent(double value) {
    final negative = value < 0;
    final core = _formatExactNumber(value.abs(), maxDecimals: 2, group: false);
    return '${negative ? '-' : ''}$core%';
  }

  static String _formatExactNumber(
    double abs, {
    int maxDecimals = 2,
    bool group = true,
  }) {
    // Avoid float noise; keep up to [maxDecimals] without forcing .00.
    final fixed = abs.toStringAsFixed(maxDecimals);
    final parts = fixed.split('.');
    final intPart =
        group ? _groupDigits(int.parse(parts[0])) : parts[0];
    if (parts.length == 1) return intPart;

    var frac = parts[1];
    while (frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    if (frac.isEmpty) return intPart;
    return '$intPart,$frac';
  }

  static String _groupDigits(int abs) {
    final s = abs.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
