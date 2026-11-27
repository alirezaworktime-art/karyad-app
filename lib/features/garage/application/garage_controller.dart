import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog.dart';
import '../data/garage_repository.dart';
import '../domain/maintenance_planner.dart';
import '../domain/vehicle.dart';

/// App state for the garage: loads once, applies user actions, saves after
/// each change and notifies listeners. Screens never touch storage directly.
class GarageController extends ChangeNotifier {
  GarageController({
    required this.repository,
    required this.catalog,
    DateTime Function()? clock,
    this.planner = const MaintenancePlanner(),
  }) : _clock = clock ?? DateTime.now;

  final GarageRepository repository;
  final Catalog catalog;
  final MaintenancePlanner planner;
  final DateTime Function() _clock;

  GarageData _data = const GarageData();
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isOnboarded => _data.onboarded && _data.vehicles.isNotEmpty;
  List<Vehicle> get vehicles => _data.vehicles;
  Vehicle? get primaryVehicle =>
      _data.vehicles.isEmpty ? null : _data.vehicles.first;
  DateTime get now => _clock();

  Future<void> load() async {
    _data = await repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _commit(GarageData next) async {
    _data = next;
    notifyListeners();
    await repository.save(next);
  }

  String _newId(String prefix) =>
      '$prefix-${_clock().microsecondsSinceEpoch.toRadixString(36)}';

  /// Adds a car. [lastOilChangeKm], when the user remembers it, seeds the
  /// engine-oil history; its date is estimated from average daily km.
  Future<Vehicle> addVehicle({
    required String modelId,
    required VehicleUsage usage,
    required OilType oilType,
    required int currentKm,
    required int averageDailyKm,
    int? lastOilChangeKm,
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
    final seeded = <ServiceRecord>[];
    if (lastOilChangeKm != null && lastOilChangeKm <= currentKm) {
      final daysAgo = averageDailyKm <= 0
          ? 0
          : (currentKm - lastOilChangeKm) ~/ averageDailyKm;
      seeded.add(
        ServiceRecord(
          id: _newId('svc'),
          vehicleId: vehicle.id,
          partId: MaintenancePlanner.engineOilPartId,
          km: lastOilChangeKm,
          date: reading.date.subtract(Duration(days: daysAgo)),
          estimated: true,
        ),
      );
    }
    await _commit(
      _data.copyWith(
        onboarded: true,
        vehicles: [..._data.vehicles, vehicle],
        records: [..._data.records, ...seeded],
      ),
    );
    return vehicle;
  }

  /// For an item whose history the user does not remember: start counting
  /// from the current odometer and today.
  Future<void> startTrackingFromNow({
    required String vehicleId,
    required String partId,
  }) async {
    final vehicle = _data.vehicles.firstWhere((v) => v.id == vehicleId);
    final record = ServiceRecord(
      id: _newId('svc'),
      vehicleId: vehicleId,
      partId: partId,
      km: estimatedOdometer(vehicle),
      date: _clock(),
      estimated: true,
    );
    await _commit(_data.copyWith(records: [..._data.records, record]));
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
  /// confirmed reading, it also becomes the new reading. A km below today's
  /// estimate is a past service: without an explicit [date], its date is
  /// estimated from average daily km and the record is marked estimated.
  Future<void> recordService({
    required String vehicleId,
    required String partId,
    required int km,
    DateTime? date,
    int? costRial,
  }) async {
    final vehicle = _data.vehicles.firstWhere((v) => v.id == vehicleId);
    final now = _clock();
    final kmBehind = estimatedOdometer(vehicle) - km;
    final isPast = date == null && kmBehind > 0 && vehicle.averageDailyKm > 0;
    final when =
        date ??
        (isPast
            ? now.subtract(Duration(days: kmBehind ~/ vehicle.averageDailyKm))
            : now);
    final record = ServiceRecord(
      id: _newId('svc'),
      vehicleId: vehicleId,
      partId: partId,
      km: km,
      date: when,
      costRial: costRial,
      estimated: isPast && kmBehind ~/ vehicle.averageDailyKm > 0,
    );
    await _commit(
      _data.copyWith(
        records: [..._data.records, record],
        vehicles: [
          for (final v in _data.vehicles)
            v.id == vehicleId && km > v.lastReading.km
                ? v.copyWith(lastReading: OdometerReading(km: km, date: now))
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
    return planner.plan(
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
