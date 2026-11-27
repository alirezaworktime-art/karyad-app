import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/ui/responsive_body.dart';
import '../../catalog/domain/body_type.dart';
import '../application/garage_controller.dart';
import '../domain/vehicle.dart';
import 'widgets/car_illustration.dart';

/// Car settings: color, use, oil type, and starting over.
class CarTab extends StatelessWidget {
  const CarTab({super.key, required this.controller});

  final GarageController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = text.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final vehicle = controller.primaryVehicle;
        if (vehicle == null) return const SizedBox.shrink();
        final model = controller.catalog.model(vehicle.modelId);

        return ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'ماشین من',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
                      model?.nameFa ?? '',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  value: vehicle.usage == VehicleUsage.work,
                  onChanged: (v) => controller.updateVehicle(
                    vehicle.id,
                    usage: v ? VehicleUsage.work : VehicleUsage.personal,
                  ),
                  title: Text('مسافرکشی می‌کنم', style: label),
                  subtitle: const Text('سرویس‌ها طبق «شرایط سخت» کارخانه'),
                ),
              ),
              const SizedBox(height: 20),
              Text('نوع روغن موتور', style: label),
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
                'نمی‌دانی؟ از تعویض‌روغنی بپرس؛ روغن معدنی زودتر عوض می‌شود.',
                style: text.bodySmall?.copyWith(color: BrandColors.muted),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => _confirmReset(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandColors.danger,
                  side: const BorderSide(color: BrandColors.danger),
                ),
                child: const Text('حذف ماشین و شروع دوباره'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('همه‌چیز پاک شود؟'),
        content: const Text(
          'ماشین و همه‌ی سوابق سرویس از این گوشی پاک می‌شود و قابل برگشت نیست.',
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
    if (ok ?? false) await controller.resetAll();
  }
}
