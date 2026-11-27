import '../../catalog/domain/catalog.dart';
import 'vehicle.dart';

/// Ordered by how much it needs the user's attention.
enum DueStatus {
  overdue,
  dueSoon,

  /// Never logged, and the time since the car was added does not yet prove
  /// it is due. The app asks the user when it was last done.
  unknown,
  ok,
}

/// One upcoming maintenance task for a vehicle, with how close it is.
class MaintenanceDue {
  const MaintenanceDue({
    required this.item,
    required this.intervalKm,
    required this.intervalMonths,
    required this.lastDoneKm,
    required this.lastDoneDate,
    required this.hasServiceRecord,
    required this.dueKm,
    required this.dueDate,
    required this.remainingKm,
    required this.remainingDays,
    required this.status,
    required this.urgency,
  });

  final MaintenanceItem item;
  final int? intervalKm;
  final int? intervalMonths;
  final int lastDoneKm;
  final DateTime lastDoneDate;

  /// False when the countdown starts from when the car was added, because
  /// the user has not logged this item yet.
  final bool hasServiceRecord;
  final int? dueKm;
  final DateTime? dueDate;
  final int? remainingKm;
  final int? remainingDays;
  final DueStatus status;

  /// Share of the interval already used, by whichever limit is closer
  /// (1.0 = due now). Used for sorting.
  final double urgency;
}

/// Turns a vehicle, the catalog and the service history into a sorted list
/// of what is due. Pure and deterministic: [now] is passed in.
class MaintenancePlanner {
  const MaintenancePlanner({
    this.dueSoonKm = 1000,
    this.dueSoonShare = 0.1,
    this.dueSoonDays = 14,
  });

  /// An item is "due soon" within this many km, or within [dueSoonShare] of
  /// its interval if that is larger.
  final int dueSoonKm;
  final double dueSoonShare;
  final int dueSoonDays;

  static const engineOilPartId = 'engine_oil';

  /// Odometer estimate: last confirmed reading plus average daily driving
  /// since then. Never goes below the last reading.
  static int estimateOdometer(Vehicle vehicle, DateTime now) {
    final days = now.difference(vehicle.lastReading.date).inDays;
    if (days <= 0) return vehicle.lastReading.km;
    return vehicle.lastReading.km + days * vehicle.averageDailyKm;
  }

  /// The interval that applies to this vehicle, or null if the item has
  /// none (inspect-only items such as a timing chain).
  static ({int? km, int? months})? effectiveInterval(
    MaintenanceItem item,
    Vehicle vehicle,
  ) {
    // Non-synthetic oil degrades faster, so the oil change follows the
    // severe interval even on an otherwise normal schedule.
    final severe =
        vehicle.usesSevereSchedule ||
        (item.partId == engineOilPartId &&
            vehicle.oilType != OilType.fullSynthetic);
    final primary = severe ? item.severe : item.normal;
    final fallback = severe ? item.normal : item.severe;
    var km = primary?.km ?? fallback?.km;
    final months = primary?.months ?? fallback?.months;
    if (km == null && months == null) return null;

    final oilCap = vehicle.oilType.maxKm;
    if (item.partId == engineOilPartId && oilCap != null) {
      km = km == null ? oilCap : (km < oilCap ? km : oilCap);
    }
    return (km: km, months: months);
  }

  List<MaintenanceDue> plan({
    required Vehicle vehicle,
    required VehicleGroup group,
    required List<ServiceRecord> records,
    required DateTime now,
  }) {
    final currentKm = estimateOdometer(vehicle, now);
    final latestByPart = <String, ServiceRecord>{};
    for (final record in records) {
      if (record.vehicleId != vehicle.id) continue;
      final existing = latestByPart[record.partId];
      if (existing == null || record.km > existing.km) {
        latestByPart[record.partId] = record;
      }
    }

    final dues = <MaintenanceDue>[];
    for (final item in group.items) {
      final interval = effectiveInterval(item, vehicle);
      if (interval == null) continue;

      final last = latestByPart[item.partId];
      final lastKm = last?.km ?? vehicle.trackingStart.km;
      final lastDate = last?.date ?? vehicle.trackingStart.date;

      final dueKm = interval.km == null ? null : lastKm + interval.km!;
      final dueDate = interval.months == null
          ? null
          : _addMonths(lastDate, interval.months!);
      final remainingKm = dueKm == null ? null : dueKm - currentKm;
      final remainingDays = dueDate == null ? null : _daysBetween(now, dueDate);

      final kmShare = interval.km == null
          ? 0.0
          : (currentKm - lastKm) / interval.km!;
      final dayShare = interval.months == null
          ? 0.0
          : _daysBetween(lastDate, now) /
                _daysBetween(lastDate, dueDate!).clamp(1, 1 << 30);
      final urgency = kmShare > dayShare ? kmShare : dayShare;

      dues.add(
        MaintenanceDue(
          item: item,
          intervalKm: interval.km,
          intervalMonths: interval.months,
          lastDoneKm: lastKm,
          lastDoneDate: lastDate,
          hasServiceRecord: last != null,
          dueKm: dueKm,
          dueDate: dueDate,
          remainingKm: remainingKm,
          remainingDays: remainingDays,
          status: _statusFor(
            hasRecord: last != null,
            intervalKm: interval.km,
            remainingKm: remainingKm,
            remainingDays: remainingDays,
          ),
          urgency: urgency,
        ),
      );
    }

    dues.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      return byStatus != 0 ? byStatus : b.urgency.compareTo(a.urgency);
    });
    return dues;
  }

  /// Without a record, counting from the day the car was added only proves
  /// something when it is already due; otherwise the honest answer is
  /// "unknown" rather than a reassuring "ok".
  DueStatus _statusFor({
    required bool hasRecord,
    required int? intervalKm,
    required int? remainingKm,
    required int? remainingDays,
  }) {
    final status = _status(intervalKm, remainingKm, remainingDays);
    if (!hasRecord && status == DueStatus.ok) return DueStatus.unknown;
    return status;
  }

  DueStatus _status(int? intervalKm, int? remainingKm, int? remainingDays) {
    if ((remainingKm != null && remainingKm <= 0) ||
        (remainingDays != null && remainingDays <= 0)) {
      return DueStatus.overdue;
    }
    final kmWindow = intervalKm == null
        ? dueSoonKm
        : (intervalKm * dueSoonShare).round().clamp(dueSoonKm, 1 << 30);
    if ((remainingKm != null && remainingKm <= kmWindow) ||
        (remainingDays != null && remainingDays <= dueSoonDays)) {
      return DueStatus.dueSoon;
    }
    return DueStatus.ok;
  }

  static int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// Calendar month arithmetic that clamps the day (31 Jan + 1 month =
  /// 28/29 Feb), so intervals never skip a month.
  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final year = date.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }
}
