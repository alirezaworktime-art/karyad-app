import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/catalog/data/catalog_repository.dart';
import 'features/garage/application/garage_controller.dart';
import 'features/garage/data/garage_repository.dart';
import 'features/reminders/application/reminder_planner.dart';
import 'features/reminders/data/local_notification_scheduler.dart';

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
  ReminderSync(garage: controller, scheduler: await _scheduler()).start();
}

/// Phone notifications on Android; browsers can't schedule them.
Future<ReminderScheduler> _scheduler() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const NoopReminderScheduler();
  }
  try {
    return await LocalNotificationScheduler.create();
  } on Object {
    return const NoopReminderScheduler();
  }
}
