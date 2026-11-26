import 'package:intl/intl.dart';

/// Utility helpers for formatting Indonesian Rupiah (IDR) currency values.
abstract final class CurrencyFormatter {
  static final NumberFormat _idrFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _plainNumberFormat = NumberFormat.decimalPattern(
    'id_ID',
  );

  /// Formats [amount] into Indonesian Rupiah string, e.g. `Rp 1.250.000`.
  static String formatIdr(num amount) {
    final isNegative = amount < 0;
    final formatted = _idrFormat.format(amount.abs().round());
    return isNegative ? '-$formatted' : formatted;
  }

  /// Formats [amount] as compact Indonesian currency, e.g. `Rp 12,5 Jt` or `Rp 1,2 M`.
  static String formatCompactIdr(num amount) {
    final absValue = amount.abs();
    final prefix = amount < 0 ? '-' : '';
    if (absValue >= 1000000000) {
      final value = (absValue / 1000000000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return '${prefix}Rp $value M';
    }
    if (absValue >= 1000000) {
      final value = (absValue / 1000000)
          .toStringAsFixed(1)
          .replaceAll('.', ',');
      return '${prefix}Rp $value Jt';
    }
    if (absValue >= 1000) {
      final value = (absValue / 1000).toStringAsFixed(0);
      return '${prefix}Rp $value Rb';
    }
    return formatIdr(amount);
  }

  /// Formats [amount] with thousand separators without currency prefix.
  static String formatNumber(num amount) {
    return _plainNumberFormat.format(amount);
  }
}
