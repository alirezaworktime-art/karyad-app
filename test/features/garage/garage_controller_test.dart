import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/features/garage/application/garage_controller.dart';
import 'package:karyad/features/garage/data/garage_repository.dart';
import 'package:karyad/features/garage/domain/vehicle.dart';

import '../../helpers/catalog_fixture.dart';

void main() {
  late InMemoryGarageRepository repository;
  late DateTime now;
  late GarageController controller;

  setUp(() async {
    repository = InMemoryGarageRepository();
    now = DateTime(2026, 11, 27);
    controller = GarageController(
      repository: repository,
      catalog: loadCatalog(),
      clock: () => now,
    );
    await controller.load();
  });

  test('starts not onboarded', () {
    expect(controller.isLoaded, isTrue);
    expect(controller.isOnboarded, isFalse);
  });

  test('the oil sticker sets the next oil change exactly', () async {
    await controller.addVehicle(
      modelId: 'dena-plus',
      usage: VehicleUsage.personal,
      currentKm: 62400,
      nextOilChangeKm: 72000,
    );
    final plan = controller.planFor(controller.primaryVehicle!)!;
    final oil = plan.all.firstWhere((d) => d.partId == 'engine_oil');
    expect(oil.dueKm, 72000);
    // The sticker is not a visit the user made, so history stays empty.
    expect(controller.visitsFor(controller.primaryVehicle!.id), isEmpty);
  });

  test('without a sticker oil follows the factory milestones', () async {
    await controller.addVehicle(
      modelId: 'dena-plus',
      usage: VehicleUsage.personal,
      currentKm: 62400,
    );
    final plan = controller.planFor(controller.primaryVehicle!)!;
    expect(plan.all.firstWhere((d) => d.partId == 'engine_oil').dueKm, 70000);
  });

  test(
    'remembered replacements set targets; impossible ones are ignored',
    () async {
      final items = controller.startingHistoryItems('dena-plus');
      expect(items.map((i) => i.partId), contains('air_filter'));
      expect(items.map((i) => i.partId), isNot(contains('engine_oil')));

      await controller.addVehicle(
        modelId: 'dena-plus',
        usage: VehicleUsage.personal,
        currentKm: 62400,
        lastReplacedKm: {'air_filter': 61000, 'spark_plugs': 90000},
      );
      final car = controller.primaryVehicle!;
      final all = controller.planFor(car)!.all;
      expect(all.firstWhere((d) => d.partId == 'air_filter').dueKm, 71000);
      // 90,000 is above the odometer, so plugs stay on the factory schedule.
      expect(all.firstWhere((d) => d.partId == 'spark_plugs').dueKm, 80000);
      expect(controller.visitsFor(car.id), isEmpty);
    },
  );

  test('a visit saves every ticked item and moves the odometer', () async {
    final car = await controller.addVehicle(
      modelId: 'quick',
      usage: VehicleUsage.personal,
      currentKm: 30000,
    );
    now = now.add(const Duration(days: 40));
    await controller.recordVisit(
      vehicleId: car.id,
      km: 31800,
      partIds: ['engine_oil', 'air_filter'],
      costRial: 24000000,
    );
    final vehicle = controller.primaryVehicle!;
    expect(vehicle.lastReading.km, 31800);
    final visits = controller.visitsFor(car.id);
    expect(visits.single.partIds, ['engine_oil', 'air_filter']);
    expect(visits.single.costRial, 24000000);
    final oil = controller
        .planFor(vehicle)!
        .all
        .firstWhere((d) => d.partId == 'engine_oil');
    expect(oil.dueKm, 31800 + 5000);
  });

  test('readings only move forward and go stale after two weeks', () async {
    final car = await controller.addVehicle(
      modelId: 'tiba',
      usage: VehicleUsage.personal,
      currentKm: 100000,
    );
    expect(controller.readingIsStale(controller.primaryVehicle!), isFalse);
    now = now.add(const Duration(days: 15));
    expect(controller.readingIsStale(controller.primaryVehicle!), isTrue);
    await controller.addReading(car.id, 99000);
    expect(controller.primaryVehicle!.lastReading.km, 100000);
    await controller.addReading(car.id, 100700);
    expect(controller.primaryVehicle!.lastReading.km, 100700);
    expect(controller.readingIsStale(controller.primaryVehicle!), isFalse);
  });

  test('work cars ask for the odometer weekly', () async {
    await controller.addVehicle(
      modelId: 'tiba',
      usage: VehicleUsage.work,
      currentKm: 100000,
    );
    now = now.add(const Duration(days: 8));
    expect(controller.readingIsStale(controller.primaryVehicle!), isTrue);
  });

  test('deleting a visit removes it from history', () async {
    final car = await controller.addVehicle(
      modelId: 'quick',
      usage: VehicleUsage.personal,
      currentKm: 30000,
    );
    await controller.recordVisit(
      vehicleId: car.id,
      km: 30000,
      partIds: ['spark_plugs'],
    );
    final visit = controller.visitsFor(car.id).single;
    await controller.deleteVisit(visit.id);
    expect(controller.visitsFor(car.id), isEmpty);
  });

  test('data round-trips through JSON, including color', () async {
    await controller.addVehicle(
      modelId: 'shahin',
      usage: VehicleUsage.work,
      currentKm: 12000,
      oilType: OilType.semiSynthetic,
      color: CarColor.silver,
    );
    final saved = await repository.load();
    final decoded = GarageData.fromJson(
      jsonDecode(jsonEncode(saved.toJson())) as Map<String, Object?>,
    );
    final v = decoded.vehicles.single;
    expect(v.color, CarColor.silver);
    expect(v.oilType, OilType.semiSynthetic);
    expect(v.readings.single.km, 12000);
  });

  test('reads data saved by version 0.1', () {
    final legacy = Vehicle.fromJson({
      'id': 'old',
      'modelId': 'dena',
      'usage': 'personal',
      'oilType': 'fullSynthetic',
      'averageDailyKm': 40,
      'trackingStart': {'km': 62000, 'date': '2026-11-01T00:00:00.000'},
      'lastReading': {'km': 62000, 'date': '2026-11-01T00:00:00.000'},
    });
    expect(legacy.lastReading.km, 62000);
    expect(legacy.color, CarColor.white);
  });

  group('own oil interval', () {
    test('replaces the factory figure and the oil-type cap', () async {
      final car = await controller.addVehicle(
        modelId: 'dena-plus',
        usage: VehicleUsage.personal,
        currentKm: 62400,
        oilType: OilType.mineral,
        nextOilChangeKm: 67000,
      );
      await controller.setOilInterval(car.id, 6000);
      var oil = controller
          .planFor(controller.primaryVehicle!)!
          .all
          .firstWhere((d) => d.partId == 'engine_oil');
      // Sticker 67,000 with the mineral 5,000 cap → last change at 62,000.
      expect(oil.dueKm, 68000);

      await controller.setOilInterval(car.id, 50);
      expect(controller.primaryVehicle!.oilIntervalKm, 6000);

      await controller.setOilInterval(car.id, null);
      oil = controller
          .planFor(controller.primaryVehicle!)!
          .all
          .firstWhere((d) => d.partId == 'engine_oil');
      expect(oil.dueKm, 67000);
    });

    test('a new sticker at an oil change sets the interval', () async {
      final car = await controller.addVehicle(
        modelId: 'quick',
        usage: VehicleUsage.personal,
        currentKm: 30000,
      );
      await controller.recordVisit(
        vehicleId: car.id,
        km: 30500,
        partIds: ['engine_oil'],
        nextOilChangeKm: 36500,
      );
      final vehicle = controller.primaryVehicle!;
      expect(vehicle.oilIntervalKm, 6000);
      final oil = controller
          .planFor(vehicle)!
          .all
          .firstWhere((d) => d.partId == 'engine_oil');
      expect(oil.dueKm, 36500);
    });

    test('a sticker without an oil change is ignored', () async {
      final car = await controller.addVehicle(
        modelId: 'quick',
        usage: VehicleUsage.personal,
        currentKm: 30000,
      );
      await controller.recordVisit(
        vehicleId: car.id,
        km: 30500,
        partIds: ['air_filter'],
        nextOilChangeKm: 36500,
      );
      expect(controller.primaryVehicle!.oilIntervalKm, isNull);
    });
  });

  group('documents', () {
    test('remind within 30 days and after expiry', () async {
      final car = await controller.addVehicle(
        modelId: 'quick',
        usage: VehicleUsage.personal,
        currentKm: 30000,
      );
      await controller.setDocumentExpiry(
        car.id,
        VehicleDocument.insurance,
        DateTime(2027, 3, 1),
      );
      await controller.setDocumentExpiry(
        car.id,
        VehicleDocument.inspection,
        DateTime(2026, 12, 10),
      );
      var vehicle = controller.primaryVehicle!;
      expect(
        controller.documentsFor(vehicle).map((d) => d.document),
        [VehicleDocument.inspection, VehicleDocument.insurance],
      );
      expect(controller.documentsToRenew(vehicle).single.daysLeft, 13);

      now = DateTime(2026, 12, 12);
      final expired = controller.documentsToRenew(vehicle).single;
      expect(expired.expired, isTrue);

      await controller.setDocumentExpiry(
        car.id,
        VehicleDocument.inspection,
        null,
      );
      vehicle = controller.primaryVehicle!;
      expect(controller.documentsFor(vehicle), hasLength(1));
    });

    test('survive saving and loading', () async {
      final car = await controller.addVehicle(
        modelId: 'quick',
        usage: VehicleUsage.personal,
        currentKm: 30000,
      );
      await controller.setDocumentExpiry(
        car.id,
        VehicleDocument.insurance,
        DateTime(2027, 3, 1),
      );
      await controller.setOilInterval(car.id, 6000);
      final json = jsonDecode(jsonEncode(controller.primaryVehicle!.toJson()));
      final restored = Vehicle.fromJson(json as Map<String, Object?>);
      expect(restored.oilIntervalKm, 6000);
      expect(
        restored.documentExpiry[VehicleDocument.insurance],
        DateTime(2027, 3, 1),
      );
    });
  });
}
