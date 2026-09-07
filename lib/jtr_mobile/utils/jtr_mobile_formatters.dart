class JtrMobileFormatters {
  JtrMobileFormatters._();

  static String integer(int value) {
    final negative = value < 0;
    final core = _groupDigits(value.abs());
    return negative ? '-$core' : core;
  }

  static String currency(double value, {bool compact = false}) {
    final rounded = value.round();
    final negative = rounded < 0;
    final core = _groupDigits(rounded.abs());
    return '${negative ? '-' : ''}$core DH';
  }

  static String decimal(double value) {
    final rounded = value.round();
    final hasFraction = (value - rounded).abs() > 0.05;
    final core = hasFraction
        ? value.toStringAsFixed(1).replaceAll('.', ',')
        : _groupDigits(rounded.abs());
    final prefix = value < 0 ? '-' : '';
    return '$prefix$core DH';
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
