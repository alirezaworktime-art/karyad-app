import 'package:material_ui/material_ui.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../format/persian_format.dart';

/// Asks for a Solar Hijri date with three dropdowns (day, month, year), the
/// way dates are written on Iranian documents. Returns the Gregorian date,
/// or null when cancelled. Years offered run around [initial].
Future<DateTime?> showJalaliDatePicker(
  BuildContext context, {
  required String title,
  required DateTime initial,
  int yearsBack = 1,
  int yearsAhead = 3,
}) {
  final start = Jalali.fromDateTime(initial);
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _JalaliDateDialog(
      title: title,
      initial: start,
      firstYear: start.year - yearsBack,
      lastYear: start.year + yearsAhead,
    ),
  );
}

class _JalaliDateDialog extends StatefulWidget {
  const _JalaliDateDialog({
    required this.title,
    required this.initial,
    required this.firstYear,
    required this.lastYear,
  });

  final String title;
  final Jalali initial;
  final int firstYear;
  final int lastYear;

  @override
  State<_JalaliDateDialog> createState() => _JalaliDateDialogState();
}

class _JalaliDateDialogState extends State<_JalaliDateDialog> {
  late int _year = widget.initial.year.clamp(widget.firstYear, widget.lastYear);
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;

  int get _monthLength => Jalali(_year, _month).monthLength;

  void _set({int? year, int? month, int? day}) {
    setState(() {
      _year = year ?? _year;
      _month = month ?? _month;
      _day = (day ?? _day).clamp(1, _monthLength);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Row(
        children: [
          Expanded(
            flex: 2,
            child: _Field<int>(
              label: 'روز',
              fieldKey: const Key('date-day'),
              value: _day,
              items: {
                for (var d = 1; d <= _monthLength; d++)
                  d: PersianFormat.digits('$d'),
              },
              onChanged: (v) => _set(day: v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _Field<int>(
              label: 'ماه',
              fieldKey: const Key('date-month'),
              value: _month,
              items: {
                for (var m = 1; m <= 12; m++) m: PersianFormat.monthName(m),
              },
              onChanged: (v) => _set(month: v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _Field<int>(
              label: 'سال',
              fieldKey: const Key('date-year'),
              value: _year,
              items: {
                for (var y = widget.firstYear; y <= widget.lastYear; y++)
                  y: PersianFormat.digits('$y'),
              },
              onChanged: (v) => _set(year: v),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(Jalali(_year, _month, _day).toDateTime()),
          child: const Text('ثبت'),
        ),
      ],
    );
  }
}

class _Field<T> extends StatelessWidget {
  const _Field({
    required this.label,
    required this.fieldKey,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final Key fieldKey;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // A controlled dropdown: the day list shrinks with the month, so the
    // value must follow state rather than a form field's initial value.
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: fieldKey,
          value: value,
          isExpanded: true,
          items: [
            for (final e in items.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
