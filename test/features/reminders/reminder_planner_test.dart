import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/features/garage/application/garage_controller.dart';
import 'package:karyad/features/garage/data/garage_repository.dart';
import 'package:karyad/features/garage/domain/vehicle.dart';
import 'package:karyad/features/reminders/application/reminder_planner.dart';

import '../../helpers/catalog_fixture.dart';

class _RecordingScheduler implements ReminderScheduler {
  final calls = <List<ScheduledReminder>>[];

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async =>
      calls.add(reminders);
}

void main() {
  late DateTime now;
  late GarageController garage;
  const planner = ReminderPlanner();

  setUp(() async {
    now = DateTime(2026, 11, 27, 12);
    garage = GarageController(
      repository: InMemoryGarageRepository(),
      catalog: loadCatalog(),
      clock: () => now,
    );
    await garage.load();
  });

  List<String> keys() => planner.plan(garage).map((r) => r.key).toList();

  test('no cars, no reminders', () {
    expect(planner.plan(garage), isEmpty);
  });

  test(
    'a service date gives a week-before and an on-the-day reminder',
    () async {
      final car = await garage.addVehicle(
        modelId: 'quick',
        usage: VehicleUsage.personal,
        currentKm: 30000,
      );
      final reminders = planner.plan(garage);
      final service = reminders
          .where((r) => r.key.contains(':service:'))
          .toList();
      expect(service.map((r) => r.key), [
        '${car.id}:service:7',
        '${car.id}:service:0',
      ]);
      final due = garage.planFor(garage.activeVehicle!)!.nextVisit!.dueDate!;
      expect(service.last.when, DateTime(due.year, due.month, due.day, 10));
      expect(
        service.first.when,
        DateTime(due.year, due.month, due.day - 7, 10),
      );
      expect(service.last.title, contains('کوییک'));
    },
  );

  test('documents remind a month, a week and the day before', () async {
    final car = await garage.addVehicle(
      modelId: 'quick',
      usage: VehicleUsage.personal,
      currentKm: 30000,
    );
    await garage.setDocumentExpiry(
      car.id,
      VehicleDocument.insurance,
      DateTime(2027, 3, 1),
    );
    expect(keys().where((k) => k.contains('insurance')), [
      '${car.id}:insurance:30',
      '${car.id}:insurance:7',
      '${car.id}:insurance:0',
    ]);
  });

  test('reminders in the past are dropped', () async {
    final car = await garage.addVehicle(
      modelId: 'quick',
      usage: VehicleUsage.personal,
      currentKm: 30000,
    );
    // Expires in 10 days: the 30-day reminder is already past.
    await garage.setDocumentExpiry(
      car.id,
      VehicleDocument.inspection,
      DateTime(2026, 12, 7),
    );
    expect(keys().where((k) => k.contains('inspection')), [
      '${car.id}:inspection:7',
      '${car.id}:inspection:0',
    ]);
    expect(planner.plan(garage).every((r) => r.when.isAfter(now)), isTrue);
  });

  test('an odometer prompt comes when the reading gets old', () async {
    final personal = await garage.addVehicle(
      modelId: 'quick',
      usage: VehicleUsage.personal,
      currentKm: 30000,
    );
    final work = await garage.addVehicle(
      modelId: 'dena-plus',
      usage: VehicleUsage.work,
      currentKm: 90000,
    );
    final byKey = {for (final r in planner.plan(garage)) r.key: r.when};
    expect(byKey['${personal.id}:reading'], DateTime(2026, 12, 11, 19));
    expect(byKey['${work.id}:reading'], DateTime(2026, 12, 4, 19));

    // Long stale: prompt tomorrow evening instead of in the past.
    now = DateTime(2027, 2, 1, 12);
    final later = {for (final r in planner.plan(garage)) r.key: r.when};
    expect(later['${personal.id}:reading'], DateTime(2027, 2, 2, 19));
  });

  test('sorted by time and capped', () async {
    for (var i = 0; i < 12; i++) {
      final car = await garage.addVehicle(
        modelId: 'quick',
        usage: VehicleUsage.personal,
        currentKm: 30000 + i,
      );
      for (final d in VehicleDocument.values) {
        await garage.setDocumentExpiry(car.id, d, DateTime(2027, 6, 1 + i));
      }
    }
    final reminders = const ReminderPlanner(max: 20).plan(garage);
    expect(reminders, hasLength(20));
    for (var i = 1; i < reminders.length; i++) {
      expect(reminders[i].when.isBefore(reminders[i - 1].when), isFalse);
    }
  });

  test('sync reschedules on every change and clears when turned off', () async {
    final scheduler = _RecordingScheduler();
    final sync = ReminderSync(garage: garage, scheduler: scheduler)..start();
    await sync.settled();
    expect(scheduler.calls.last, isEmpty);

    await garage.addVehicle(
      modelId: 'quick',
      usage: VehicleUsage.personal,
      currentKm: 30000,
    );
    await sync.settled();
    expect(scheduler.calls.last, isNotEmpty);

    await garage.setRemindersEnabled(false);
    await sync.settled();
    expect(scheduler.calls.last, isEmpty);
    sync.dispose();
  });
}
