/// Utility helpers for Indonesian date and time formatting without locale race conditions.
abstract final class DateFormatter {
  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static const List<String> _fullMonths = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> _weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  /// Formats [date] as `26 Nov 2026`.
  static String formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _shortMonths[date.month - 1];
    return '$day $month ${date.year}';
  }

  /// Formats [date] as `26 Nov 2026, 14:30`.
  static String formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${formatShortDate(date)}, $hour:$minute';
  }

  /// Formats [date] as `Kamis, 26 November 2026`.
  static String formatFullDate(DateTime date) {
    final weekday = _weekdays[date.weekday - 1];
    final month = _fullMonths[date.month - 1];
    return '$weekday, ${date.day} $month ${date.year}';
  }

  /// Formats only the time portion of [date] as `14:30`.
  static String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
