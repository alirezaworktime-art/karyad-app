import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/catalog.dart';

/// Supplies the maintenance catalog. Today it reads the copy bundled with
/// the app, which always works offline; a later version also checks the
/// backend for a newer copy and keeps whichever is newer.
class CatalogRepository {
  CatalogRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const bundledAsset = 'assets/catalog/maintenance-catalog.json';

  final AssetBundle _bundle;
  Catalog? _cached;

  Future<Catalog> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(bundledAsset);
    final catalog = Catalog.fromJson(jsonDecode(raw) as Map<String, Object?>);
    _cached = catalog;
    return catalog;
  }
}
