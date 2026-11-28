import '../../catalog/domain/catalog.dart';
import 'vehicle.dart';

/// Ordered by how much it needs the user's attention.
enum DueStatus { overdue, dueSoon, ok }

/// Where the countdown for an item starts.
enum DueBasis {
  /// The user logged this item (or gave the oil sticker).
  record,

  /// Nothing logged: km follow the factory schedule from 0 (for an
  /// 80,000 km belt on a 62,000 km car, the next one is at 80,000), and
  /// time counts from the day the car was added.
  factorySchedule,
}

/// One maintenance item and when it is next due, as absolute values the
/// user can compare with the dashboard and the calendar.
class MaintenanceDue {
  const MaintenanceDue({
    required this.item,
    required this.basis,
    required this.intervalKm,
    required this.intervalMonths,
    required this.periodStartKm,
    required this.dueKm,
    required this.dueDate,
    required this.status,
  });

  final MaintenanceItem item;
  final DueBasis basis;
  final int? intervalKm;
  final int? intervalMonths;

  /// Odometer at the start of the current period (last done, or the last
  /// factory milestone). Used for the progress bar.
  final int periodStartKm;

  /// Due at this odometer value…
  final int? dueKm;

  /// …or on this date, whichever comes first.
  final DateTime? dueDate;
  final DueStatus status;

  String get partId => item.partId;

  /// Share of the km period used at [odometerKm], 0..1.
  double kmProgress(int odometerKm) {
    final span = periodKm;
    if (span == null || span <= 0) return 0;
    return ((odometerKm - periodStartKm) / span).clamp(0.0, 1.0);
  }

  /// Length of the current km period: from its start to the target.
  int? get periodKm => dueKm == null ? null : dueKm! - periodStartKm;
}

/// Items that are done together at one workshop visit.
class ServiceVisit {
  const ServiceVisit({
    required this.items,
    required this.lead,
    required this.dueKm,
    this.dueDate,
  });

  /// Everything to do at this visit; [lead] comes first.
  final List<MaintenanceDue> items;

  /// The item that sets the visit's target, for its progress bar.
  final MaintenanceDue lead;

  /// The earliest km target among the items, preferring items whose last
  /// service is on record over factory-schedule estimates.
  final int? dueKm;

  /// The earliest date among the same items, if any has one.
  final DateTime? dueDate;

  DueStatus get status =>
      items.map((d) => d.status).reduce((a, b) => a.index <= b.index ? a : b);
}

class MaintenancePlan {
  const MaintenancePlan({
    required this.odometerKm,
    required this.nextVisit,
    required this.later,
  });

  /// The last odometer value the user entered. Never an estimate.
  final int odometerKm;

  /// What to do at the next workshop visit; null if nothing is scheduled.
  final ServiceVisit? nextVisit;

  /// Everything else, soonest first.
  final List<MaintenanceDue> later;

  List<MaintenanceDue> get all => [...?nextVisit?.items, ...later];
}

/// Turns a vehicle, the catalog and the service history into absolute
/// due km and dates. Pure and deterministic: [now] is passed in.
class MaintenancePlanner {
  const MaintenancePlanner({
    this.dueSoonKm = 1000,
    this.dueSoonDays = 30,
    this.visitWindowKm = 2000,
    this.visitWindowDays = 45,
  });

  /// "Due soon" within this many km of the target, or this many days.
  final int dueSoonKm;
  final int dueSoonDays;

  /// Items due within this distance or time of the first one join it in
  /// the same visit, as a mechanic would do them together.
  final int visitWindowKm;
  final int visitWindowDays;

  static const engineOilPartId = 'engine_oil';

  /// The interval that applies to this vehicle, or null for inspect-only
  /// items with no interval (such as a timing chain).
  static ({int? km, int? months})? effectiveInterval(
    MaintenanceItem item,
    Vehicle vehicle,
  ) {
    final isOil = item.partId == engineOilPartId;
    // Non-synthetic oil degrades faster, so the oil change follows the
    // severe interval even on an otherwise normal schedule.
    final severe =
        vehicle.usesSevereSchedule ||
        (isOil && vehicle.oilType != OilType.fullSynthetic);
    final primary = severe ? item.severe : item.normal;
    final fallback = severe ? item.normal : item.severe;
    var km = primary?.km ?? fallback?.km;
    final months = primary?.months ?? fallback?.months;
    if (km == null && months == null) return null;

    // An interval the user set (from their mechanic or the oil can) wins
    // over both the factory figure and the oil-type cap.
    final custom = vehicle.oilIntervalKm;
    if (isOil && custom != null) return (km: custom, months: months);

    final oilCap = vehicle.oilType.maxKm;
    if (isOil && oilCap != null) {
      km = km == null ? oilCap : (km < oilCap ? km : oilCap);
    }
    return (km: km, months: months);
  }

  MaintenancePlan plan({
    required Vehicle vehicle,
    required VehicleGroup group,
    required List<ServiceRecord> records,
    required DateTime now,
  }) {
    final odometer = vehicle.lastReading.km;
    final latestByPart = <String, ServiceRecord>{};
    for (final record in records) {
      if (record.vehicleId != vehicle.id) continue;
      final existing = latestByPart[record.partId];
      if (existing == null ||
          record.km > existing.km ||
          (record.km == existing.km && record.date.isAfter(existing.date))) {
        latestByPart[record.partId] = record;
      }
    }

    final dues = <MaintenanceDue>[];
    for (final item in group.items) {
      final gearbox = Transmission.ofPart(item.partId);
      if (gearbox != null && gearbox != vehicle.transmission) continue;
      final interval = effectiveInterval(item, vehicle);
      if (interval == null) continue;
      final last = latestByPart[item.partId];

      final int periodStartKm;
      final int? dueKm;
      if (interval.km == null) {
        periodStartKm = last?.km ?? odometer;
        dueKm = null;
      } else if (last != null) {
        periodStartKm = last.km;
        // A sticker number is the target as the mechanic gave it.
        dueKm = last.nextDueKm ?? last.km + interval.km!;
      } else {
        // Next factory milestone strictly above the odometer.
        final step = interval.km!;
        periodStartKm = (odometer ~/ step) * step;
        dueKm = periodStartKm + step;
      }

      final start = last?.date ?? vehicle.firstReading.date;
      final dueDate = interval.months == null
          ? null
          : addMonths(start, interval.months!);

      dues.add(
        MaintenanceDue(
          item: item,
          basis: last == null ? DueBasis.factorySchedule : DueBasis.record,
          intervalKm: interval.km,
          intervalMonths: interval.months,
          periodStartKm: periodStartKm,
          dueKm: dueKm,
          dueDate: dueDate,
          status: _status(odometer, now, dueKm, dueDate),
        ),
      );
    }

    dues.sort((a, b) => _compare(a, b, vehicle, now));
    if (dues.isEmpty) {
      return MaintenancePlan(odometerKm: odometer, nextVisit: null, later: []);
    }

    final first = dues.first;
    final inVisit = <MaintenanceDue>[];
    final later = <MaintenanceDue>[];
    for (final due in dues) {
      if (identical(due, first) || _sameVisit(first, due)) {
        inVisit.add(due);
      } else {
        later.add(due);
      }
    }
    // A target the user gave us (a sticker or a logged service) is a fact;
    // a factory milestone for a part with no history is only an estimate.
    // When a visit has both, the facts set its target, so the app never
    // moves an oil change the sticker put at 72,000 back to 70,000.
    // An overdue estimate is never hidden behind a later fact, though.
    final facts = [
      for (final d in inVisit)
        if (d.basis == DueBasis.record || d.status == DueStatus.overdue) d,
    ];
    final anchors = facts.isEmpty ? inVisit : facts;
    final lead = anchors.first;
    return MaintenancePlan(
      odometerKm: odometer,
      nextVisit: ServiceVisit(
        items: [lead, ...inVisit.where((d) => !identical(d, lead))],
        lead: lead,
        dueKm: _minInt(anchors.map((d) => d.dueKm)),
        dueDate: _minDate(anchors.map((d) => d.dueDate)),
      ),
      later: later,
    );
  }

  bool _sameVisit(MaintenanceDue first, MaintenanceDue other) {
    final firstKm = first.dueKm;
    final otherKm = other.dueKm;
    if (firstKm != null &&
        otherKm != null &&
        (otherKm - firstKm).abs() <= visitWindowKm) {
      return true;
    }
    final firstDate = first.dueDate;
    final otherDate = other.dueDate;
    if (firstKm == null &&
        firstDate != null &&
        otherDate != null &&
        otherDate.difference(firstDate).inDays.abs() <= visitWindowDays) {
      return true;
    }
    return false;
  }

  DueStatus _status(int odometer, DateTime now, int? dueKm, DateTime? due) {
    final kmLeft = dueKm == null ? null : dueKm - odometer;
    final daysLeft = due == null ? null : daysBetween(now, due);
    if ((kmLeft != null && kmLeft <= 0) ||
        (daysLeft != null && daysLeft <= 0)) {
      return DueStatus.overdue;
    }
    if ((kmLeft != null && kmLeft <= dueSoonKm) ||
        (daysLeft != null && daysLeft <= dueSoonDays)) {
      return DueStatus.dueSoon;
    }
    return DueStatus.ok;
  }

  /// Most urgent first: by status, then by how soon the earlier of the two
  /// limits arrives. Km are converted to days with the learned pace when
  /// known, otherwise compared as km.
  int _compare(
    MaintenanceDue a,
    MaintenanceDue b,
    Vehicle vehicle,
    DateTime now,
  ) {
    final byStatus = a.status.index.compareTo(b.status.index);
    if (byStatus != 0) return byStatus;
    return _urgencyDays(
      a,
      vehicle,
      now,
    ).compareTo(_urgencyDays(b, vehicle, now));
  }

  double _urgencyDays(MaintenanceDue d, Vehicle vehicle, DateTime now) {
    final pace = vehicle.learnedDailyKm ?? 40;
    final kmDays = d.dueKm == null
        ? double.infinity
        : (d.dueKm! - vehicle.lastReading.km) / pace;
    final dateDays = d.dueDate == null
        ? double.infinity
        : daysBetween(now, d.dueDate!).toDouble();
    return kmDays < dateDays ? kmDays : dateDays;
  }

  static int? _minInt(Iterable<int?> values) {
    int? min;
    for (final v in values) {
      if (v != null && (min == null || v < min)) min = v;
    }
    return min;
  }

  static DateTime? _minDate(Iterable<DateTime?> values) {
    DateTime? min;
    for (final v in values) {
      if (v != null && (min == null || v.isBefore(min))) min = v;
    }
    return min;
  }

  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// Calendar month arithmetic that clamps the day (31 Jan + 1 month =
  /// 28/29 Feb), so intervals never skip a month.
  static DateTime addMonths(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final year = date.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }
}
