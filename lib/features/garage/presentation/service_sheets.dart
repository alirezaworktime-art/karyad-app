import 'package:material_ui/material_ui.dart';

import '../../../core/format/persian_format.dart';
import '../application/garage_controller.dart';
import '../domain/vehicle.dart';

/// Asks for the odometer and optional cost, then logs the service.
Future<void> showRecordServiceSheet(
  BuildContext context, {
  required GarageController controller,
  required Vehicle vehicle,
  required String partId,
  required String partName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _NumberSheet(
      title: partName,
      subtitle: 'در چه کیلومتری انجام شد؟ اگر قبلاً بوده، همان عدد را بنویس.',
      initialKm: controller.estimatedOdometer(vehicle),
      minKm: 0,
      showCost: true,
      confirmLabel: 'ثبت',
      onConfirm: (km, cost) => controller.recordService(
        vehicleId: vehicle.id,
        partId: partId,
        km: km,
        costRial: cost,
      ),
    ),
  );
}

/// Lets the user correct the estimated odometer with the real reading.
Future<void> showOdometerSheet(
  BuildContext context, {
  required GarageController controller,
  required Vehicle vehicle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _NumberSheet(
      title: 'کیلومتر فعلی',
      subtitle: 'عدد کیلومترشمار را وارد کن تا یادآورها دقیق بمانند.',
      initialKm: controller.estimatedOdometer(vehicle),
      minKm: vehicle.trackingStart.km,
      showCost: false,
      confirmLabel: 'ذخیره',
      onConfirm: (km, _) => controller.updateOdometer(vehicle.id, km),
    ),
  );
}

class _NumberSheet extends StatefulWidget {
  const _NumberSheet({
    required this.title,
    required this.subtitle,
    required this.initialKm,
    required this.minKm,
    required this.showCost,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final String subtitle;
  final int initialKm;
  final int minKm;
  final bool showCost;
  final String confirmLabel;
  final Future<void> Function(int km, int? costRial) onConfirm;

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late final _km = TextEditingController(
    text: PersianFormat.digits('${widget.initialKm}'),
  );
  final _cost = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _km.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final km = PersianFormat.parseInt(_km.text);
    if (km == null) {
      setState(() => _error = 'کیلومتر را وارد کنید');
      return;
    }
    if (km < widget.minKm) {
      setState(
        () => _error =
            'کمتر از کیلومتر روز ثبت ماشین (${PersianFormat.number(widget.minKm)}) است',
      );
      return;
    }
    final costToman = PersianFormat.parseInt(_cost.text);
    setState(() => _saving = true);
    await widget.onConfirm(km, costToman == null ? null : costToman * 10);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(widget.subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _km,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'کیلومتر',
              suffixText: 'کیلومتر',
              errorText: _error,
            ),
          ),
          if (widget.showCost) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'هزینه (اختیاری)',
                suffixText: 'تومان',
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
