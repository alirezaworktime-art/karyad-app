import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../../../core/ui/responsive_body.dart';
import '../../catalog/domain/body_type.dart';
import '../application/garage_controller.dart';
import 'document_actions.dart';
import 'vehicle_switcher.dart';
import '../domain/vehicle.dart';
import 'widgets/car_illustration.dart';

/// Settings: the car, its oil, its documents, and starting over.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.controller});

  final GarageController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final vehicle = controller.activeVehicle;
        if (vehicle == null) return const SizedBox.shrink();
        final model = controller.catalog.model(vehicle.modelId);

        return ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'تنظیمات',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BrandColors.violetLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CarIllustration(
                      bodyType: BodyTypes.of(vehicle.modelId),
                      color: Color(vehicle.color.argb),
                      taxiSign: vehicle.usage == VehicleUsage.work,
                      width: 220,
                    ),
                    Text(
                      controller.displayName(vehicle),
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (vehicle.nickname != null)
                      Text(
                        model?.nameFa ?? '',
                        style: text.bodySmall?.copyWith(
                          color: BrandColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle('ماشین'),
              const SizedBox(height: 4),
              ListTile(
                key: const Key('rename-vehicle'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.edit_outlined,
                  color: BrandColors.violet,
                ),
                title: Text(vehicle.nickname ?? 'یه اسم براش بذار'),
                subtitle: const Text(
                  'مثلاً «ماشین بابا» یا «پراید کار»، که قاطی نشن',
                ),
                onTap: () => _rename(context, vehicle),
              ),
              const SizedBox(height: 6),
              Text('رنگ', style: label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in CarColor.values)
                    ChoiceChip(
                      label: Text(c.nameFa),
                      selected: c == vehicle.color,
                      avatar: CircleAvatar(backgroundColor: Color(c.argb)),
                      onSelected: (_) =>
                          controller.updateVehicle(vehicle.id, color: c),
                    ),
                ],
              ),
              if (controller
                  .transmissionChoices(vehicle.modelId)
                  .isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('گیربکس', style: label),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in controller.transmissionChoices(
                      vehicle.modelId,
                    ))
                      ChoiceChip(
                        label: Text(t.nameFa),
                        selected: t == vehicle.transmission,
                        onSelected: (_) => controller.updateVehicle(
                          vehicle.id,
                          transmission: t,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  value: vehicle.usage == VehicleUsage.work,
                  onChanged: (v) => controller.updateVehicle(
                    vehicle.id,
                    usage: v ? VehicleUsage.work : VehicleUsage.personal,
                  ),
                  title: Text('مسافرکشی می‌کنم', style: label),
                  subtitle: const Text('سرویس‌ها طبق «شرایط سخت» کارخونه'),
                ),
              ),
              const SizedBox(height: 28),
              _SectionTitle('روغن موتور'),
              const SizedBox(height: 10),
              _OilSettings(controller: controller, vehicle: vehicle),
              const SizedBox(height: 28),
              _SectionTitle('بیمه و معاینه‌ی فنی'),
              const SizedBox(height: 4),
              Text(
                'یه ماه مونده به تموم شدنش، تو صفحه‌ی «خانه» یادت میندازیم.',
                style: text.bodySmall?.copyWith(color: BrandColors.muted),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    for (final document in VehicleDocument.values)
                      _DocumentTile(
                        controller: controller,
                        vehicle: vehicle,
                        document: document,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => openAddVehicle(context, controller),
                icon: const Icon(Icons.add),
                label: const Text('یه ماشین دیگه اضافه کن'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('remove-vehicle'),
                onPressed: () => _confirmRemove(context, vehicle),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.danger,
                  side: const BorderSide(color: BrandColors.danger),
                ),
                child: Text('حذف ${controller.displayName(vehicle)}'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, Vehicle vehicle) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: vehicle.nickname ?? ''),
    );
    if (name != null) await controller.renameVehicle(vehicle.id, name);
  }

  Future<void> _confirmRemove(BuildContext context, Vehicle vehicle) async {
    final last = controller.vehicles.length == 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${controller.displayName(vehicle)} پاک بشه؟'),
        content: Text(
          last
              ? 'ماشین و همه‌ی سوابقش از این گوشی پاک می‌شه و برنمی‌گرده. بعدش از اول شروع می‌کنی.'
              : 'این ماشین و همه‌ی سوابقش از این گوشی پاک می‌شه و برنمی‌گرده. بقیه‌ی ماشین‌ها سر جاشون می‌مونن.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('نه'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
            child: const Text('پاک کن'),
          ),
        ],
      ),
    );
    if (ok ?? false) await controller.removeVehicle(vehicle.id);
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اسم ماشین'),
      content: TextField(
        key: const Key('vehicle-name'),
        controller: _field,
        autofocus: true,
        maxLength: 24,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        decoration: const InputDecoration(
          hintText: 'خالی بذاری، اسم مدل نشون داده می‌شه',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('بی‌خیال'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: const Text('ذخیره'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800),
  );
}

/// Oil type, or the user's own interval when their mechanic gave one.
class _OilSettings extends StatelessWidget {
  const _OilSettings({required this.controller, required this.vehicle});

  final GarageController controller;
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final custom = vehicle.oilIntervalKm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: SwitchListTile(
            key: const Key('custom-oil-switch'),
            value: custom != null,
            onChanged: (on) => on
                ? _editInterval(context)
                : controller.setOilInterval(vehicle.id, null),
            title: Text(
              'فاصله‌ی تعویض رو خودم تعیین می‌کنم',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              custom == null
                  ? 'مثلاً اگه تعمیرکار گفته هر ۶٬۰۰۰ کیلومتر'
                  : 'هر ${PersianFormat.km(custom)}',
            ),
          ),
        ),
        if (custom != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _editInterval(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('عوض کردن عدد'),
            ),
          )
        else ...[
          const SizedBox(height: 12),
          Text(
            'نوع روغن',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SegmentedButton<OilType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: OilType.mineral, label: Text('معدنی')),
              ButtonSegment(
                value: OilType.semiSynthetic,
                label: Text('نیمه‌سنتتیک'),
              ),
              ButtonSegment(
                value: OilType.fullSynthetic,
                label: Text('تمام‌سنتتیک'),
              ),
            ],
            selected: {vehicle.oilType},
            onSelectionChanged: (s) =>
                controller.updateVehicle(vehicle.id, oilType: s.first),
          ),
          const SizedBox(height: 6),
          Text(
            'نمی‌دونی؟ از تعویض‌روغنی بپرس؛ روغن معدنی زودتر عوض می‌شه.',
            style: text.bodySmall?.copyWith(color: BrandColors.muted),
          ),
        ],
      ],
    );
  }

  Future<void> _editInterval(BuildContext context) async {
    final km = await showDialog<int>(
      context: context,
      builder: (_) => _OilIntervalDialog(initial: vehicle.oilIntervalKm),
    );
    if (km != null) await controller.setOilInterval(vehicle.id, km);
  }
}

class _OilIntervalDialog extends StatefulWidget {
  const _OilIntervalDialog({required this.initial});

  final int? initial;

  @override
  State<_OilIntervalDialog> createState() => _OilIntervalDialogState();
}

class _OilIntervalDialogState extends State<_OilIntervalDialog> {
  late final _field = TextEditingController(
    text: widget.initial == null ? '' : PersianFormat.number(widget.initial!),
  );
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final km = PersianFormat.parseInt(_field.text);
    if (km == null ||
        km < GarageController.minOilIntervalKm ||
        km > GarageController.maxOilIntervalKm) {
      setState(
        () => _error =
            'عددی بین ${PersianFormat.number(GarageController.minOilIntervalKm)} '
            'و ${PersianFormat.number(GarageController.maxOilIntervalKm)} بنویس',
      );
      return;
    }
    Navigator.of(context).pop(km);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('هر چند کیلومتر روغن عوض بشه؟'),
      content: TextField(
        key: const Key('oil-interval'),
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          hintText: '۶٬۰۰۰',
          suffixText: 'کیلومتر',
          errorText: _error,
          errorMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('بی‌خیال'),
        ),
        FilledButton(onPressed: _save, child: const Text('ثبت')),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.controller,
    required this.vehicle,
    required this.document,
  });

  final GarageController controller;
  final Vehicle vehicle;
  final VehicleDocument document;

  @override
  Widget build(BuildContext context) {
    final expiry = vehicle.documentExpiry[document];
    return ListTile(
      key: Key('document-${document.name}'),
      leading: Icon(documentIcon(document), color: BrandColors.violet),
      title: Text(document.nameFa),
      subtitle: Text(
        expiry == null ? 'ثبت نشده' : 'اعتبار تا ${PersianFormat.date(expiry)}',
      ),
      trailing: expiry == null
          ? const Icon(Icons.add, color: BrandColors.violet)
          : IconButton(
              tooltip: 'پاک کردن تاریخ',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  controller.setDocumentExpiry(vehicle.id, document, null),
            ),
      onTap: () => pickDocumentExpiry(context, controller, vehicle, document),
    );
  }
}
