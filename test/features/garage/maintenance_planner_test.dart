import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/features/catalog/domain/catalog.dart';
import 'package:karyad/features/garage/domain/maintenance_planner.dart';
import 'package:karyad/features/garage/domain/vehicle.dart';

const _oil = MaintenanceItem(
  partId: 'engine_oil',
  action: MaintenanceAction.replace,
  confidence: Confidence.official,
  normal: ServiceInterval(km: 10000, months: 12),
  severe: ServiceInterval(km: 5000, months: 6),
);

const _air = MaintenanceItem(
  partId: 'air_filter',
  action: MaintenanceAction.replace,
  confidence: Confidence.official,
  normal: ServiceInterval(km: 10000),
);

const _belt = MaintenanceItem(
  partId: 'timing_belt',
  action: MaintenanceAction.replace,
  confidence: Confidence.official,
  normal: ServiceInterval(km: 80000, months: 36),
  severe: ServiceInterval(km: 40000),
);

const _brakeFluid = MaintenanceItem(
  partId: 'brake_fluid',
  action: MaintenanceAction.replace,
  confidence: Confidence.official,
  normal: ServiceInterval(months: 24),
);

const _chain = MaintenanceItem(
  partId: 'timing_chain',
  action: MaintenanceAction.inspect,
  confidence: Confidence.official,
);

const _manualBox = MaintenanceItem(
  partId: 'manual_gearbox_oil',
  action: MaintenanceAction.replace,
  confidence: Confidence.official,
  normal: ServiceInterval(km: 60000),
);

const _autoBox = MaintenanceItem(
  partId: 'automatic_gearbox_oil',
  action: MaintenanceAction.replace,
  confidence: Confidence.official,
  normal: ServiceInterval(km: 40000),
);

const _boxGroup = VehicleGroup(
  id: 'g',
  makerId: 'ikco',
  models: [VehicleModel(id: 'car', nameFa: 'خودرو', groupId: 'g')],
  confidence: Confidence.official,
  sourceFa: 'test',
  items: [_oil, _manualBox, _autoBox],
);

const _group = VehicleGroup(
  id: 'g',
  makerId: 'ikco',
  models: [VehicleModel(id: 'car', nameFa: 'خودرو', groupId: 'g')],
  confidence: Confidence.official,
  sourceFa: 'test',
  items: [_oil, _air, _belt, _brakeFluid, _chain],
);

final _added = DateTime(2026, 1, 1);

Vehicle _car({
  int km = 62000,
  VehicleUsage usage = VehicleUsage.personal,
  OilType oil = OilType.fullSynthetic,
  Transmission transmission = Transmission.manual,
  int? oilIntervalKm,
  List<OdometerReading>? readings,
}) => Vehicle(
  id: 'v1',
  modelId: 'car',
  usage: usage,
  oilType: oil,
  transmission: transmission,
  oilIntervalKm: oilIntervalKm,
  readings: readings ?? [OdometerReading(km: km, date: _added)],
);

ServiceRecord _done(String part, int km, DateTime date) => ServiceRecord(
  id: '$part-$km',
  vehicleId: 'v1',
  partId: part,
  km: km,
  date: date,
);

MaintenanceDue _due(MaintenancePlan plan, String part) =>
    plan.all.firstWhere((d) => d.partId == part);

void main() {
  const planner = MaintenancePlanner();

  group('absolute targets without history', () {
    test('km items follow the factory schedule to the next milestone', () {
      final plan = planner.plan(
        vehicle: _car(km: 62000),
        group: _group,
        records: const [],
        now: _added,
      );
      expect(_due(plan, 'timing_belt').dueKm, 80000);
      expect(_due(plan, 'timing_belt').basis, DueBasis.factorySchedule);
      expect(_due(plan, 'air_filter').dueKm, 70000);
      expect(_due(plan, 'engine_oil').dueKm, 70000);
    });

    test('a car exactly on a milestone gets the next one', () {
      final plan = planner.plan(
        vehicle: _car(km: 80000),
        group: _group,
        records: const [],
        now: _added,
      );
      expect(_due(plan, 'timing_belt').dueKm, 160000);
    });

    test('time limits count from the day the car was added', () {
      final plan = planner.plan(
        vehicle: _car(),
        group: _group,
        records: const [],
        now: _added,
      );
      expect(_due(plan, 'brake_fluid').dueDate, DateTime(2028, 1, 1));
      expect(_due(plan, 'brake_fluid').dueKm, isNull);
    });

    test('inspect-only items without an interval are left out', () {
      final plan = planner.plan(
        vehicle: _car(),
        group: _group,
        records: const [],
        now: _added,
      );
      expect(plan.all.map((d) => d.partId), isNot(contains('timing_chain')));
    });
  });

  group('with history', () {
    test('due km is last done km plus the interval', () {
      final plan = planner.plan(
        vehicle: _car(km: 64000),
        group: _group,
        records: [_done('engine_oil', 62000, DateTime(2026, 2, 1))],
        now: DateTime(2026, 2, 10),
      );
      final oil = _due(plan, 'engine_oil');
      expect(oil.basis, DueBasis.record);
      expect(oil.dueKm, 72000);
      expect(oil.dueDate, DateTime(2027, 2, 1));
      expect(oil.kmProgress(64000), closeTo(0.2, 1e-9));
    });

    test('uses the record with the highest km', () {
      final plan = planner.plan(
        vehicle: _car(km: 64000),
        group: _group,
        records: [
          _done('engine_oil', 52000, DateTime(2025, 6, 1)),
          _done('engine_oil', 62000, DateTime(2026, 2, 1)),
        ],
        now: DateTime(2026, 2, 10),
      );
      expect(_due(plan, 'engine_oil').dueKm, 72000);
    });
  });

  group('schedules', () {
    test('work use takes severe intervals, falling back to normal months', () {
      final v = _car(usage: VehicleUsage.work);
      final belt = MaintenancePlanner.effectiveInterval(_belt, v)!;
      expect(belt.km, 40000);
      expect(belt.months, 36);
      expect(MaintenancePlanner.effectiveInterval(_oil, v)!.km, 5000);
    });

    test('non-synthetic oil shortens only the oil change, with a cap', () {
      final v = _car(oil: OilType.semiSynthetic);
      expect(MaintenancePlanner.effectiveInterval(_oil, v)!.km, 5000);
      expect(MaintenancePlanner.effectiveInterval(_belt, v)!.km, 80000);
    });
  });

  group('status', () {
    test('overdue when the odometer passed the target', () {
      final plan = planner.plan(
        vehicle: _car(km: 73000),
        group: _group,
        records: [_done('engine_oil', 62000, DateTime(2026, 1, 1))],
        now: DateTime(2026, 2, 1),
      );
      expect(_due(plan, 'engine_oil').status, DueStatus.overdue);
    });

    test('overdue when the date passed even with few km', () {
      final plan = planner.plan(
        vehicle: _car(km: 62500),
        group: _group,
        records: [_done('engine_oil', 62000, DateTime(2026, 1, 1))],
        now: DateTime(2027, 1, 2),
      );
      expect(_due(plan, 'engine_oil').status, DueStatus.overdue);
    });

    test('due soon within 1,000 km', () {
      final plan = planner.plan(
        vehicle: _car(km: 71200),
        group: _group,
        records: [_done('engine_oil', 62000, DateTime(2026, 1, 1))],
        now: DateTime(2026, 2, 1),
      );
      expect(_due(plan, 'engine_oil').status, DueStatus.dueSoon);
    });
  });

  group('service visit', () {
    test('groups items due close together into the next visit', () {
      final plan = planner.plan(
        vehicle: _car(km: 62000),
        group: _group,
        records: const [],
        now: _added,
      );
      final visit = plan.nextVisit!;
      expect(
        visit.items.map((d) => d.partId),
        containsAll(['engine_oil', 'air_filter']),
      );
      expect(visit.dueKm, 70000);
      expect(plan.later.map((d) => d.partId), contains('timing_belt'));
    });

    test('a recorded target sets the visit, not a nearby estimate', () {
      // Sticker says oil at 72,000; the air filter has no history, so its
      // factory milestone of 70,000 is only an estimate and joins the visit.
      final plan = planner.plan(
        vehicle: _car(km: 62400),
        group: _group,
        records: [_done('engine_oil', 62000, _added)],
        now: _added,
      );
      final visit = plan.nextVisit!;
      expect(
        visit.items.map((d) => d.partId),
        containsAll(['engine_oil', 'air_filter']),
      );
      expect(visit.dueKm, 72000);
    });

    test('the most urgent item leads the visit', () {
      final plan = planner.plan(
        vehicle: _car(km: 73000),
        group: _group,
        records: [
          _done('engine_oil', 62000, DateTime(2026, 1, 1)),
          _done('air_filter', 70000, DateTime(2026, 1, 1)),
        ],
        now: DateTime(2026, 2, 1),
      );
      expect(plan.nextVisit!.items.first.partId, 'engine_oil');
      expect(plan.nextVisit!.status, DueStatus.overdue);
    });
  });

  group('learned pace', () {
    test('comes from the user\'s own readings, not a guess', () {
      expect(_car().learnedDailyKm, isNull);
      final v = _car(
        readings: [
          OdometerReading(km: 60000, date: DateTime(2026, 1, 1)),
          OdometerReading(km: 60600, date: DateTime(2026, 1, 21)),
        ],
      );
      expect(v.learnedDailyKm, 30);
    });
  });

  group('audit fixes', () {
    test('only the gearbox oil of the car\'s gearbox applies', () {
      List<String> parts(Transmission t) => planner
          .plan(
            vehicle: _car(transmission: t),
            group: _boxGroup,
            records: const [],
            now: _added,
          )
          .all
          .map((d) => d.partId)
          .toList();
      expect(parts(Transmission.manual), contains('manual_gearbox_oil'));
      expect(parts(Transmission.manual), isNot(contains('automatic_gearbox_oil')));
      expect(parts(Transmission.automatic), contains('automatic_gearbox_oil'));
      expect(parts(Transmission.automatic), isNot(contains('manual_gearbox_oil')));
    });

    test('a sticker target stays put when interval settings change', () {
      final sticker = ServiceRecord(
        id: 's',
        vehicleId: 'v1',
        partId: 'engine_oil',
        km: 62000,
        date: _added,
        estimated: true,
        nextDueKm: 72000,
      );
      for (final car in [
        _car(km: 62400),
        _car(km: 62400, oil: OilType.mineral),
        _car(km: 62400, oilIntervalKm: 6000),
      ]) {
        final plan = planner.plan(
          vehicle: car,
          group: _group,
          records: [sticker],
          now: _added,
        );
        expect(_due(plan, 'engine_oil').dueKm, 72000);
      }
    });

    test('the visit lead is the item that sets its target', () {
      final plan = planner.plan(
        vehicle: _car(km: 62400),
        group: _group,
        records: [_done('engine_oil', 62000, _added)],
        now: _added,
      );
      final visit = plan.nextVisit!;
      expect(visit.lead.partId, 'engine_oil');
      expect(visit.items.first.partId, 'engine_oil');
      expect(visit.lead.kmProgress(63000), closeTo(0.1, 1e-9));
    });

    test('an overdue estimate is not hidden behind a later recorded target',
        () {
      // The belt has no history: 36 months from the day the car was added,
      // so it is overdue by date. The air filter, logged at 71,000, is due
      // at 81,000 and joins the same visit. The visit must still say 80,000.
      final now = DateTime(2029, 1, 5);
      final plan = planner.plan(
        vehicle: _car(
          readings: [
            OdometerReading(km: 78500, date: _added),
            OdometerReading(km: 79000, date: now),
          ],
        ),
        group: _group,
        records: [_done('air_filter', 71000, DateTime(2028, 6, 1))],
        now: now,
      );
      final visit = plan.nextVisit!;
      expect(
        visit.items.map((d) => d.partId),
        containsAll(['timing_belt', 'air_filter']),
      );
      expect(visit.status, DueStatus.overdue);
      expect(visit.lead.status, DueStatus.overdue);
      expect(visit.dueKm, 80000);
    });
  });
}
