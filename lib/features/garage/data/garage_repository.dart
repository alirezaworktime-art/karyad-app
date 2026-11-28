import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/vehicle.dart';

/// Everything the user owns in the app: settings, vehicles, service records.
class GarageData {
  const GarageData({
    this.onboarded = false,
    this.vehicles = const [],
    this.records = const [],
  });

  final bool onboarded;
  final List<Vehicle> vehicles;
  final List<ServiceRecord> records;

  GarageData copyWith({
    bool? onboarded,
    List<Vehicle>? vehicles,
    List<ServiceRecord>? records,
  }) => GarageData(
    onboarded: onboarded ?? this.onboarded,
    vehicles: vehicles ?? this.vehicles,
    records: records ?? this.records,
  );

  Map<String, Object?> toJson() => {
    'version': GarageRepository.dataVersion,
    'onboarded': onboarded,
    'vehicles': [for (final v in vehicles) v.toJson()],
    'records': [for (final r in records) r.toJson()],
  };

  factory GarageData.fromJson(Map<String, Object?> json) => GarageData(
    onboarded: json['onboarded'] as bool? ?? false,
    vehicles: [
      for (final raw in json['vehicles'] as List<Object?>? ?? const [])
        Vehicle.fromJson(raw as Map<String, Object?>),
    ],
    records: [
      for (final raw in json['records'] as List<Object?>? ?? const [])
        ServiceRecord.fromJson(raw as Map<String, Object?>),
    ],
  );
}

/// Persists [GarageData] on the device. The interface lets the storage
/// engine change later (for example to SQLite) without touching the UI.
abstract interface class GarageRepository {
  static const dataVersion = 2;

  Future<GarageData> load();
  Future<void> save(GarageData data);
}

/// Stores the whole garage as one JSON document in shared preferences.
/// Fine for the expected size (a few cars, hundreds of records) and works
/// on Android, web and desktop alike.
class PreferencesGarageRepository implements GarageRepository {
  PreferencesGarageRepository(this._prefs);

  static const _key = 'garage.v1';
  static const _backupKey = 'garage.v1.previous';

  /// Where an unreadable document is set aside, so support can still
  /// recover it and a later save never overwrites it.
  static const _corruptKey = 'garage.v1.unreadable';

  final SharedPreferences _prefs;

  /// False when the stored document could not be read, so it must not
  /// replace the good backup on the next save.
  bool _currentIsReadable = true;

  @override
  Future<GarageData> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return const GarageData();
    final current = _decode(raw);
    if (current != null) return current;

    _currentIsReadable = false;
    await _prefs.setString(_corruptKey, raw);
    final previous = _prefs.getString(_backupKey);
    return (previous == null ? null : _decode(previous)) ?? const GarageData();
  }

  @override
  Future<void> save(GarageData data) async {
    final current = _prefs.getString(_key);
    if (current != null && _currentIsReadable) {
      await _prefs.setString(_backupKey, current);
    }
    await _prefs.setString(_key, jsonEncode(data.toJson()));
    _currentIsReadable = true;
  }

  static GarageData? _decode(String raw) {
    try {
      return GarageData.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }
}

class InMemoryGarageRepository implements GarageRepository {
  InMemoryGarageRepository([this._data = const GarageData()]);

  GarageData _data;

  @override
  Future<GarageData> load() async => _data;

  @override
  Future<void> save(GarageData data) async => _data = data;
}
