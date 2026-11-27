/// Body shape of a model, used to pick the car illustration. Kept apart
/// from the maintenance catalog because it is display information only.
enum BodyType { sedan, hatchback, suv, pickup }

abstract final class BodyTypes {
  static const _byModel = <String, BodyType>{
    '206-tip2': BodyType.hatchback,
    '206-tip5': BodyType.hatchback,
    '207': BodyType.hatchback,
    'quick': BodyType.hatchback,
    'atlas': BodyType.hatchback,
    'haima-s5': BodyType.suv,
    'haima-s7': BodyType.suv,
    'rira': BodyType.suv,
    '2008': BodyType.suv,
    'padra-plus': BodyType.pickup,
    'z24': BodyType.pickup,
    'arisan': BodyType.pickup,
    'pride-151': BodyType.pickup,
  };

  /// Sedan unless listed otherwise; most Iranian models are sedans.
  static BodyType of(String modelId) => _byModel[modelId] ?? BodyType.sedan;
}
