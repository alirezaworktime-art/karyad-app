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

const _belt = MaintenanceItem(
  partId: 'timing_belt',
  action: MaintenanceAction.replace,
  confidence: Confidence.official,
  normal: ServiceInterval(km: 60000, months: 72),
  severe: ServiceInterval(km: 40000),
);

const _chain = MaintenanceItem(
  partId: 'timing_chain',
  action: MaintenanceAction.inspect,
  confidence: Confidence.official,
);

const _group = VehicleGroup(
  id: 'test-group',
  makerId: 'saipa',
  models: [VehicleModel(id: 'car', nameFa: 'خودرو', groupId: 'test-group')],
  confidence: Confidence.official,
  sourceFa: 'test',
  items: [_oil, _belt, _chain],
);

final _start = DateTime(2026, 1, 1);

Vehicle _vehicle({
  VehicleUsage usage = VehicleUsage.personal,
  OilType oil = OilType.fullSynthetic,
  int dailyKm = 50,
  int startKm = 20000,
  bool severe = false,
}) => Vehicle(
  id: 'v1',
  modelId: 'car',
  usage: usage,
  oilType: oil,
  averageDailyKm: dailyKm,
  trackingStart: OdometerReading(km: startKm, date: _start),
  lastReading: OdometerReading(km: startKm, date: _start),
  severeConditions: severe,
);

MaintenanceDue _dueFor(List<MaintenanceDue> dues, String partId) =>
    dues.firstWhere((d) => d.item.partId == partId);

void main() {
  const planner = MaintenancePlanner();

  group('estimateOdometer', () {
    test('adds average daily km since the last reading', () {
      final v = _vehicle(dailyKm: 40);
      expect(
        MaintenancePlanner.estimateOdometer(
          v,
          _start.add(const Duration(days: 10)),
        ),
        20400,
      );
    });

    test('never goes below the last reading', () {
      final v = _vehicle();
      expect(
        MaintenancePlanner.estimateOdometer(
          v,
          _start.subtract(const Duration(days: 3)),
        ),
        20000,
      );
    });
  });

  group('effectiveInterval', () {
    test('uses normal intervals for personal use with synthetic oil', () {
      final i = MaintenancePlanner.effectiveInterval(_oil, _vehicle())!;
      expect(i.km, 10000);
      expect(i.months, 12);
    });

    test('uses severe intervals for work use', () {
      final v = _vehicle(usage: VehicleUsage.work);
      expect(MaintenancePlanner.effectiveInterval(_oil, v)!.km, 5000);
      expect(MaintenancePlanner.effectiveInterval(_belt, v)!.km, 40000);
    });

    test('falls back to normal months when severe lists only km', () {
      final v = _vehicle(usage: VehicleUsage.work);
      expect(MaintenancePlanner.effectiveInterval(_belt, v)!.months, 72);
    });

    test('non-synthetic oil shortens only the oil change', () {
      final v = _vehicle(oil: OilType.semiSynthetic);
      expect(MaintenancePlanner.effectiveInterval(_oil, v)!.km, 5000);
      expect(MaintenancePlanner.effectiveInterval(_belt, v)!.km, 60000);
    });

    test('oil type caps the oil interval', () {
      const longOil = MaintenanceItem(
        partId: 'engine_oil',
        action: MaintenanceAction.replace,
        confidence: Confidence.official,
        normal: ServiceInterval(km: 10000),
        severe: ServiceInterval(km: 8000),
      );
      final v = _vehicle(oil: OilType.mineral);
      expect(MaintenancePlanner.effectiveInterval(longOil, v)!.km, 5000);
    });

    test('returns null for inspect-only items without an interval', () {
      expect(MaintenancePlanner.effectiveInterval(_chain, _vehicle()), isNull);
    });
  });

  group('plan', () {
    test('counts from tracking start when nothing is logged', () {
      final now = _start.add(const Duration(days: 100));
      final dues = planner.plan(
        vehicle: _vehicle(dailyKm: 50),
        group: _group,
        records: const [],
        now: now,
      );
      final oil = _dueFor(dues, 'engine_oil');
      expect(oil.hasServiceRecord, isFalse);
      expect(oil.dueKm, 30000);
      expect(oil.remainingKm, 30000 - 25000);
      // Not logged and not yet provably due: unknown, not a reassuring ok.
      expect(oil.status, DueStatus.unknown);
    });

    test('a logged item that is not due is ok', () {
      final dues = planner.plan(
        vehicle: _vehicle(),
        group: _group,
        records: [
          ServiceRecord(
            id: 'r',
            vehicleId: 'v1',
            partId: 'engine_oil',
            km: 20000,
            date: _start,
          ),
        ],
        now: _start.add(const Duration(days: 10)),
      );
      expect(_dueFor(dues, 'engine_oil').status, DueStatus.ok);
      expect(_dueFor(dues, 'timing_belt').status, DueStatus.unknown);
    });

    test('skips items without an interval', () {
      final dues = planner.plan(
        vehicle: _vehicle(),
        group: _group,
        records: const [],
        now: _start,
      );
      expect(dues.map((d) => d.item.partId), isNot(contains('timing_chain')));
    });

    test('counts from the latest service record of this vehicle', () {
      final records = [
        ServiceRecord(
          id: 'r1',
          vehicleId: 'v1',
          partId: 'engine_oil',
          km: 24000,
          date: DateTime(2026, 3, 1),
        ),
        ServiceRecord(
          id: 'r0',
          vehicleId: 'v1',
          partId: 'engine_oil',
          km: 21000,
          date: DateTime(2026, 1, 20),
        ),
        ServiceRecord(
          id: 'other',
          vehicleId: 'v2',
          partId: 'engine_oil',
          km: 99000,
          date: DateTime(2026, 3, 1),
        ),
      ];
      final dues = planner.plan(
        vehicle: _vehicle(),
        group: _group,
        records: records,
        now: DateTime(2026, 3, 2),
      );
      final oil = _dueFor(dues, 'engine_oil');
      expect(oil.hasServiceRecord, isTrue);
      expect(oil.lastDoneKm, 24000);
      expect(oil.dueKm, 34000);
      expect(oil.dueDate, DateTime(2027, 3, 1));
    });

    test('marks overdue by km and sorts it first', () {
      final now = _start.add(const Duration(days: 220));
      final dues = planner.plan(
        vehicle: _vehicle(dailyKm: 50),
        group: _group,
        records: const [],
        now: now,
      );
      expect(dues.first.item.partId, 'engine_oil');
      expect(dues.first.status, DueStatus.overdue);
    });

    test('marks overdue by time even with few km', () {
      final dues = planner.plan(
        vehicle: _vehicle(dailyKm: 1),
        group: _group,
        records: const [],
        now: DateTime(2027, 1, 2),
      );
      expect(_dueFor(dues, 'engine_oil').status, DueStatus.overdue);
    });

    test('marks due soon inside the km window', () {
      // 10,000 km interval → window is max(1000, 10%) = 1000 km.
      final now = _start.add(const Duration(days: 182));
      final dues = planner.plan(
        vehicle: _vehicle(dailyKm: 50),
        group: _group,
        records: const [],
        now: now,
      );
      final oil = _dueFor(dues, 'engine_oil');
      expect(oil.remainingKm, 900);
      expect(oil.status, DueStatus.dueSoon);
    });
  });
}
