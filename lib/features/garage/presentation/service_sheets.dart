import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../../../core/ui/jalali_date_picker.dart';
import '../application/garage_controller.dart';
import '../domain/maintenance_planner.dart';
import '../domain/vehicle.dart';

/// Log one workshop visit: odometer, what was done (pre-ticked with what
/// was due), and an optional cost.
Future<void> showVisitSheet(
  BuildContext context, {
  required GarageController controller,
  required Vehicle vehicle,
  required List<String> preselected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _VisitSheet(
      controller: controller,
      vehicle: vehicle,
      preselected: preselected,
    ),
  );
}

/// Ask for what the dashboard shows now.
Future<void> showReadingSheet(
  BuildContext context, {
  required GarageController controller,
  required Vehicle vehicle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _ReadingSheet(controller: controller, vehicle: vehicle),
  );
}

/// A jump this large from the last reading is more likely a typo (an extra
/// digit) than real driving, so the user is asked to confirm it.
const _suspiciousJumpKm = 30000;

Future<bool> _confirmLargeJump(BuildContext context, int from, int to) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('این عدد درسته؟'),
      content: Text(
        '${PersianFormat.km(to - from)} بیشتر از عدد قبلی '
        '(${PersianFormat.number(from)}) هست. اگه رقم اضافه زدی، درستش کن.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('درستش می‌کنم'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('آره، درسته'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

EdgeInsets _sheetPadding(BuildContext context) => EdgeInsets.fromLTRB(
  20,
  0,
  20,
  20 + MediaQuery.viewInsetsOf(context).bottom,
);

class _ReadingSheet extends StatefulWidget {
  const _ReadingSheet({required this.controller, required this.vehicle});

  final GarageController controller;
  final Vehicle vehicle;

  @override
  State<_ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends State<_ReadingSheet> {
  final _km = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final km = PersianFormat.parseInt(_km.text);
    final last = widget.vehicle.lastReading.km;
    if (km == null) {
      setState(() => _error = 'عدد کیلومترشمار رو بنویس');
      return;
    }
    if (km < last) {
      setState(
        () => _error =
            'از عدد قبلی (${PersianFormat.number(last)}) کمتره؛ یه بار دیگه نگاه کن.',
      );
      return;
    }
    if (km - last > _suspiciousJumpKm &&
        !await _confirmLargeJump(context, last, km)) {
      return;
    }
    await widget.controller.addReading(widget.vehicle.id, km);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: _sheetPadding(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'کیلومترشمار الان چنده؟',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'عدد قبلی: ${PersianFormat.km(widget.vehicle.lastReading.km)}',
            style: text.bodyMedium?.copyWith(color: BrandColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('reading-km'),
            controller: _km,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              suffixText: 'کیلومتر',
              errorText: _error,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('ذخیره')),
        ],
      ),
    );
  }
}

class _VisitSheet extends StatefulWidget {
  const _VisitSheet({
    required this.controller,
    required this.vehicle,
    required this.preselected,
  });

  final GarageController controller;
  final Vehicle vehicle;
  final List<String> preselected;

  @override
  State<_VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends State<_VisitSheet> {
  late final _km = TextEditingController(
    text: PersianFormat.digits('${widget.vehicle.lastReading.km}'),
  );
  final _cost = TextEditingController();
  final _sticker = TextEditingController();
  late final Set<String> _selected = {...widget.preselected};
  bool _showAll = false;
  late DateTime _date = widget.controller.now;
  String? _kmError;
  String? _stickerError;
  String? _itemsError;
  bool _saving = false;

  @override
  void dispose() {
    _km.dispose();
    _cost.dispose();
    _sticker.dispose();
    super.dispose();
  }

  bool get _oilTicked => _selected.contains(MaintenancePlanner.engineOilPartId);

  List<String> _allParts() {
    final group = widget.controller.catalog.groupForModel(
      widget.vehicle.modelId,
    );
    if (group == null) return const [];
    return [
      for (final item in group.items)
        if (item.isSchedulable &&
            (Transmission.ofPart(item.partId) ?? widget.vehicle.transmission) ==
                widget.vehicle.transmission)
          item.partId,
    ];
  }

  Future<void> _save() async {
    final km = PersianFormat.parseInt(_km.text);
    if (km == null || km > 2000000) {
      setState(() => _kmError = 'کیلومتر رو بنویس');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _itemsError = 'حداقل یه کار رو تیک بزن');
      return;
    }
    final sticker = _oilTicked ? PersianFormat.parseInt(_sticker.text) : null;
    if (sticker != null) {
      final interval = sticker - km;
      if (interval < GarageController.minOilIntervalKm ||
          interval > GarageController.maxOilIntervalKm) {
        setState(
          () => _stickerError =
              'باید حدود ${PersianFormat.number(GarageController.minOilIntervalKm)} '
              'تا ${PersianFormat.number(GarageController.maxOilIntervalKm)} '
              'کیلومتر بیشتر از کیلومترشمار باشه',
        );
        return;
      }
    }
    final last = widget.vehicle.lastReading.km;
    if (km - last > _suspiciousJumpKm &&
        !await _confirmLargeJump(context, last, km)) {
      return;
    }
    if (!mounted) return;
    final toman = PersianFormat.parseInt(_cost.text);
    setState(() => _saving = true);
    await widget.controller.recordVisit(
      vehicleId: widget.vehicle.id,
      km: km,
      date: _date,
      partIds: [
        for (final id in _allParts())
          if (_selected.contains(id)) id,
      ],
      costRial: toman == null ? null : toman * 10,
      nextOilChangeKm: sticker,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final today = widget.controller.now;
    final picked = await showJalaliDatePicker(
      context,
      title: 'سرویس کِی انجام شد؟',
      initial: _date,
      yearsBack: 5,
      yearsAhead: 0,
    );
    if (picked == null) return;
    // A service can't be logged in the future.
    setState(() => _date = picked.isAfter(today) ? today : picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final catalog = widget.controller.catalog;
    final all = _allParts();
    final visible = _showAll
        ? all
        : [
            for (final id in all)
              if (widget.preselected.contains(id) || _selected.contains(id)) id,
          ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: _sheetPadding(context),
        children: [
          Text(
            'ثبت سرویس',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('visit-km'),
            controller: _km,
            keyboardType: TextInputType.number,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            onChanged: (_) => setState(() => _kmError = null),
            decoration: InputDecoration(
              labelText: 'کیلومترشمار موقع سرویس',
              suffixText: 'کیلومتر',
              errorText: _kmError,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('visit-date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined, size: 20),
              label: Text(
                MaintenancePlanner.daysBetween(_date, widget.controller.now) ==
                        0
                    ? 'امروز · ${PersianFormat.date(_date)}'
                    : PersianFormat.date(_date),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'چه کارهایی انجام دادی؟',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (_itemsError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _itemsError!,
                style: text.bodySmall?.copyWith(color: BrandColors.danger),
              ),
            ),
          const SizedBox(height: 8),
          for (final id in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CheckRow(
                label: catalog.part(id)?.nameFa ?? id,
                checked: _selected.contains(id),
                onChanged: (v) => setState(() {
                  _itemsError = null;
                  v ? _selected.add(id) : _selected.remove(id);
                }),
              ),
            ),
          if (!_showAll && visible.length < all.length)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _showAll = true),
                icon: const Icon(Icons.add),
                label: const Text('یه کار دیگه (تسمه، شمع، لنت…)'),
              ),
            ),
          if (_oilTicked) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('visit-sticker'),
              controller: _sticker,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _stickerError = null),
              decoration: InputDecoration(
                labelText: 'عدد برچسب جدید روغن (اختیاری)',
                hintText:
                    'مثلاً ${PersianFormat.number(widget.vehicle.lastReading.km + 6000)}',
                suffixText: 'کیلومتر',
                helperText: 'تعویض بعدی دقیقاً همین عدد می‌شه.',
                helperMaxLines: 2,
                errorText: _stickerError,
                errorMaxLines: 3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'چقدر شد؟ (اختیاری)',
              suffixText: 'تومان',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checked ? BrandColors.violetLight : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: checked ? Colors.transparent : BrandColors.violetBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: checked,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: BrandColors.violet,
        title: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
