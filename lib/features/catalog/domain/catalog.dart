/// Maintenance catalog: per-model replacement and inspection intervals.
///
/// Mirrors `catalog/maintenance-catalog.json` in karyad-backend (schema
/// version 1). Pure Dart with no Flutter imports, so it is unit-testable and
/// reusable on every platform.
library;

enum Confidence { official, inferred, unverified }

enum MaintenanceAction { replace, inspect, perform }

/// A repeating interval; a reminder is due at whichever limit comes first.
class ServiceInterval {
  const ServiceInterval({this.km, this.months})
    : assert(km != null || months != null, 'interval needs km or months');

  final int? km;
  final int? months;

  static ServiceInterval? fromJson(Object? json) {
    if (json == null) return null;
    final map = json as Map<String, Object?>;
    return ServiceInterval(
      km: map['km'] as int?,
      months: map['months'] as int?,
    );
  }
}

class Maker {
  const Maker({
    required this.id,
    required this.nameFa,
    required this.roadsidePhone,
  });

  final String id;
  final String nameFa;
  final String roadsidePhone;
}

class Part {
  const Part({required this.id, required this.nameFa});

  final String id;
  final String nameFa;
}

class VehicleModel {
  const VehicleModel({
    required this.id,
    required this.nameFa,
    required this.groupId,
  });

  final String id;
  final String nameFa;
  final String groupId;
}

class MaintenanceItem {
  const MaintenanceItem({
    required this.partId,
    required this.action,
    required this.confidence,
    this.normal,
    this.severe,
    this.noteFa,
  });

  final String partId;
  final MaintenanceAction action;

  /// The item's own confidence, or its group's when the item sets none.
  final Confidence confidence;
  final ServiceInterval? normal;
  final ServiceInterval? severe;
  final String? noteFa;

  /// True when the item has an interval a reminder can be scheduled from.
  bool get isSchedulable => normal != null || severe != null;
}

class VehicleGroup {
  const VehicleGroup({
    required this.id,
    required this.makerId,
    required this.models,
    required this.confidence,
    required this.sourceFa,
    required this.items,
  });

  final String id;
  final String makerId;
  final List<VehicleModel> models;
  final Confidence confidence;
  final String sourceFa;
  final List<MaintenanceItem> items;
}

class Catalog {
  Catalog({
    required this.catalogVersion,
    required this.severeConditionsFa,
    required this.makers,
    required this.parts,
    required this.groups,
  }) : _partsById = {for (final part in parts) part.id: part},
       _makersById = {for (final maker in makers) maker.id: maker},
       _groupsById = {for (final group in groups) group.id: group},
       _modelsById = {
         for (final group in groups)
           for (final model in group.models) model.id: model,
       };

  final String catalogVersion;
  final String severeConditionsFa;
  final List<Maker> makers;
  final List<Part> parts;
  final List<VehicleGroup> groups;

  final Map<String, Part> _partsById;
  final Map<String, Maker> _makersById;
  final Map<String, VehicleGroup> _groupsById;
  final Map<String, VehicleModel> _modelsById;

  Part? part(String id) => _partsById[id];
  Maker? maker(String id) => _makersById[id];
  VehicleModel? model(String id) => _modelsById[id];
  VehicleGroup? groupForModel(String modelId) {
    final model = _modelsById[modelId];
    return model == null ? null : _groupsById[model.groupId];
  }

  /// Every model of one maker, in catalog order.
  List<VehicleModel> modelsOfMaker(String makerId) => [
    for (final group in groups)
      if (group.makerId == makerId) ...group.models,
  ];

  static const supportedSchemaVersion = 1;

  /// Parses the catalog JSON. Throws [FormatException] for a schema version
  /// this build cannot read, so the app keeps its bundled copy instead.
  factory Catalog.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != supportedSchemaVersion) {
      throw FormatException('Unsupported catalog schema: $schemaVersion');
    }
    final rules = json['rules'] as Map<String, Object?>;
    final makers = [
      for (final raw in json['makers'] as List<Object?>)
        _makerFromJson(raw as Map<String, Object?>),
    ];
    final parts = [
      for (final raw in json['parts'] as List<Object?>)
        _partFromJson(raw as Map<String, Object?>),
    ];
    final groups = [
      for (final raw in json['vehicleGroups'] as List<Object?>)
        _groupFromJson(raw as Map<String, Object?>),
    ];
    return Catalog(
      catalogVersion: json['catalogVersion'] as String,
      severeConditionsFa: rules['severeConditionsFa'] as String,
      makers: makers,
      parts: parts,
      groups: groups,
    );
  }

  static Maker _makerFromJson(Map<String, Object?> json) => Maker(
    id: json['id'] as String,
    nameFa: json['nameFa'] as String,
    roadsidePhone: json['roadsidePhone'] as String,
  );

  static Part _partFromJson(Map<String, Object?> json) =>
      Part(id: json['id'] as String, nameFa: json['nameFa'] as String);

  static VehicleGroup _groupFromJson(Map<String, Object?> json) {
    final id = json['id'] as String;
    final confidence = Confidence.values.byName(json['confidence'] as String);
    return VehicleGroup(
      id: id,
      makerId: json['makerId'] as String,
      confidence: confidence,
      sourceFa: json['sourceFa'] as String,
      models: [
        for (final raw in json['models'] as List<Object?>)
          VehicleModel(
            id: (raw as Map<String, Object?>)['id'] as String,
            nameFa: raw['nameFa'] as String,
            groupId: id,
          ),
      ],
      items: [
        for (final raw in json['items'] as List<Object?>)
          _itemFromJson(raw as Map<String, Object?>, confidence),
      ],
    );
  }

  static MaintenanceItem _itemFromJson(
    Map<String, Object?> json,
    Confidence groupConfidence,
  ) {
    final ownConfidence = json['confidence'] as String?;
    return MaintenanceItem(
      partId: json['partId'] as String,
      action: MaintenanceAction.values.byName(json['action'] as String),
      confidence: ownConfidence == null
          ? groupConfidence
          : Confidence.values.byName(ownConfidence),
      normal: ServiceInterval.fromJson(json['normal']),
      severe: ServiceInterval.fromJson(json['severe']),
      noteFa: json['noteFa'] as String?,
    );
  }
}
