import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format/persian_format.dart';
import '../../../core/ui/responsive_body.dart';
import '../application/garage_controller.dart';

/// Every logged visit, newest first, with costs.
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key, required this.controller});

  final GarageController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final vehicle = controller.primaryVehicle;
        if (vehicle == null) return const SizedBox.shrink();
        final visits = controller.visitsFor(vehicle.id);
        final total = visits
            .map((v) => v.costRial ?? 0)
            .fold<int>(0, (a, b) => a + b);

        return ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                'سوابق سرویس',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'هر سرویسی که ثبت کنی اینجا می‌ماند؛ موقع فروش ماشین به خریدار نشانش بده.',
                style: text.bodyMedium?.copyWith(color: BrandColors.muted),
              ),
              const SizedBox(height: 16),
              if (visits.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.history,
                          size: 40,
                          color: BrandColors.violet,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'هنوز سرویسی ثبت نشده',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'بعد از هر تعویض روغن یا تعمیر، در صفحه‌ی خانه «سرویس را انجام دادم» را بزن.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: BrandColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final visit in visits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        14,
                        4,
                        14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        PersianFormat.date(visit.date),
                                        style: text.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      PersianFormat.km(visit.km),
                                      style: text.bodyMedium?.copyWith(
                                        color: BrandColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  visit.partIds
                                      .map(
                                        (id) =>
                                            controller.catalog
                                                .part(id)
                                                ?.nameFa ??
                                            id,
                                      )
                                      .join(' · '),
                                  style: text.bodyMedium,
                                ),
                                if (visit.costRial != null)
                                  Text(
                                    '${PersianFormat.number(visit.costRial! ~/ 10)} تومان',
                                    style: text.bodySmall?.copyWith(
                                      color: BrandColors.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: BrandColors.muted,
                            ),
                            onPressed: () =>
                                _confirmDelete(context, () {
                                  controller.deleteVisit(visit.id);
                                }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: BrandColors.violetLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'جمع هزینه‌ها',
                          style: text.bodyMedium?.copyWith(
                            color: BrandColors.violetDark,
                          ),
                        ),
                      ),
                      Text(
                        '${PersianFormat.number(total ~/ 10)} تومان',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BrandColors.violetDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    VoidCallback onConfirm,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('این سرویس حذف شود؟'),
        content: const Text('یادآورها دوباره بدون این سرویس حساب می‌شوند.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('نه'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok ?? false) onConfirm();
  }
}
