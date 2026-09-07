class JtrMobileFormatters {
  JtrMobileFormatters._();

  static String currency(double value, {bool compact = false}) {
    final rounded = value.round();
    final negative = rounded < 0;
    final abs = rounded.abs();
    final s = abs.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    final core = buf.toString();
    if (compact && abs >= 1000) {
      return '${negative ? '-' : ''}$core DH';
    }
    return '${negative ? '-' : ''}$core DH';
  }

  static String decimal(double value) {
    final s = value.toStringAsFixed(1).replaceAll('.', ',');
    return '$s DH';
  }
}
