import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/app/app.dart';
import 'package:karyad/features/garage/application/garage_controller.dart';
import 'package:karyad/features/garage/data/garage_repository.dart';
import 'package:karyad/features/garage/domain/vehicle.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/catalog_fixture.dart';

Future<GarageController> _pumpApp(WidgetTester tester) async {
  // A phone-width, extra-tall screen so whole screens are laid out at once.
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(400 * 3, 1800 * 3);
  addTearDown(tester.view.reset);

  final controller = GarageController(
    repository: InMemoryGarageRepository(),
    catalog: loadCatalog(),
    clock: () => DateTime(2026, 11, 27),
  );
  await controller.load();
  await tester.pumpWidget(KaryadApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Leaves the details step and skips the optional history step.
Future<void> _continueAndSkipHistory(WidgetTester tester) async {
  await _tap(tester, find.text('ادامه'));
  await _tap(tester, find.text('هیچ‌کدوم یادم نیست، رد شو'));
}

Future<void> _pickModel(WidgetTester tester, String search, String name) async {
  await tester.enterText(find.byKey(const Key('model-search')), search);
  await tester.pumpAndSettle();
  await _tap(tester, find.widgetWithText(ListTile, name));
}

void main() {
  testWidgets('welcome → model → sticker → home shows the sticker km', (
    tester,
  ) async {
    final controller = await _pumpApp(tester);

    expect(find.text('دیگه سرویس ماشینت یادت نمی‌ره'), findsOneWidget);
    await _tap(tester, find.text('شروع کنیم'));

    await _pickModel(tester, 'دنا', 'دنا پلاس');

    await tester.enterText(find.byKey(const Key('current-km')), '۶۲٬۴۰۰');
    await tester.enterText(find.byKey(const Key('sticker-km')), '72000');
    await _tap(tester, find.bySemanticsLabel('نقره‌ای'));
    await _continueAndSkipHistory(tester);

    expect(find.text('سرویس بعدی'), findsOneWidget);
    expect(find.textContaining('۷۲٬۰۰۰', findRichText: true), findsWidgets);
    expect(find.text('سرویس رو انجام دادم'), findsOneWidget);
    expect(controller.activeVehicle!.color, CarColor.silver);
  });

  testWidgets('validates the odometer and the sticker', (tester) async {
    final controller = await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, 'پراید', 'پراید ۱۳۱');
    await _tap(tester, find.text('ادامه'));

    expect(find.text('عدد کیلومترشمار رو بنویس'), findsOneWidget);
    expect(
      find.text('عدد برچسب رو بنویس یا «برچسب ندارم» رو بزن'),
      findsOneWidget,
    );
    expect(controller.isOnboarded, isFalse);
  });

  testWidgets('no sticker: oil follows the factory milestone', (tester) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, '405', 'پژو ۴۰۵');
    await tester.enterText(find.byKey(const Key('current-km')), '183500');
    await _tap(tester, find.text('برچسب ندارم'));
    await _continueAndSkipHistory(tester);

    // 405 oil every 10,000 km → next milestone after 183,500 is 190,000.
    expect(find.textContaining('۱۹۰٬۰۰۰', findRichText: true), findsWidgets);
  });

  testWidgets('remembered replacements move their targets', (tester) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, 'دنا', 'دنا پلاس');
    await tester.enterText(find.byKey(const Key('current-km')), '62400');
    await tester.enterText(find.byKey(const Key('sticker-km')), '72000');
    expect(find.widgetWithText(ChoiceChip, 'اتوماتیک'), findsOneWidget);
    await _tap(tester, find.text('ادامه'));

    expect(find.text('آخرین بار کِی عوضشون کردی؟'), findsOneWidget);
    // Manual is the default gearbox, so the automatic-gearbox oil is gone.
    expect(find.byKey(const Key('last-automatic_gearbox_oil')), findsNothing);
    await tester.enterText(find.byKey(const Key('last-air_filter')), '70000');
    await _tap(tester, find.text('تموم'));
    expect(find.textContaining('از کیلومترشمار'), findsOneWidget);

    // Air filter every 10,000 km from 61,000 → 71,000, ahead of the oil.
    await tester.enterText(find.byKey(const Key('last-air_filter')), '۶۱۰۰۰');
    await _tap(tester, find.text('تموم'));
    expect(find.text('سرویس بعدی'), findsOneWidget);
    expect(find.textContaining('۷۱٬۰۰۰', findRichText: true), findsWidgets);
  });

  testWidgets('logging a visit moves the next service and fills history', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, 'کوییک', 'کوییک');
    await tester.enterText(find.byKey(const Key('current-km')), '30000');
    await _tap(tester, find.text('برچسب ندارم'));
    await _continueAndSkipHistory(tester);

    await _tap(tester, find.text('سرویس رو انجام دادم'));
    await tester.enterText(find.byKey(const Key('visit-km')), '30000');
    await _tap(tester, find.text('ذخیره'));

    // Quick oil every 5,000 km from the logged 30,000.
    expect(find.textContaining('۳۵٬۰۰۰', findRichText: true), findsWidgets);

    await _tap(tester, find.text('سوابق'));
    expect(find.text('۳۰٬۰۰۰ کیلومتر'), findsOneWidget);
  });

  testWidgets('a new oil sticker sets the next change and its interval', (
    tester,
  ) async {
    final controller = await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, 'کوییک', 'کوییک');
    await tester.enterText(find.byKey(const Key('current-km')), '30000');
    await _tap(tester, find.text('برچسب ندارم'));
    await _continueAndSkipHistory(tester);

    await _tap(tester, find.text('سرویس رو انجام دادم'));
    await tester.enterText(find.byKey(const Key('visit-km')), '30000');
    await tester.enterText(find.byKey(const Key('visit-sticker')), '36000');
    await _tap(tester, find.text('ذخیره'));

    expect(find.textContaining('۳۶٬۰۰۰', findRichText: true), findsWidgets);
    expect(controller.activeVehicle!.oilIntervalKm, 6000);
  });

  testWidgets('settings: own oil interval and insurance reminder', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, 'دنا', 'دنا پلاس');
    await tester.enterText(find.byKey(const Key('current-km')), '62400');
    await tester.enterText(find.byKey(const Key('sticker-km')), '72000');
    await _continueAndSkipHistory(tester);

    await _tap(tester, find.text('تنظیمات'));
    await _tap(tester, find.byKey(const Key('custom-oil-switch')));
    await tester.enterText(find.byKey(const Key('oil-interval')), '600');
    await _tap(tester, find.text('ثبت'));
    expect(find.textContaining('عددی بین'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('oil-interval')), '۶۰۰۰');
    await _tap(tester, find.text('ثبت'));
    expect(find.text('هر ۶٬۰۰۰ کیلومتر'), findsOneWidget);

    // The sticker already in the car stays the target; the new interval
    // applies from the next oil change.
    await _tap(tester, find.byKey(const Key('document-insurance')));
    await _tap(tester, find.text('ثبت'));

    await _tap(tester, find.text('خانه'));
    expect(find.textContaining('۷۲٬۰۰۰', findRichText: true), findsWidgets);
    expect(find.text('بیمه‌ی شخص ثالث امروز تمام می‌شود'), findsOneWidget);
  });

  testWidgets('adding a second car and switching between them', (
    tester,
  ) async {
    final controller = await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, 'کوییک', 'کوییک');
    await tester.enterText(find.byKey(const Key('current-km')), '30000');
    await _tap(tester, find.text('برچسب ندارم'));
    await _continueAndSkipHistory(tester);

    // With one car the header button adds a car straight away; the add
    // flow skips the welcome screen.
    await _tap(tester, find.byKey(const Key('vehicle-switcher')));
    expect(find.text('ماشینت چیه؟'), findsOneWidget);
    await _pickModel(tester, 'دنا', 'دنا پلاس');
    await tester.enterText(find.byKey(const Key('current-km')), '120000');
    await _tap(tester, find.text('برچسب ندارم'));
    await _continueAndSkipHistory(tester);

    expect(controller.vehicles, hasLength(2));
    expect(find.text('سرویس بعدی'), findsOneWidget);
    expect(find.textContaining('دنا پلاس · ۲ ماشین'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('vehicle-switcher')));
    expect(find.text('ماشین‌هات'), findsOneWidget);
    await _tap(tester, find.text('کوییک'));
    expect(controller.activeVehicle!.modelId, 'quick');
    expect(find.textContaining('کوییک · ۲ ماشین'), findsOneWidget);

    // Removing one car from settings keeps the other.
    await _tap(tester, find.text('تنظیمات'));
    await _tap(tester, find.byKey(const Key('remove-vehicle')));
    await _tap(tester, find.text('پاک کن'));
    expect(controller.vehicles.single.modelId, 'dena-plus');
  });

  testWidgets('model search folds Arabic letters and handles no results', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));

    await tester.enterText(find.byKey(const Key('model-search')), 'كوييك');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'کوییک'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('model-search')), 'تسلا');
    await tester.pumpAndSettle();
    expect(
      find.text('این مدل هنوز تو فهرست نیست. به‌زودی اضافه‌ش می‌کنیم.'),
      findsOneWidget,
    );
  });
}
