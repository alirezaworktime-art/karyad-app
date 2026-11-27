import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../../catalog/domain/catalog.dart';
import '../application/garage_controller.dart';
import '../domain/maintenance_planner.dart';
import '../domain/vehicle.dart';
import 'emergency_sheet.dart';
import 'service_sheets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final GarageController controller;

  @override
  Widget build(BuildContext context) {
    final vehicle = controller.primaryVehicle!;
    final catalog = controller.catalog;
    final model = catalog.model(vehicle.modelId);
    final group = catalog.groupForModel(vehicle.modelId);
    final maker = group == null ? null : catalog.maker(group.makerId);
    final dues = controller.duesFor(vehicle);
    final estimatedKm = controller.estimatedOdometer(vehicle);
    final attention = dues.where((d) => d.status != DueStatus.ok).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('کاریاد'),
        actions: [
          IconButton(
            tooltip: 'امداد خودرو',
            icon: const Icon(Icons.sos_outlined),
            onPressed: () => showEmergencySheet(context, maker: maker),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _VehicleHeader(
              name: vehicle.nickname ?? model?.nameFa ?? '',
              estimatedKm: estimatedKm,
              isWork: vehicle.usage == VehicleUsage.work,
              attention: attention,
              onUpdateKm: () => showOdometerSheet(
                context,
                controller: controller,
                vehicle: vehicle,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'سرویس‌های پیش رو',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final due in dues)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DueCard(
                  due: due,
                  partName:
                      catalog.part(due.item.partId)?.nameFa ?? due.item.partId,
                  onDone: () => showRecordServiceSheet(
                    context,
                    controller: controller,
                    vehicle: vehicle,
                    partId: due.item.partId,
                    partName: catalog.part(due.item.partId)?.nameFa ?? '',
                  ),
                ),
              ),
            if (group != null) ...[
              const SizedBox(height: 8),
              Text(
                'منبع: ${group.sourceFa}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({
    required this.name,
    required this.estimatedKm,
    required this.isWork,
    required this.attention,
    required this.onUpdateKm,
  });

  final String name;
  final int estimatedKm;
  final bool isWork;
  final int attention;
  final VoidCallback onUpdateKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isWork)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: onPrimary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'حالت کاری',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'کیلومتر تخمینی',
            style: theme.textTheme.bodySmall?.copyWith(
              color: onPrimary.withValues(alpha: 0.8),
            ),
          ),
          Text(
            PersianFormat.km(estimatedKm),
            style: theme.textTheme.titleLarge?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  attention == 0
                      ? 'همه‌چیز مرتب است'
                      : '${PersianFormat.number(attention)} مورد نیاز به توجه',
                  style: theme.textTheme.bodyMedium?.copyWith(color: onPrimary),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onUpdateKm,
                style: OutlinedButton.styleFrom(
                  foregroundColor: onPrimary,
                  side: BorderSide(color: onPrimary.withValues(alpha: 0.6)),
                ),
                icon: const Icon(Icons.speed_outlined),
                label: const Text('ثبت کیلومتر'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({
    required this.due,
    required this.partName,
    required this.onDone,
  });

  final MaintenanceDue due;
  final String partName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (due.status) {
      DueStatus.overdue => ('گذشته', BrandColors.coralText),
      DueStatus.dueSoon => ('نزدیک', BrandColors.coral),
      DueStatus.ok => ('مرتب', theme.colorScheme.primary),
    };
    final details = <String>[
      if (due.remainingKm != null)
        due.remainingKm! > 0
            ? '${PersianFormat.km(due.remainingKm!)} دیگر'
            : '${PersianFormat.km(-due.remainingKm!)} گذشته',
      if (due.remainingDays != null)
        PersianFormat.daysFromNow(due.remainingDays!),
    ];
    final isApproximate = due.item.confidence != Confidence.official;
    final actionLabel = switch (due.item.action) {
      MaintenanceAction.inspect => 'بازدید شد',
      _ => 'انجام شد',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          partName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(details.join(' · '), style: theme.textTheme.bodySmall),
                  if (isApproximate || !due.hasServiceRecord)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          if (isApproximate) 'تقریبی',
                          if (!due.hasServiceRecord) 'از روز ثبت ماشین',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onDone, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
