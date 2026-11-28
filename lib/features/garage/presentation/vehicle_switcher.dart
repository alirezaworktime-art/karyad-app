import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../../catalog/domain/body_type.dart';
import '../application/garage_controller.dart';
import '../domain/vehicle.dart';
import 'onboarding_screen.dart';
import 'widgets/car_illustration.dart';

/// Opens the add-a-car steps on top of the app; they close themselves when
/// the car is saved (it becomes the active car) or the user backs out.
Future<void> openAddVehicle(BuildContext context, GarageController controller) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => OnboardingScreen(
        controller: controller,
        addingAnother: true,
        onExit: () => Navigator.of(routeContext).pop(),
      ),
    ),
  );
}

/// Every car, to switch between them or add one.
Future<void> showVehicleSheet(
  BuildContext context,
  GarageController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _VehicleSheet(
      controller: controller,
      onAdd: () {
        Navigator.of(sheetContext).pop();
        openAddVehicle(context, controller);
      },
    ),
  );
}

class _VehicleSheet extends StatelessWidget {
  const _VehicleSheet({required this.controller, required this.onAdd});

  final GarageController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final active = controller.activeVehicle;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'ماشین‌هات',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            for (final vehicle in controller.vehicles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _VehicleTile(
                  vehicle: vehicle,
                  name: controller.displayName(vehicle),
                  modelName:
                      controller.catalog.model(vehicle.modelId)?.nameFa ?? '',
                  selected: vehicle.id == active?.id,
                  onTap: () {
                    controller.selectVehicle(vehicle.id);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              key: const Key('add-vehicle'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('یه ماشین دیگه اضافه کن'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.name,
    required this.modelName,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final String name;
  final String modelName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected ? BrandColors.violetLight : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? BrandColors.violet : BrandColors.violetBorder,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CarIllustration(
                bodyType: BodyTypes.of(vehicle.modelId),
                color: Color(vehicle.color.argb),
                taxiSign: vehicle.usage == VehicleUsage.work,
                width: 84,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        if (name != modelName) modelName,
                        PersianFormat.km(vehicle.lastReading.km),
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(color: BrandColors.muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: BrandColors.violet),
            ],
          ),
        ),
      ),
    );
  }
}
