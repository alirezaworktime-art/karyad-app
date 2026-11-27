import 'package:shamsi_date/shamsi_date.dart';

/// Number and date formatting for Persian UI text.
abstract final class PersianFormat {
  static const _latinDigits = '0123456789';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  static const _monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// Replaces Latin digits with Persian ones: "12" → "۱۲".
  static String digits(String input) {
    final buffer = StringBuffer();
    for (final unit in input.split('')) {
      final index = _latinDigits.indexOf(unit);
      buffer.write(index < 0 ? unit : _persianDigits[index]);
    }
    return buffer.toString();
  }

  /// Parses user input that may mix Persian, Arabic-Indic and Latin digits
  /// and thousands separators. Returns null when no digits are present.
  static int? parseInt(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final persian = _persianDigits.indexOf(char);
      if (persian >= 0) {
        buffer.write(persian);
        continue;
      }
      // Arabic-Indic digits U+0660..U+0669.
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.write(rune - 0x0660);
        continue;
      }
      if (_latinDigits.contains(char)) buffer.write(char);
    }
    final text = buffer.toString();
    return text.isEmpty ? null : int.tryParse(text);
  }

  /// 12500 → "۱۲٬۵۰۰".
  static String number(int value) {
    final negative = value < 0;
    final raw = value.abs().toString();
    final grouped = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) grouped.write('٬');
      grouped.write(raw[i]);
    }
    return '${negative ? '−' : ''}${digits(grouped.toString())}';
  }

  /// 12500 → "۱۲٬۵۰۰ کیلومتر".
  static String km(int value) => '${number(value)} کیلومتر';

  /// Solar Hijri date: "۶ آذر ۱۴۰۵".
  static String date(DateTime value) {
    final jalali = Jalali.fromDateTime(value);
    return '${digits('${jalali.day}')} ${_monthNames[jalali.month - 1]} '
        '${digits('${jalali.year}')}';
  }

  /// Month and year only, for far-off dates: "مهر ۱۴۰۶".
  static String monthYear(DateTime value) {
    final jalali = Jalali.fromDateTime(value);
    return '${_monthNames[jalali.month - 1]} ${digits('${jalali.year}')}';
  }

  /// A rough, friendly duration: "۵ روز", "۳ هفته", "۴ ماه".
  static String roughDuration(int days) {
    if (days < 14) return '${number(days < 1 ? 1 : days)} روز';
    if (days < 60) return '${number((days / 7).round())} هفته';
    return '${number((days / 30).round())} ماه';
  }

  /// Relative day count for reminders: "امروز", "۳ روز دیگر", "۵ روز پیش".
  static String daysFromNow(int days) {
    if (days == 0) return 'امروز';
    if (days > 0) return '${number(days)} روز دیگر';
    return '${number(-days)} روز پیش';
  }
}
