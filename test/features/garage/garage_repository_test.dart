import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/features/garage/application/garage_controller.dart';
import 'package:karyad/features/garage/data/garage_repository.dart';
import 'package:karyad/features/garage/domain/vehicle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/catalog_fixture.dart';

GarageController _controller(SharedPreferences prefs) => GarageController(
  repository: PreferencesGarageRepository(prefs),
  catalog: loadCatalog(),
  clock: () => DateTime(2026, 11, 27),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a car added before a restart is still there after it', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = _controller(prefs);
    await first.load();
    final car = await first.addVehicle(
      modelId: 'dena-plus',
      usage: VehicleUsage.personal,
      currentKm: 62400,
      color: CarColor.silver,
      nextOilChangeKm: 72000,
    );
    await first.recordVisit(
      vehicleId: car.id,
      km: 62400,
      partIds: const ['air_filter'],
      costRial: 1500000,
    );
    await first.addReading(car.id, 63000);

    // A fresh controller reads only what was written to storage.
    final restarted = _controller(await SharedPreferences.getInstance());
    await restarted.load();

    expect(restarted.isOnboarded, isTrue);
    final saved = restarted.primaryVehicle!;
    expect(saved.modelId, 'dena-plus');
    expect(saved.color, CarColor.silver);
    expect(saved.lastReading.km, 63000);
    expect(restarted.visitsFor(saved.id), hasLength(1));
    expect(restarted.planFor(saved)!.nextVisit!.dueKm, 72000);
  });

  test('a corrupt document falls back to the previous copy', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = _controller(prefs);
    await first.load();
    await first.addVehicle(
      modelId: 'quick',
      usage: VehicleUsage.personal,
      currentKm: 30000,
    );
    await first.addReading(first.primaryVehicle!.id, 30500);
    await prefs.setString('garage.v1', '{not json');

    final restarted = _controller(prefs);
    await restarted.load();
    expect(restarted.isOnboarded, isTrue);
    expect(restarted.primaryVehicle!.lastReading.km, 30000);
  });
}
