import 'dart:convert';
import 'dart:io';

import 'package:karyad/features/catalog/domain/catalog.dart';

/// The real bundled catalog, read from disk for tests.
Catalog loadCatalog() => Catalog.fromJson(
  jsonDecode(File('assets/catalog/maintenance-catalog.json').readAsStringSync())
      as Map<String, Object?>,
);
