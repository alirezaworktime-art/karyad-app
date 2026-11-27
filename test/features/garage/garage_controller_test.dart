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

  test('adding a vehicle onboards and persists it', () async {
    await controller.addVehicle(
      modelId: 'quick',
      usage: VehicleUsage.personal,
      oilType: OilType.fullSynthetic,
      currentKm: 30000,
      averageDailyKm: 40,
    );
    expect(controller.isOnboarded, isTrue);
    final saved = await repository.load();
    expect(saved.vehicles.single.modelId, 'quick');
  });

  test(
    'recording a service resets that item and advances the odometer',
    () async {
      final car = await controller.addVehicle(
        modelId: 'dena',
        usage: VehicleUsage.personal,
        oilType: OilType.fullSynthetic,
        currentKm: 50000,
        averageDailyKm: 50,
      );
      now = now.add(const Duration(days: 30));
      await controller.recordService(
        vehicleId: car.id,
        partId: 'engine_oil',
        km: 51600,
      );
      final vehicle = controller.primaryVehicle!;
      expect(vehicle.lastReading.km, 51600);
      final oil = controller
          .duesFor(vehicle)
          .firstWhere((d) => d.item.partId == 'engine_oil');
      expect(oil.hasServiceRecord, isTrue);
      expect(oil.dueKm, 61600);
    },
  );

  test('odometer update replaces the estimate', () async {
    final car = await controller.addVehicle(
      modelId: 'tiba',
      usage: VehicleUsage.work,
      oilType: OilType.fullSynthetic,
      currentKm: 100000,
      averageDailyKm: 150,
    );
    now = now.add(const Duration(days: 10));
    expect(controller.estimatedOdometer(controller.primaryVehicle!), 101500);
    await controller.updateOdometer(car.id, 101200);
    expect(controller.estimatedOdometer(controller.primaryVehicle!), 101200);
  });

  test('preferences repository round-trips the garage', () async {
    await controller.addVehicle(
      modelId: 'shahin',
      usage: VehicleUsage.work,
      oilType: OilType.semiSynthetic,
      currentKm: 12000,
      averageDailyKm: 200,
    );
    final saved = await repository.load();
    final decoded = GarageData.fromJson(
      jsonDecode(jsonEncode(saved.toJson())) as Map<String, Object?>,
    );
    expect(decoded.vehicles.single.oilType, OilType.semiSynthetic);
    expect(decoded.vehicles.single.usage, VehicleUsage.work);
  });
}
