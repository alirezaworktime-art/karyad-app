/// How the car is used. Work use (taxi, ride-hailing, delivery) puts it on
/// the manufacturer's severe-conditions schedule.
enum VehicleUsage { personal, work }

/// Engine oil type. Mineral and semi-synthetic oils cap the oil-change
/// interval below the manufacturer's figure, which assumes the recommended
/// oil.
enum OilType {
  mineral(maxKm: 5000),
  semiSynthetic(maxKm: 7000),
  fullSynthetic(maxKm: null);

  const OilType({required this.maxKm});

  /// Upper bound on the oil-change interval in km, or null for none.
  final int? maxKm;
}

class OdometerReading {
  const OdometerReading({required this.km, required this.date});

  final int km;
  final DateTime date;

  Map<String, Object?> toJson() => {'km': km, 'date': date.toIso8601String()};

  factory OdometerReading.fromJson(Map<String, Object?> json) =>
      OdometerReading(
        km: json['km'] as int,
        date: DateTime.parse(json['date'] as String),
      );
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.modelId,
    required this.usage,
    required this.oilType,
    required this.averageDailyKm,
    required this.trackingStart,
    required this.lastReading,
    this.nickname,
    this.severeConditions = false,
  });

  final String id;
  final String modelId;
  final String? nickname;
  final VehicleUsage usage;
  final OilType oilType;

  /// User-declared average km driven per day; used to estimate the odometer
  /// between readings.
  final int averageDailyKm;

  /// Odometer when the car was added. Without a logged service, intervals
  /// count from here.
  final OdometerReading trackingStart;

  /// Most recent odometer the user confirmed.
  final OdometerReading lastReading;

  /// Personal-use cars the user says drive in severe conditions (heavy
  /// traffic, dust, short trips).
  final bool severeConditions;

  /// Work use or declared severe conditions put the whole car on the
  /// severe schedule. Oil type only affects the engine-oil interval.
  bool get usesSevereSchedule => usage == VehicleUsage.work || severeConditions;

  Vehicle copyWith({
    String? nickname,
    VehicleUsage? usage,
    OilType? oilType,
    int? averageDailyKm,
    OdometerReading? lastReading,
    bool? severeConditions,
  }) => Vehicle(
    id: id,
    modelId: modelId,
    nickname: nickname ?? this.nickname,
    usage: usage ?? this.usage,
    oilType: oilType ?? this.oilType,
    averageDailyKm: averageDailyKm ?? this.averageDailyKm,
    trackingStart: trackingStart,
    lastReading: lastReading ?? this.lastReading,
    severeConditions: severeConditions ?? this.severeConditions,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'modelId': modelId,
    'nickname': nickname,
    'usage': usage.name,
    'oilType': oilType.name,
    'averageDailyKm': averageDailyKm,
    'trackingStart': trackingStart.toJson(),
    'lastReading': lastReading.toJson(),
    'severeConditions': severeConditions,
  };

  factory Vehicle.fromJson(Map<String, Object?> json) => Vehicle(
    id: json['id'] as String,
    modelId: json['modelId'] as String,
    nickname: json['nickname'] as String?,
    usage: VehicleUsage.values.byName(json['usage'] as String),
    oilType: OilType.values.byName(json['oilType'] as String),
    averageDailyKm: json['averageDailyKm'] as int,
    trackingStart: OdometerReading.fromJson(
      json['trackingStart'] as Map<String, Object?>,
    ),
    lastReading: OdometerReading.fromJson(
      json['lastReading'] as Map<String, Object?>,
    ),
    severeConditions: json['severeConditions'] as bool? ?? false,
  );
}

/// A maintenance item the user marked as done.
class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.partId,
    required this.km,
    required this.date,
    this.costRial,
    this.note,
  });

  final String id;
  final String vehicleId;
  final String partId;
  final int km;
  final DateTime date;
  final int? costRial;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'partId': partId,
    'km': km,
    'date': date.toIso8601String(),
    'costRial': costRial,
    'note': note,
  };

  factory ServiceRecord.fromJson(Map<String, Object?> json) => ServiceRecord(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String,
    partId: json['partId'] as String,
    km: json['km'] as int,
    date: DateTime.parse(json['date'] as String),
    costRial: json['costRial'] as int?,
    note: json['note'] as String?,
  );
}
