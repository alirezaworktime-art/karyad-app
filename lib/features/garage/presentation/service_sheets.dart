import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../application/garage_controller.dart';
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
      setState(() => _error = 'عدد کیلومترشمار را بنویس');
      return;
    }
    if (km < last) {
      setState(
        () => _error =
            'از عدد قبلی (${PersianFormat.number(last)}) کمتر است؛ دوباره نگاه کن.',
      );
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
            'کیلومترشمار الان چند است؟',
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
  late final Set<String> _selected = {...widget.preselected};
  bool _showAll = false;
  String? _kmError;
  String? _itemsError;
  bool _saving = false;

  @override
  void dispose() {
    _km.dispose();
    _cost.dispose();
    super.dispose();
  }

  List<String> _allParts() {
    final group = widget.controller.catalog.groupForModel(
      widget.vehicle.modelId,
    );
    if (group == null) return const [];
    return [
      for (final item in group.items)
        if (item.isSchedulable) item.partId,
    ];
  }

  Future<void> _save() async {
    final km = PersianFormat.parseInt(_km.text);
    if (km == null) {
      setState(() => _kmError = 'کیلومتر را بنویس');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _itemsError = 'حداقل یک کار را تیک بزن');
      return;
    }
    final toman = PersianFormat.parseInt(_cost.text);
    setState(() => _saving = true);
    await widget.controller.recordVisit(
      vehicleId: widget.vehicle.id,
      km: km,
      partIds: [
        for (final id in _allParts())
          if (_selected.contains(id)) id,
      ],
      costRial: toman == null ? null : toman * 10,
    );
    if (mounted) Navigator.of(context).pop();
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
              labelText: 'کیلومترشمار هنگام سرویس',
              suffixText: 'کیلومتر',
              errorText: _kmError,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'چه کارهایی انجام شد؟',
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
                label: const Text('کار دیگر (تسمه، شمع، لنت…)'),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'هزینه (اختیاری)',
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
