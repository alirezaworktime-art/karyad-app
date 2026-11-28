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

/// Gearbox type. Catalog groups list a gearbox-oil item per type; only the
/// one matching the car applies.
enum Transmission {
  manual('دستی'),
  automatic('اتوماتیک'),
  cvt('اتوماتیک CVT');

  const Transmission(this.nameFa);

  final String nameFa;

  /// The gearbox type a catalog part belongs to, or null for parts that
  /// apply to every car (including the generic "gearbox oil").
  static Transmission? ofPart(String partId) => switch (partId) {
    'manual_gearbox_oil' => Transmission.manual,
    'automatic_gearbox_oil' => Transmission.automatic,
    'cvt_oil' => Transmission.cvt,
    _ => null,
  };
}

/// Paperwork with an expiry date that the app reminds about.
enum VehicleDocument {
  insurance('بیمه‌ی شخص ثالث'),
  inspection('معاینه‌ی فنی');

  const VehicleDocument(this.nameFa);

  final String nameFa;
}

/// Lets [Vehicle.copyWith] tell "leave as is" apart from "set to null".
const Object _keep = Object();

/// Body color, used to paint the car illustration.
enum CarColor {
  white(0xFFFFFFFF, 'سفید'),
  silver(0xFFB9BEC7, 'نقره‌ای'),
  gray(0xFF6B7280, 'خاکستری'),
  black(0xFF1F2328, 'مشکی'),
  red(0xFFB42318, 'قرمز'),
  blue(0xFF2756A8, 'آبی'),
  brown(0xFF7A5338, 'قهوه‌ای');

  const CarColor(this.argb, this.nameFa);

  final int argb;
  final String nameFa;
}

/// A value the user read off the dashboard. The app never guesses the
/// odometer; it only knows what the user told it, and when.
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
  Vehicle({
    required this.id,
    required this.modelId,
    required this.usage,
    required this.oilType,
    required List<OdometerReading> readings,
    this.color = CarColor.white,
    this.nickname,
    this.severeConditions = false,
    this.oilIntervalKm,
    this.transmission = Transmission.manual,
    Map<VehicleDocument, DateTime> documentExpiry = const {},
  }) : assert(readings.isNotEmpty, 'a vehicle starts with one reading'),
       documentExpiry = Map.unmodifiable(documentExpiry),
       readings = List<OdometerReading>.unmodifiable(
         List<OdometerReading>.of(readings)
           // Same-day readings tie on date; the odometer never goes back,
           // so km breaks the tie and the last reading is the highest.
           ..sort((x, y) {
             final byDate = x.date.compareTo(y.date);
             return byDate != 0 ? byDate : x.km.compareTo(y.km);
           }),
       );

  final String id;
  final String modelId;
  final String? nickname;
  final VehicleUsage usage;
  final OilType oilType;
  final CarColor color;

  /// Most Iranian cars are manual; data saved before this field existed
  /// loads as manual and can be changed in settings.
  final Transmission transmission;

  /// Every odometer value the user entered, oldest first. The first one is
  /// the day the car was added.
  final List<OdometerReading> readings;

  /// Personal-use cars the user says drive in severe conditions.
  final bool severeConditions;

  /// The user's own oil-change interval (what their mechanic or the oil
  /// can says). When set it replaces the factory figure and [oilType] cap.
  final int? oilIntervalKm;

  /// Expiry date of each document the user entered.
  final Map<VehicleDocument, DateTime> documentExpiry;

  OdometerReading get firstReading => readings.first;
  OdometerReading get lastReading => readings.last;

  /// Work use or declared severe conditions put the whole car on the
  /// severe schedule. Oil type only affects the engine-oil interval.
  bool get usesSevereSchedule => usage == VehicleUsage.work || severeConditions;

  /// Km per day learned from the user's own readings, or null until there
  /// are at least a week and some distance between the first and last one.
  /// Only used to say roughly *when* a km target will be reached.
  double? get learnedDailyKm {
    final days = lastReading.date.difference(firstReading.date).inDays;
    final km = lastReading.km - firstReading.km;
    if (days < 7 || km <= 0) return null;
    return km / days;
  }

  Vehicle copyWith({
    String? nickname,
    VehicleUsage? usage,
    OilType? oilType,
    CarColor? color,
    List<OdometerReading>? readings,
    bool? severeConditions,
    Transmission? transmission,
    Object? oilIntervalKm = _keep,
    Map<VehicleDocument, DateTime>? documentExpiry,
  }) => Vehicle(
    id: id,
    modelId: modelId,
    nickname: nickname ?? this.nickname,
    usage: usage ?? this.usage,
    oilType: oilType ?? this.oilType,
    color: color ?? this.color,
    readings: readings ?? this.readings,
    severeConditions: severeConditions ?? this.severeConditions,
    transmission: transmission ?? this.transmission,
    oilIntervalKm: identical(oilIntervalKm, _keep)
        ? this.oilIntervalKm
        : oilIntervalKm as int?,
    documentExpiry: documentExpiry ?? this.documentExpiry,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'modelId': modelId,
    'nickname': nickname,
    'usage': usage.name,
    'oilType': oilType.name,
    'color': color.name,
    'readings': [for (final r in readings) r.toJson()],
    'severeConditions': severeConditions,
    'oilIntervalKm': oilIntervalKm,
    'transmission': transmission.name,
    'documentExpiry': {
      for (final e in documentExpiry.entries)
        e.key.name: e.value.toIso8601String(),
    },
  };

  factory Vehicle.fromJson(Map<String, Object?> json) {
    final rawReadings = json['readings'] as List<Object?>?;
    final readings = rawReadings != null
        ? [
            for (final raw in rawReadings)
              OdometerReading.fromJson(raw as Map<String, Object?>),
          ]
        // Data saved by version 0.1 kept two readings under these keys.
        : [
            OdometerReading.fromJson(
              json['trackingStart'] as Map<String, Object?>,
            ),
            OdometerReading.fromJson(
              json['lastReading'] as Map<String, Object?>,
            ),
          ];
    final colorName = json['color'] as String?;
    final transmissionName = json['transmission'] as String?;
    final rawDocuments =
        json['documentExpiry'] as Map<String, Object?>? ?? const {};
    return Vehicle(
      id: json['id'] as String,
      modelId: json['modelId'] as String,
      nickname: json['nickname'] as String?,
      usage: VehicleUsage.values.byName(json['usage'] as String),
      oilType: OilType.values.byName(json['oilType'] as String),
      color: colorName == null
          ? CarColor.white
          : CarColor.values.byName(colorName),
      readings: readings,
      severeConditions: json['severeConditions'] as bool? ?? false,
      oilIntervalKm: json['oilIntervalKm'] as int?,
      transmission: Transmission.values
              .where((t) => t.name == transmissionName)
              .firstOrNull ??
          Transmission.manual,
      documentExpiry: {
        for (final e in rawDocuments.entries)
          if (VehicleDocument.values.any((d) => d.name == e.key))
            VehicleDocument.values.byName(e.key): DateTime.parse(
              e.value! as String,
            ),
      },
    );
  }
}

/// One maintenance item done at a service visit.
class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.partId,
    required this.km,
    required this.date,
    this.visitId,
    this.costRial,
    this.note,
    this.estimated = false,
    this.nextDueKm,
  });

  final String id;
  final String vehicleId;
  final String partId;
  final int km;
  final DateTime date;

  /// Records saved together share a visit, shown as one entry in history.
  final String? visitId;

  /// Cost of the whole visit, stored on its first record only.
  final int? costRial;
  final String? note;

  /// True when derived rather than logged at the time (for example from the
  /// oil-change sticker at onboarding).
  final bool estimated;

  /// The km the mechanic wrote for the next change (the oil sticker). When
  /// set it is the target as given, whatever interval settings say.
  final int? nextDueKm;

  Map<String, Object?> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'partId': partId,
    'km': km,
    'date': date.toIso8601String(),
    'visitId': visitId,
    'costRial': costRial,
    'note': note,
    'estimated': estimated,
    'nextDueKm': nextDueKm,
  };

  factory ServiceRecord.fromJson(Map<String, Object?> json) => ServiceRecord(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String,
    partId: json['partId'] as String,
    km: json['km'] as int,
    date: DateTime.parse(json['date'] as String),
    visitId: json['visitId'] as String?,
    costRial: json['costRial'] as int?,
    note: json['note'] as String?,
    estimated: json['estimated'] as bool? ?? false,
    nextDueKm: json['nextDueKm'] as int?,
  );
}
