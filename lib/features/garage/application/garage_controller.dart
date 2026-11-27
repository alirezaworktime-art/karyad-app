import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog.dart';
import '../data/garage_repository.dart';
import '../domain/maintenance_planner.dart';
import '../domain/vehicle.dart';

/// App state for the garage: loads once, applies user actions, saves after
/// each change and notifies listeners. Screens never touch storage directly.
class GarageController extends ChangeNotifier {
  GarageController({
    required GarageRepository repository,
    required this.catalog,
    DateTime Function()? clock,
    MaintenancePlanner planner = const MaintenancePlanner(),
  }) : _repository = repository,
       _clock = clock ?? DateTime.now,
       _planner = planner;

  final GarageRepository _repository;
  final Catalog catalog;
  final DateTime Function() _clock;
  final MaintenancePlanner _planner;

  GarageData _data = const GarageData();
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isOnboarded => _data.onboarded && _data.vehicles.isNotEmpty;
  List<Vehicle> get vehicles => _data.vehicles;
  Vehicle? get primaryVehicle =>
      _data.vehicles.isEmpty ? null : _data.vehicles.first;
  DateTime get now => _clock();

  Future<void> load() async {
    _data = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _commit(GarageData next) async {
    _data = next;
    notifyListeners();
    await _repository.save(next);
  }

  String _newId(String prefix) =>
      '$prefix-${_clock().microsecondsSinceEpoch.toRadixString(36)}';

  Future<Vehicle> addVehicle({
    required String modelId,
    required VehicleUsage usage,
    required OilType oilType,
    required int currentKm,
    required int averageDailyKm,
    bool severeConditions = false,
  }) async {
    final reading = OdometerReading(km: currentKm, date: _clock());
    final vehicle = Vehicle(
      id: _newId('car'),
      modelId: modelId,
      usage: usage,
      oilType: oilType,
      averageDailyKm: averageDailyKm,
      trackingStart: reading,
      lastReading: reading,
      severeConditions: severeConditions,
    );
    await _commit(
      _data.copyWith(onboarded: true, vehicles: [..._data.vehicles, vehicle]),
    );
    return vehicle;
  }

  Future<void> updateOdometer(String vehicleId, int km) async {
    final reading = OdometerReading(km: km, date: _clock());
    await _commit(
      _data.copyWith(
        vehicles: [
          for (final v in _data.vehicles)
            v.id == vehicleId ? v.copyWith(lastReading: reading) : v,
        ],
      ),
    );
  }

  /// Logs a completed task. If the odometer given is past the last
  /// confirmed reading, it also becomes the new reading.
  Future<void> recordService({
    required String vehicleId,
    required String partId,
    required int km,
    DateTime? date,
    int? costRial,
  }) async {
    final when = date ?? _clock();
    final record = ServiceRecord(
      id: _newId('svc'),
      vehicleId: vehicleId,
      partId: partId,
      km: km,
      date: when,
      costRial: costRial,
    );
    await _commit(
      _data.copyWith(
        records: [..._data.records, record],
        vehicles: [
          for (final v in _data.vehicles)
            v.id == vehicleId && km > v.lastReading.km
                ? v.copyWith(lastReading: OdometerReading(km: km, date: when))
                : v,
        ],
      ),
    );
  }

  int estimatedOdometer(Vehicle vehicle) =>
      MaintenancePlanner.estimateOdometer(vehicle, _clock());

  List<MaintenanceDue> duesFor(Vehicle vehicle) {
    final group = catalog.groupForModel(vehicle.modelId);
    if (group == null) return const [];
    return _planner.plan(
      vehicle: vehicle,
      group: group,
      records: _data.records,
      now: _clock(),
    );
  }

  List<ServiceRecord> historyFor(String vehicleId) {
    final list = [
      for (final r in _data.records)
        if (r.vehicleId == vehicleId) r,
    ]..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}
