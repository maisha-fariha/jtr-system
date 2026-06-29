const _frenchMonths = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

const _frenchWeekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

class DateFormatter {
  DateFormatter._();

  static String formatFrenchLongDate(DateTime date) {
    final weekday = _frenchWeekdays[date.weekday - 1];
    final month = _frenchMonths[date.month - 1];
    return '$weekday ${date.day} $month ${date.year}';
  }

  static DateTime? tryParseApiDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
