import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/features/catalog/domain/catalog.dart';

Map<String, Object?> _loadRaw() => jsonDecode(
  File('assets/catalog/maintenance-catalog.json').readAsStringSync(),
) as Map<String, Object?>;

void main() {
  group('bundled catalog', () {
    late Catalog catalog;

    setUpAll(() => catalog = Catalog.fromJson(_loadRaw()));

    test('parses with groups, models and parts', () {
      expect(catalog.groups, isNotEmpty);
      expect(catalog.parts, isNotEmpty);
      expect(catalog.model('quick')?.nameFa, 'کوییک');
    });

    test('every item points at a known part', () {
      for (final group in catalog.groups) {
        for (final item in group.items) {
          expect(
            catalog.part(item.partId),
            isNotNull,
            reason: '${group.id}/${item.partId}',
          );
        }
      }
    });

    test('every group points at a known maker with a roadside number', () {
      for (final group in catalog.groups) {
        expect(catalog.maker(group.makerId)?.roadsidePhone, isNotEmpty);
      }
    });

    test('finds the group of a model', () {
      expect(catalog.groupForModel('dena-plus')?.id, 'ikco-dena-family');
      expect(catalog.groupForModel('unknown'), isNull);
    });

    test('item confidence falls back to the group confidence', () {
      final shahin = catalog.groupForModel('shahin')!;
      final oil = shahin.items.firstWhere((i) => i.partId == 'engine_oil');
      final belt = shahin.items.firstWhere((i) => i.partId == 'timing_belt');
      expect(oil.confidence, Confidence.official);
      expect(belt.confidence, Confidence.unverified);
    });

    test('lists models by maker', () {
      final saipa = catalog.modelsOfMaker('saipa').map((m) => m.id);
      expect(saipa, containsAll(['quick', 'pride-131', 'shahin']));
      expect(saipa, isNot(contains('dena')));
    });
  });

  test('rejects an unsupported schema version', () {
    final raw = _loadRaw()..['schemaVersion'] = 99;
    expect(() => Catalog.fromJson(raw), throwsFormatException);
  });
}
