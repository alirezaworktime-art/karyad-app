import 'package:flutter/foundation.dart';

import '../../catalog/domain/body_type.dart';
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

/// A document the user entered, with how many days are left on it.
class DocumentStatus {
  const DocumentStatus({
    required this.document,
    required this.expiry,
    required this.daysLeft,
  });

  final VehicleDocument document;
  final DateTime expiry;

  /// Negative once the document has expired.
  final int daysLeft;

  bool get expired => daysLeft < 0;
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

  /// The car every screen shows; the user switches it from home.
  Vehicle? get activeVehicle {
    final vehicles = _data.vehicles;
    if (vehicles.isEmpty) return null;
    return vehicles.where((v) => v.id == _data.activeVehicleId).firstOrNull ??
        vehicles.first;
  }

  bool get remindersEnabled => _data.remindersEnabled;

  Future<void> setRemindersEnabled(bool on) =>
      _commit(_data.copyWith(remindersEnabled: on));

  /// Name to show for a car: its nickname, else the model name.
  String displayName(Vehicle vehicle) =>
      vehicle.nickname ?? catalog.model(vehicle.modelId)?.nameFa ?? '';

  Future<void> selectVehicle(String vehicleId) async {
    if (activeVehicle?.id == vehicleId) return;
    _vehicle(vehicleId);
    await _commit(_data.copyWith(activeVehicleId: vehicleId));
  }

  /// Gives a car its own name (to tell two of the same model apart), or
  /// clears it with null or a blank name.
  Future<void> renameVehicle(String vehicleId, String? nickname) async {
    final name = nickname?.trim();
    final updated = _vehicle(vehicleId)
        .copyWith(nickname: name == null || name.isEmpty ? null : name);
    await _commit(_data.copyWith(vehicles: _replace(updated)));
  }

  /// Deletes one car and its history. Deleting the last car starts over.
  Future<void> removeVehicle(String vehicleId) async {
    final remaining = [
      for (final v in _data.vehicles)
        if (v.id != vehicleId) v,
    ];
    if (remaining.isEmpty) {
      await _commit(const GarageData());
      return;
    }
    await _commit(
      GarageData(
        onboarded: true,
        vehicles: remaining,
        records: [
          for (final r in _data.records)
            if (r.vehicleId != vehicleId) r,
        ],
        activeVehicleId: _data.activeVehicleId == vehicleId
            ? remaining.first.id
            : _data.activeVehicleId,
        remindersEnabled: _data.remindersEnabled,
      ),
    );
  }

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

  /// Parts whose last replacement the user can tell us while adding a car:
  /// everything replaced on a km interval, except the oil (the sticker
  /// covers it). Without an answer a part follows the factory milestones.
  List<MaintenanceItem> startingHistoryItems(
    String modelId, {
    Transmission transmission = Transmission.manual,
  }) {
    final group = catalog.groupForModel(modelId);
    if (group == null) return const [];
    return [
      for (final item in group.items)
        if (item.action == MaintenanceAction.replace &&
            item.partId != MaintenancePlanner.engineOilPartId &&
            (Transmission.ofPart(item.partId) ?? transmission) ==
                transmission &&
            (item.normal?.km ?? item.severe?.km) != null)
          item,
    ];
  }

  /// Gearbox types worth asking about for this model: manual plus every
  /// automatic kind its catalog group has an item for. Empty when the
  /// group only knows manual gearboxes, so there is nothing to ask.
  List<Transmission> transmissionChoices(String modelId) {
    final group = catalog.groupForModel(modelId);
    if (group == null) return const [];
    final kinds = {
      for (final item in group.items) ?Transmission.ofPart(item.partId),
    }..remove(Transmission.manual);
    if (kinds.isEmpty) return const [];
    return [
      Transmission.manual,
      for (final t in Transmission.values)
        if (kinds.contains(t)) t,
    ];
  }

  /// Adds a car. [nextOilChangeKm] is the number on the oil-change sticker:
  /// the engine-oil countdown then ends exactly there. [lastReplacedKm] maps
  /// part ids to the odometer at their last replacement, as the user
  /// remembers it; values above [currentKm] are ignored.
  Future<Vehicle> addVehicle({
    required String modelId,
    required VehicleUsage usage,
    required int currentKm,
    OilType oilType = OilType.fullSynthetic,
    CarColor color = CarColor.white,
    int? nextOilChangeKm,
    Transmission transmission = Transmission.manual,
    String? nickname,
    BodyType? bodyType,
    int? oilIntervalKm,
    Map<String, int> lastReplacedKm = const {},
  }) async {
    final now = _clock();
    final name = nickname?.trim();
    final vehicle = Vehicle(
      id: _newId('car'),
      modelId: modelId,
      nickname: name == null || name.isEmpty ? null : name,
      bodyType: bodyType,
      oilIntervalKm: oilIntervalKm,
      usage: usage,
      oilType: oilType,
      color: color,
      transmission: transmission,
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
          nextDueKm: nextOilChangeKm,
        ),
      );
    }

    for (final entry in lastReplacedKm.entries) {
      if (entry.value < 0 || entry.value > currentKm) continue;
      if (entry.key == MaintenancePlanner.engineOilPartId) continue;
      seeded.add(
        ServiceRecord(
          id: _newId('svc'),
          vehicleId: vehicle.id,
          partId: entry.key,
          km: entry.value,
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
        activeVehicleId: vehicle.id,
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
    Transmission? transmission,
  }) async {
    final updated = _vehicle(vehicleId).copyWith(
      color: color,
      usage: usage,
      oilType: oilType,
      transmission: transmission,
    );
    await _commit(_data.copyWith(vehicles: _replace(updated)));
  }

  /// Accepted range for a user-set oil interval, in km.
  static const minOilIntervalKm = 1000;
  static const maxOilIntervalKm = 30000;

  /// Days before a document expires when the home screen starts reminding.
  static const documentReminderDays = 30;

  /// Sets the user's own oil-change interval, or clears it with null so the
  /// factory figure and oil type apply again. Out-of-range values are
  /// ignored.
  Future<void> setOilInterval(String vehicleId, int? km) async {
    if (km != null && (km < minOilIntervalKm || km > maxOilIntervalKm)) {
      return;
    }
    final updated = _vehicle(vehicleId).copyWith(oilIntervalKm: km);
    await _commit(_data.copyWith(vehicles: _replace(updated)));
  }

  /// Sets or (with null) clears a document's expiry date.
  Future<void> setDocumentExpiry(
    String vehicleId,
    VehicleDocument document,
    DateTime? expiry,
  ) async {
    final vehicle = _vehicle(vehicleId);
    final documents = {...vehicle.documentExpiry};
    if (expiry == null) {
      documents.remove(document);
    } else {
      documents[document] = DateTime(expiry.year, expiry.month, expiry.day);
    }
    final updated = vehicle.copyWith(documentExpiry: documents);
    await _commit(_data.copyWith(vehicles: _replace(updated)));
  }

  /// Every entered document, soonest expiry first.
  List<DocumentStatus> documentsFor(Vehicle vehicle) {
    final today = _clock();
    return [
      for (final e in vehicle.documentExpiry.entries)
        DocumentStatus(
          document: e.key,
          expiry: e.value,
          daysLeft: MaintenancePlanner.daysBetween(today, e.value),
        ),
    ]..sort((a, b) => a.expiry.compareTo(b.expiry));
  }

  /// Documents expired or expiring within [documentReminderDays].
  List<DocumentStatus> documentsToRenew(Vehicle vehicle) => [
    for (final d in documentsFor(vehicle))
      if (d.daysLeft <= documentReminderDays) d,
  ];

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
    int? nextOilChangeKm,
  }) async {
    if (partIds.isEmpty) return;
    final when = date ?? _clock();
    final visitId = _newId('visit');
    // The new oil sticker is the next target as given, and tells us the
    // interval this oil runs for, which then applies to later changes too.
    final stickerInterval = nextOilChangeKm == null
        ? null
        : nextOilChangeKm - km;
    final validSticker =
        partIds.contains(MaintenancePlanner.engineOilPartId) &&
        stickerInterval != null &&
        stickerInterval >= minOilIntervalKm &&
        stickerInterval <= maxOilIntervalKm;
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
          nextDueKm:
              validSticker && partIds[i] == MaintenancePlanner.engineOilPartId
              ? nextOilChangeKm
              : null,
        ),
    ];
    var vehicle = _vehicle(vehicleId);
    if (validSticker) {
      vehicle = vehicle.copyWith(oilIntervalKm: stickerInterval);
    }
    if (km > vehicle.lastReading.km) {
      vehicle = vehicle.copyWith(
        readings: [
          ...vehicle.readings,
          OdometerReading(km: km, date: _clock()),
        ],
      );
    }
    final vehicles = _replace(vehicle);
    await _commit(
      _data.copyWith(
        records: [..._data.records, ...records],
        vehicles: vehicles,
      ),
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
