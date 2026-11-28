import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../../../core/ui/responsive_body.dart';
import '../../catalog/domain/body_type.dart';
import '../../catalog/domain/catalog.dart';
import '../application/garage_controller.dart';
import '../domain/maintenance_planner.dart';
import '../domain/vehicle.dart';
import 'document_actions.dart';
import 'emergency_sheet.dart';
import 'service_sheets.dart';
import 'widgets/car_illustration.dart';

/// What the user opens the app for: when the next service is, in km and
/// date they can check against the dashboard and calendar.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.controller});

  final GarageController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final vehicle = controller.primaryVehicle;
        if (vehicle == null) return const SizedBox.shrink();
        final catalog = controller.catalog;
        final group = catalog.groupForModel(vehicle.modelId);
        final maker = group == null ? null : catalog.maker(group.makerId);
        final plan = controller.planFor(vehicle);
        String partName(String id) => catalog.part(id)?.nameFa ?? id;
        // Inspect-only items say so, so nobody pays for a replacement.
        String dueName(MaintenanceDue d) =>
            d.item.action == MaintenanceAction.inspect
            ? 'بازدید ${partName(d.partId)}'
            : partName(d.partId);

        return ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'کاریاد',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: BrandColors.violet,
                      ),
                    ),
                  ),
                  _SosButton(
                    onPressed: () => showEmergencySheet(context, maker: maker),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CarCard(
                vehicle: vehicle,
                modelName: catalog.model(vehicle.modelId)?.nameFa ?? '',
                now: controller.now,
                onNewReading: () => showReadingSheet(
                  context,
                  controller: controller,
                  vehicle: vehicle,
                ),
              ),
              if (controller.readingIsStale(vehicle)) ...[
                const SizedBox(height: 12),
                _ReadingPrompt(
                  onTap: () => showReadingSheet(
                    context,
                    controller: controller,
                    vehicle: vehicle,
                  ),
                ),
              ],
              for (final status in controller.documentsToRenew(vehicle)) ...[
                const SizedBox(height: 12),
                _DocumentAlert(
                  status: status,
                  onRenewed: () => pickDocumentExpiry(
                    context,
                    controller,
                    vehicle,
                    status.document,
                  ),
                ),
              ],
              if (plan?.nextVisit != null) ...[
                const SizedBox(height: 12),
                _NextVisitCard(
                  visit: plan!.nextVisit!,
                  odometerKm: plan.odometerKm,
                  learnedDailyKm: vehicle.learnedDailyKm,
                  now: controller.now,
                  dueName: dueName,
                  onDone: () => showVisitSheet(
                    context,
                    controller: controller,
                    vehicle: vehicle,
                    preselected: [
                      for (final d in plan.nextVisit!.items) d.partId,
                    ],
                  ),
                ),
              ],
              if (plan != null && plan.later.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'بعدی‌ها',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'اگر یکی را قبلاً عوض کرده‌ای، رویش بزن تا ثبت شود.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: BrandColors.muted),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < plan.later.length; i++) ...[
                        if (i > 0) const Divider(),
                        _LaterRow(
                          due: plan.later[i],
                          name: dueName(plan.later[i]),
                          onTap: () => showVisitSheet(
                            context,
                            controller: controller,
                            vehicle: vehicle,
                            preselected: [plan.later[i].partId],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'بیمه و معاینه‌ی فنی',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final document in VehicleDocument.values)
                      _DocumentRow(
                        document: document,
                        status: controller
                            .documentsFor(vehicle)
                            .where((d) => d.document == document)
                            .firstOrNull,
                        onTap: () => pickDocumentExpiry(
                          context,
                          controller,
                          vehicle,
                          document,
                        ),
                      ),
                  ],
                ),
              ),
              if (group != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'زمان‌ها طبق ${group.sourceFa}'
                    '${vehicle.usesSevereSchedule ? ' (شرایط سخت)' : ''}.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: BrandColors.muted),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// "در ۷۲٬۰۰۰ کیلومتر یا تا ۱۵ اسفند ۱۴۰۵" style target, as parts.
String targetText(MaintenanceDue due, {bool short = false}) {
  final km = due.dueKm;
  final date = due.dueDate;
  if (km != null && date != null) {
    return short
        ? 'در ${PersianFormat.number(km)} · تا ${PersianFormat.monthYear(date)}'
        : 'در ${PersianFormat.km(km)} یا تا ${PersianFormat.date(date)}';
  }
  if (km != null) return 'در ${PersianFormat.number(km)}';
  return 'تا ${PersianFormat.monthYear(date!)}';
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'امداد خودرو',
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 44),
          foregroundColor: BrandColors.danger,
          side: const BorderSide(color: BrandColors.danger, width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: const Text('امداد'),
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.vehicle,
    required this.modelName,
    required this.now,
    required this.onNewReading,
  });

  final Vehicle vehicle;
  final String modelName;
  final DateTime now;
  final VoidCallback onNewReading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reading = vehicle.lastReading;
    final daysAgo = MaintenancePlanner.daysBetween(reading.date, now);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: BrandColors.violetLight,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          CarIllustration(
            bodyType: BodyTypes.of(vehicle.modelId),
            color: Color(vehicle.color.argb),
            taxiSign: vehicle.usage == VehicleUsage.work,
            width: 250,
            semanticLabel: '$modelName ${vehicle.color.nameFa}',
          ),
          const SizedBox(height: 4),
          Text(
            vehicle.nickname ?? modelName,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  text: 'کیلومترشمار ',
                  style: text.bodyMedium?.copyWith(color: BrandColors.muted),
                  children: [
                    TextSpan(
                      text: PersianFormat.number(reading.km),
                      style: const TextStyle(
                        color: BrandColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: ' · ${PersianFormat.daysFromNow(-daysAgo)}'),
                  ],
                ),
              ),
              TextButton(
                onPressed: onNewReading,
                child: const Text('ثبت جدید'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingPrompt extends StatelessWidget {
  const _ReadingPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.amberBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'کیلومترشمار الان چند است؟',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'یک عدد بنویس تا یادآورها دقیق بمانند.',
                  style: text.bodySmall?.copyWith(color: BrandColors.amberText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size(72, 44),
              backgroundColor: BrandColors.amberText,
            ),
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
  }
}

class _NextVisitCard extends StatelessWidget {
  const _NextVisitCard({
    required this.visit,
    required this.odometerKm,
    required this.learnedDailyKm,
    required this.now,
    required this.partName,
    required this.onDone,
  });

  final ServiceVisit visit;
  final int odometerKm;
  final double? learnedDailyKm;
  final DateTime now;
  final String Function(MaintenanceDue) dueName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = visit.status;
    final (heading, headingColor) = switch (status) {
      DueStatus.overdue => ('وقت سرویس رسیده', BrandColors.danger),
      DueStatus.dueSoon => ('سرویس نزدیک است', BrandColors.amberText),
      DueStatus.ok => ('سرویس بعدی', BrandColors.violet),
    };
    final km = visit.dueKm;
    final date = visit.dueDate;
    final lead = visit.lead;
    final pace = learnedDailyKm;
    final kmLeft = km == null ? null : km - odometerKm;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: text.titleSmall?.copyWith(
                color: headingColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (km != null)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'در  ',
                      style: text.titleMedium?.copyWith(
                        color: BrandColors.muted,
                      ),
                    ),
                    TextSpan(
                      text: PersianFormat.number(km),
                      style: text.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: BrandColors.ink,
                      ),
                    ),
                    TextSpan(
                      text: '  کیلومتر',
                      style: text.titleMedium?.copyWith(
                        color: BrandColors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else if (date != null)
              Text(
                'تا ${PersianFormat.date(date)}',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (km != null && date != null)
              Text.rich(
                TextSpan(
                  text: 'یا تا ',
                  style: text.bodyLarge?.copyWith(color: BrandColors.muted),
                  children: [
                    TextSpan(
                      text: PersianFormat.date(date),
                      style: const TextStyle(
                        color: BrandColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: ' — هر کدام زودتر'),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in visit.items)
                  Chip(label: Text(dueName(d))),
              ],
            ),
            if (lead.periodKm != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: lead.kmProgress(odometerKm),
                  minHeight: 8,
                  color: status == DueStatus.overdue
                      ? BrandColors.danger
                      : BrandColors.violet,
                  backgroundColor: BrandColors.violetDivider,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _progressText(lead, kmLeft, pace, date),
                style: text.bodySmall?.copyWith(color: BrandColors.muted),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                child: const Text('سرویس را انجام دادم'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _progressText(
    MaintenanceDue lead,
    int? kmLeft,
    double? pace,
    DateTime? date,
  ) {
    if (kmLeft != null && kmLeft <= 0) {
      return '${PersianFormat.km(-kmLeft)} از موعد گذشته';
    }
    if (date != null && MaintenancePlanner.daysBetween(now, date) <= 0) {
      return 'تاریخش گذشته؛ حتی اگر کم رفته‌ای، وقت سرویس است.';
    }
    final used = odometerKm - lead.periodStartKm;
    final base =
        '${PersianFormat.number(used < 0 ? 0 : used)} از '
        '${PersianFormat.km(lead.periodKm!)} این دوره طی شده';
    if (kmLeft != null && pace != null && pace > 0) {
      return '$base · حدود ${PersianFormat.roughDuration((kmLeft / pace).round())} دیگر';
    }
    return base;
  }
}

class _LaterRow extends StatelessWidget {
  const _LaterRow({required this.due, required this.name, required this.onTap});

  final MaintenanceDue due;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = switch (due.status) {
      DueStatus.overdue => BrandColors.danger,
      DueStatus.dueSoon => BrandColors.amberText,
      DueStatus.ok => BrandColors.ink,
    };
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  targetText(due, short: true),
                  textAlign: TextAlign.end,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Insurance or inspection running out soon, or already expired.
class _DocumentAlert extends StatelessWidget {
  const _DocumentAlert({required this.status, required this.onRenewed});

  final DocumentStatus status;
  final VoidCallback onRenewed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final expired = status.expired;
    final foreground = expired ? BrandColors.danger : BrandColors.amberText;
    final title = expired
        ? '${status.document.nameFa} تمام شده'
        : status.daysLeft == 0
        ? '${status.document.nameFa} امروز تمام می‌شود'
        : '${status.document.nameFa} ${PersianFormat.daysFromNow(status.daysLeft)} تمام می‌شود';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: expired ? const Color(0xFFFDECEA) : BrandColors.amberBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(documentIcon(status.document), color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                Text(
                  'اعتبار تا ${PersianFormat.date(status.expiry)}',
                  style: text.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRenewed, child: const Text('تمدید کردم')),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.status,
    required this.onTap,
  });

  final VehicleDocument document;
  final DocumentStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return ListTile(
      onTap: onTap,
      leading: Icon(documentIcon(document), color: BrandColors.violet),
      title: Text(document.nameFa),
      subtitle: Text(
        status == null
            ? 'تاریخ پایانش را ثبت کن تا یادت بیندازیم'
            : status.expired
            ? 'تمام شده · ${PersianFormat.date(status.expiry)}'
            : 'تا ${PersianFormat.date(status.expiry)} · '
                  '${PersianFormat.roughDuration(status.daysLeft)} مانده',
      ),
      trailing: Icon(
        status == null ? Icons.add : Icons.edit_outlined,
        color: BrandColors.violet,
      ),
    );
  }
}
