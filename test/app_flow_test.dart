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

    expect(find.text('سرویس ماشینت دیگر یادت نمی‌رود'), findsOneWidget);
    await _tap(tester, find.text('شروع کنیم'));

    await _pickModel(tester, 'دنا', 'دنا پلاس');

    await tester.enterText(find.byKey(const Key('current-km')), '۶۲٬۴۰۰');
    await tester.enterText(find.byKey(const Key('sticker-km')), '72000');
    await _tap(tester, find.bySemanticsLabel('نقره‌ای'));
    await _tap(tester, find.text('تمام'));

    expect(find.text('سرویس بعدی'), findsOneWidget);
    expect(find.text('۷۲٬۰۰۰'), findsOneWidget);
    expect(find.text('سرویس را انجام دادم'), findsOneWidget);
    expect(controller.primaryVehicle!.color, CarColor.silver);
  });

  testWidgets('validates the odometer and the sticker', (tester) async {
    final controller = await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, 'پراید', 'پراید ۱۳۱');
    await _tap(tester, find.text('تمام'));

    expect(find.text('عدد کیلومترشمار را بنویس'), findsOneWidget);
    expect(
      find.text('عدد برچسب را بنویس یا «برچسب ندارم» را بزن'),
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
    await _tap(tester, find.text('تمام'));

    // 405 oil every 10,000 km → next milestone after 183,500 is 190,000.
    expect(find.text('۱۹۰٬۰۰۰'), findsOneWidget);
  });

  testWidgets('logging a visit moves the next service and fills history', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('شروع کنیم'));
    await _pickModel(tester, 'کوییک', 'کوییک');
    await tester.enterText(find.byKey(const Key('current-km')), '30000');
    await _tap(tester, find.text('برچسب ندارم'));
    await _tap(tester, find.text('تمام'));

    await _tap(tester, find.text('سرویس را انجام دادم'));
    await tester.enterText(find.byKey(const Key('visit-km')), '30000');
    await _tap(tester, find.text('ذخیره'));

    // Quick oil every 5,000 km from the logged 30,000.
    expect(find.text('۳۵٬۰۰۰'), findsOneWidget);

    await _tap(tester, find.text('سوابق'));
    expect(find.text('۳۰٬۰۰۰ کیلومتر'), findsOneWidget);
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
      find.text('این مدل هنوز در فهرست نیست. به‌زودی اضافه می‌شود.'),
      findsOneWidget,
    );
  });
}
