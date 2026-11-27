import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog.dart';
import '../data/garage_repository.dart';
import '../domain/maintenance_planner.dart';
import '../domain/vehicle.dart';

/// One workshop visit in the history: everything saved together.
class VisitSummary {
  const VisitSummary({
    required this.id,
    required this.date,
    required this.km,
    required this.partIds,
    required this.costRial,
  });

  final String id;
  final DateTime date;
  final int km;
  final List<String> partIds;
  final int? costRial;
}

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
  int _idCounter = 0;

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

  String _newId(String prefix) {
    _idCounter += 1;
    return '$prefix-${_clock().microsecondsSinceEpoch.toRadixString(36)}'
        '-$_idCounter';
  }

  Vehicle _vehicle(String id) => _data.vehicles.firstWhere((v) => v.id == id);

  List<Vehicle> _replace(Vehicle updated) => [
    for (final v in _data.vehicles) v.id == updated.id ? updated : v,
  ];

  /// Adds a car. [nextOilChangeKm] is the number on the oil-change sticker:
  /// the engine-oil countdown then ends exactly there.
  Future<Vehicle> addVehicle({
    required String modelId,
    required VehicleUsage usage,
    required int currentKm,
    OilType oilType = OilType.fullSynthetic,
    CarColor color = CarColor.white,
    int? nextOilChangeKm,
  }) async {
    final now = _clock();
    final vehicle = Vehicle(
      id: _newId('car'),
      modelId: modelId,
      usage: usage,
      oilType: oilType,
      color: color,
      readings: [OdometerReading(km: currentKm, date: now)],
    );

    final seeded = <ServiceRecord>[];
    final oilItem = _oilItem(modelId);
    final oilKm = oilItem == null
        ? null
        : MaintenancePlanner.effectiveInterval(oilItem, vehicle)?.km;
    if (nextOilChangeKm != null && oilKm != null) {
      final lastChange = nextOilChangeKm - oilKm;
      seeded.add(
        ServiceRecord(
          id: _newId('svc'),
          vehicleId: vehicle.id,
          partId: MaintenancePlanner.engineOilPartId,
          km: lastChange < 0 ? 0 : lastChange,
          date: now,
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

  MaintenanceItem? _oilItem(String modelId) {
    final group = catalog.groupForModel(modelId);
    if (group == null) return null;
    for (final item in group.items) {
      if (item.partId == MaintenancePlanner.engineOilPartId) return item;
    }
    return null;
  }

  Future<void> updateVehicle(
    String vehicleId, {
    CarColor? color,
    VehicleUsage? usage,
    OilType? oilType,
  }) async {
    final updated = _vehicle(
      vehicleId,
    ).copyWith(color: color, usage: usage, oilType: oilType);
    await _commit(_data.copyWith(vehicles: _replace(updated)));
  }

  /// Adds what the dashboard shows now. Values below the last reading are
  /// rejected by the UI; here they are ignored so data stays consistent.
  Future<void> addReading(String vehicleId, int km) async {
    final vehicle = _vehicle(vehicleId);
    if (km < vehicle.lastReading.km) return;
    final updated = vehicle.copyWith(
      readings: [
        ...vehicle.readings,
        OdometerReading(km: km, date: _clock()),
      ],
    );
    await _commit(_data.copyWith(vehicles: _replace(updated)));
  }

  /// Saves one workshop visit: every ticked item at the same km and date.
  /// A km above the last reading also becomes the new odometer reading.
  Future<void> recordVisit({
    required String vehicleId,
    required int km,
    required List<String> partIds,
    DateTime? date,
    int? costRial,
  }) async {
    if (partIds.isEmpty) return;
    final when = date ?? _clock();
    final visitId = _newId('visit');
    final records = [
      for (var i = 0; i < partIds.length; i++)
        ServiceRecord(
          id: _newId('svc'),
          vehicleId: vehicleId,
          partId: partIds[i],
          km: km,
          date: when,
          visitId: visitId,
          costRial: i == 0 ? costRial : null,
        ),
    ];
    final vehicle = _vehicle(vehicleId);
    final vehicles = km > vehicle.lastReading.km
        ? _replace(
            vehicle.copyWith(
              readings: [
                ...vehicle.readings,
                OdometerReading(km: km, date: _clock()),
              ],
            ),
          )
        : _data.vehicles;
    await _commit(
      _data.copyWith(records: [..._data.records, ...records], vehicles: vehicles),
    );
  }

  Future<void> deleteVisit(String visitId) async {
    await _commit(
      _data.copyWith(
        records: [
          for (final r in _data.records)
            if (r.visitId != visitId) r,
        ],
      ),
    );
  }

  /// Wipes everything on this device.
  Future<void> resetAll() => _commit(const GarageData());

  MaintenancePlan? planFor(Vehicle vehicle) {
    final group = catalog.groupForModel(vehicle.modelId);
    if (group == null) return null;
    return planner.plan(
      vehicle: vehicle,
      group: group,
      records: _data.records,
      now: _clock(),
    );
  }

  /// True when the last odometer value is old enough that reminders by km
  /// may be off: two weeks for personal cars, one week for work cars.
  bool readingIsStale(Vehicle vehicle) {
    final days = MaintenancePlanner.daysBetween(
      vehicle.lastReading.date,
      _clock(),
    );
    return days >= (vehicle.usage == VehicleUsage.work ? 7 : 14);
  }

  /// Logged visits, newest first. Records from onboarding (the oil sticker)
  /// are not visits and are left out.
  List<VisitSummary> visitsFor(String vehicleId) {
    final byVisit = <String, List<ServiceRecord>>{};
    for (final r in _data.records) {
      if (r.vehicleId != vehicleId || r.estimated) continue;
      byVisit.putIfAbsent(r.visitId ?? r.id, () => []).add(r);
    }
    final visits = [
      for (final entry in byVisit.entries)
        VisitSummary(
          id: entry.key,
          date: entry.value.first.date,
          km: entry.value.first.km,
          partIds: [for (final r in entry.value) r.partId],
          costRial: entry.value
              .map((r) => r.costRial)
              .whereType<int>()
              .fold<int?>(null, (sum, c) => (sum ?? 0) + c),
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return visits;
  }
}
