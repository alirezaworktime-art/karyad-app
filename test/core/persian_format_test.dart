import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/core/format/persian_format.dart';

void main() {
  test('converts digits to Persian', () {
    expect(PersianFormat.digits('206 SD 2024'), '۲۰۶ SD ۲۰۲۴');
  });

  test('groups thousands', () {
    expect(PersianFormat.number(0), '۰');
    expect(PersianFormat.number(999), '۹۹۹');
    expect(PersianFormat.number(1000), '۱٬۰۰۰');
    expect(PersianFormat.number(125000), '۱۲۵٬۰۰۰');
    expect(PersianFormat.number(-1500), '−۱٬۵۰۰');
  });

  test('parses mixed-digit user input', () {
    expect(PersianFormat.parseInt('۱۲٬۵۰۰'), 12500);
    expect(PersianFormat.parseInt('12,500'), 12500);
    expect(PersianFormat.parseInt('٣٤'), 34);
    expect(PersianFormat.parseInt('km'), isNull);
  });

  test('formats Solar Hijri dates', () {
    // 27 November 2026 is 6 Azar 1405.
    expect(PersianFormat.date(DateTime(2026, 11, 27)), '۶ آذر ۱۴۰۵');
    // 21 March 2026 is 1 Farvardin 1405.
    expect(PersianFormat.date(DateTime(2026, 3, 21)), '۱ فروردین ۱۴۰۵');
  });

  test('describes relative days', () {
    expect(PersianFormat.daysFromNow(0), 'امروز');
    expect(PersianFormat.daysFromNow(3), '۳ روز دیگر');
    expect(PersianFormat.daysFromNow(-5), '۵ روز پیش');
  });

  test('formats month and year', () {
    expect(PersianFormat.monthYear(DateTime(2026, 11, 27)), 'آذر ۱۴۰۵');
  });

  test('rounds durations to friendly units', () {
    expect(PersianFormat.roughDuration(0), '۱ روز');
    expect(PersianFormat.roughDuration(10), '۱۰ روز');
    expect(PersianFormat.roughDuration(21), '۳ هفته');
    expect(PersianFormat.roughDuration(120), '۴ ماه');
  });
}
