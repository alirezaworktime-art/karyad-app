import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../../../core/ui/responsive_body.dart';
import '../../catalog/domain/catalog.dart';
import '../application/garage_controller.dart';
import '../domain/maintenance_planner.dart';
import '../domain/vehicle.dart';
import 'emergency_sheet.dart';
import 'service_sheets.dart';

/// The one screen most users live on: what needs doing next, most urgent
/// first, and a single tap to log it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final GarageController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showOk = false;

  GarageController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final vehicle = _controller.primaryVehicle!;
    final catalog = _controller.catalog;
    final model = catalog.model(vehicle.modelId);
    final group = catalog.groupForModel(vehicle.modelId);
    final maker = group == null ? null : catalog.maker(group.makerId);
    final dues = _controller.duesFor(vehicle);

    final attention = [
      for (final d in dues)
        if (d.status == DueStatus.overdue || d.status == DueStatus.dueSoon) d,
    ];
    final unknown = [
      for (final d in dues)
        if (d.status == DueStatus.unknown) d,
    ];
    final ok = [
      for (final d in dues)
        if (d.status == DueStatus.ok) d,
    ];
    final next = attention.isNotEmpty
        ? attention.first
        : (ok.isNotEmpty ? ok.first : null);

    String partName(MaintenanceDue d) =>
        catalog.part(d.item.partId)?.nameFa ?? d.item.partId;

    void logService(MaintenanceDue d) => showRecordServiceSheet(
      context,
      controller: _controller,
      vehicle: vehicle,
      partId: d.item.partId,
      partName: partName(d),
    );

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
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _HeroCard(
                carName: vehicle.nickname ?? model?.nameFa ?? '',
                isWork: vehicle.usage == VehicleUsage.work,
                estimatedKm: _controller.estimatedOdometer(vehicle),
                next: next,
                nextName: next == null ? null : partName(next),
                onUpdateKm: () => showOdometerSheet(
                  context,
                  controller: _controller,
                  vehicle: vehicle,
                ),
              ),
              if (attention.isNotEmpty) ...[
                const _SectionTitle(
                  title: 'نیاز به توجه',
                  icon: Icons.error_outline,
                ),
                for (final d in attention)
                  _DueTile(
                    due: d,
                    name: partName(d),
                    onDone: () => logService(d),
                  ),
              ],
              if (unknown.isNotEmpty) ...[
                const _SectionTitle(
                  title: 'آخرین بار کی انجام شد؟',
                  icon: Icons.help_outline,
                  subtitle: 'اگر یادت هست ثبتش کن؛ وگرنه «از امروز» را بزن تا از همین حالا حساب شود.',
                ),
                for (final d in unknown)
                  _UnknownTile(
                    name: partName(d),
                    intervalText: _intervalText(d),
                    onLog: () => logService(d),
                    onFromToday: () => _controller.startTrackingFromNow(
                      vehicleId: vehicle.id,
                      partId: d.item.partId,
                    ),
                  ),
              ],
              if (ok.isNotEmpty) ...[
                _SectionTitle(
                  title: 'مرتب',
                  icon: Icons.check_circle_outline,
                  trailing: TextButton(
                    onPressed: () => setState(() => _showOk = !_showOk),
                    child: Text(
                      _showOk
                          ? 'بستن'
                          : 'نمایش ${PersianFormat.number(ok.length)} مورد',
                    ),
                  ),
                ),
                if (_showOk)
                  for (final d in ok)
                    _DueTile(
                      due: d,
                      name: partName(d),
                      onDone: () => logService(d),
                    ),
              ],
              if (group != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'زمان‌ها طبق ${group.sourceFa}'
                    '${vehicle.usesSevereSchedule ? ' (شرایط سخت)' : ''}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _intervalText(MaintenanceDue d) => [
    if (d.intervalKm != null) 'هر ${PersianFormat.km(d.intervalKm!)}',
    if (d.intervalMonths != null)
      'هر ${PersianFormat.number(d.intervalMonths!)} ماه',
  ].join(' یا ');
}

/// Remaining distance and time in one short line.
String _remainingText(MaintenanceDue d) {
  final parts = <String>[
    if (d.remainingKm != null)
      d.remainingKm! > 0
          ? '${PersianFormat.km(d.remainingKm!)} مانده'
          : '${PersianFormat.km(-d.remainingKm!)} گذشته',
    if (d.remainingDays != null) PersianFormat.daysFromNow(d.remainingDays!),
  ];
  return parts.join(' · ');
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.carName,
    required this.isWork,
    required this.estimatedKm,
    required this.next,
    required this.nextName,
    required this.onUpdateKm,
  });

  final String carName;
  final bool isWork;
  final int estimatedKm;
  final MaintenanceDue? next;
  final String? nextName;
  final VoidCallback onUpdateKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const fg = Colors.white;
    final soft = fg.withValues(alpha: 0.78);
    final next = this.next;
    final urgent = next != null && next.status == DueStatus.overdue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BrandColors.teal,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  carName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: fg,
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
                    color: fg.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'حالت کاری',
                    style: theme.textTheme.labelMedium?.copyWith(color: fg),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (next != null && nextName != null) ...[
            Text(
              urgent ? 'وقتش گذشته' : 'سرویس بعدی',
              style: theme.textTheme.bodyMedium?.copyWith(color: soft),
            ),
            const SizedBox(height: 2),
            Text(
              nextName!,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (urgent)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    decoration: const BoxDecoration(
                      color: BrandColors.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                Flexible(
                  child: Text(
                    _remainingText(next),
                    style: theme.textTheme.titleSmall?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'سابقه‌ی سرویس‌ها را ثبت کن تا موعد بعدی را بگوییم.',
              style: theme.textTheme.bodyLarge?.copyWith(color: fg),
            ),
          const SizedBox(height: 18),
          Container(height: 1, color: fg.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.speed_outlined, color: fg, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${PersianFormat.km(estimatedKm)} (تخمینی)',
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ),
              TextButton(
                onPressed: onUpdateKm,
                style: TextButton.styleFrom(foregroundColor: fg),
                child: const Text('به‌روزرسانی'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 28, top: 2),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.due, required this.name, required this.onDone});

  final MaintenanceDue due;
  final String name;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (due.status) {
      DueStatus.overdue => ('گذشته', BrandColors.coralText),
      DueStatus.dueSoon => ('نزدیک', BrandColors.coral),
      _ => ('مرتب', theme.colorScheme.primary),
    };
    final approximate = due.item.confidence != Confidence.official;
    final actionLabel = due.item.action == MaintenanceAction.inspect
        ? 'بازدید شد'
        : 'انجام شد';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        label,
                        _remainingText(due),
                        if (approximate) 'تقریبی',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onDone, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnknownTile extends StatelessWidget {
  const _UnknownTile({
    required this.name,
    required this.intervalText,
    required this.onLog,
    required this.onFromToday,
  });

  final String name;
  final String intervalText;
  final VoidCallback onLog;
  final VoidCallback onFromToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                intervalText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onFromToday,
                    child: const Text('از امروز'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonal(
                    onPressed: onLog,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    child: const Text('ثبت آخرین بار'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
