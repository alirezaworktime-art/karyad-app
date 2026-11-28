import '../../../core/format/persian_format.dart';
import '../../garage/application/garage_controller.dart';
import '../../garage/domain/vehicle.dart';

/// One notification to show at [when].
class ScheduledReminder {
  const ScheduledReminder({
    required this.key,
    required this.when,
    required this.title,
    required this.body,
  });

  /// Stable name, for tests and de-duplication (e.g. `car-1:service:-7`).
  final String key;
  final DateTime when;
  final String title;
  final String body;

  @override
  String toString() => '$key @ $when';
}

/// Turns the garage into the notifications to schedule on the phone.
///
/// Phones can only wake us at a time, not at a km, so:
/// * date limits (service due dates, document expiries) are reminded a week
///   before and on the day — documents a month before as well;
/// * km limits depend on the odometer, so we ask for a fresh reading when
///   the last one gets old; the in-app plan does the rest.
class ReminderPlanner {
  const ReminderPlanner({this.hour = 10, this.readingHour = 19, this.max = 48});

  /// Local hour for date reminders, and for odometer prompts (evening, when
  /// people are back home with the car).
  final int hour;
  final int readingHour;

  /// Android limits pending alarms per app; stay well under it.
  final int max;

  List<ScheduledReminder> plan(GarageController garage) {
    final now = garage.now;
    final reminders = <ScheduledReminder>[];

    for (final vehicle in garage.vehicles) {
      final name = garage.displayName(vehicle);

      final visit = garage.planFor(vehicle)?.nextVisit;
      final dueDate = visit?.dueDate;
      if (visit != null && dueDate != null) {
        final when = PersianFormat.date(dueDate);
        for (final daysBefore in const [7, 0]) {
          reminders.add(
            ScheduledReminder(
              key: '${vehicle.id}:service:$daysBefore',
              when: _at(dueDate, -daysBefore, hour),
              title: daysBefore == 0
                  ? '$name امروز سرویس داره'
                  : 'یه هفته تا سرویس $name مونده',
              body:
                  'تا $when باید سرویس بشه، هر کدوم از کیلومتر یا تاریخ '
                  'زودتر برسه. تو کاریاد ببین چی‌ها رو باید عوض کنی.',
            ),
          );
        }
      }

      for (final document in VehicleDocument.values) {
        final expiry = vehicle.documentExpiry[document];
        if (expiry == null) continue;
        final date = PersianFormat.date(expiry);
        for (final daysBefore in const [30, 7, 0]) {
          reminders.add(
            ScheduledReminder(
              key: '${vehicle.id}:${document.name}:$daysBefore',
              when: _at(expiry, -daysBefore, hour),
              title: daysBefore == 0
                  ? '${document.nameFa} $name امروز تموم می‌شه'
                  : '${document.nameFa} $name '
                        '${PersianFormat.daysFromNow(daysBefore)} تموم می‌شه',
              body:
                  'اعتبارش تا $date هست. تمدیدش کردی؟ '
                  'تو کاریاد تاریخ جدید رو بزن.',
            ),
          );
        }
      }

      final staleAfter = vehicle.usage == VehicleUsage.work ? 7 : 14;
      var prompt = _at(vehicle.lastReading.date, staleAfter, readingHour);
      if (!prompt.isAfter(now)) prompt = _at(now, 1, readingHour);
      reminders.add(
        ScheduledReminder(
          key: '${vehicle.id}:reading',
          when: prompt,
          title: 'کیلومترشمار $name چند شده؟',
          body: 'یه عدد بزن که بدونیم سرویس بعدی کِی می‌رسه.',
        ),
      );
    }

    final upcoming = [
      for (final r in reminders)
        if (r.when.isAfter(now)) r,
    ]..sort((a, b) => a.when.compareTo(b.when));
    return upcoming.take(max).toList();
  }

  static DateTime _at(DateTime day, int addDays, int hour) {
    final date = DateTime(day.year, day.month, day.day + addDays);
    return DateTime(date.year, date.month, date.day, hour);
  }
}

/// How the planned reminders reach the phone.
abstract interface class ReminderScheduler {
  /// Replaces every scheduled reminder with [reminders].
  Future<void> replaceAll(List<ScheduledReminder> reminders);
}

/// For platforms that can't schedule notifications (browsers).
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {}
}

/// Keeps the phone's notifications in step with the garage: every change
/// (a reading, a service, a new date) reschedules them.
class ReminderSync {
  ReminderSync({
    required this.garage,
    required this.scheduler,
    this.planner = const ReminderPlanner(),
  });

  final GarageController garage;
  final ReminderScheduler scheduler;
  final ReminderPlanner planner;

  Future<void>? _running;
  bool _again = false;

  void start() {
    garage.addListener(_sync);
    _sync();
  }

  void dispose() => garage.removeListener(_sync);

  /// Runs one sync at a time; changes during a run trigger one more.
  void _sync() {
    if (!garage.isLoaded) return;
    if (_running != null) {
      _again = true;
      return;
    }
    _running = _run();
  }

  Future<void> _run() async {
    do {
      _again = false;
      final reminders = garage.remindersEnabled
          ? planner.plan(garage)
          : const <ScheduledReminder>[];
      try {
        await scheduler.replaceAll(reminders);
      } on Object {
        // Notifications are a convenience; the app works without them.
      }
    } while (_again);
    _running = null;
  }

  /// Completes when the current sync (if any) is done. For tests.
  Future<void> settled() async {
    while (_running != null) {
      await _running;
    }
  }
}
