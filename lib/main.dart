import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/catalog/data/catalog_repository.dart';
import 'features/garage/application/garage_controller.dart';
import 'features/garage/data/garage_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalog = await CatalogRepository().load();
  final prefs = await SharedPreferences.getInstance();
  final controller = GarageController(
    repository: PreferencesGarageRepository(prefs),
    catalog: catalog,
  );
  runApp(KaryadApp(controller: controller));
  await controller.load();
}
