import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/app/app.dart';
import 'package:karyad/features/garage/application/garage_controller.dart';
import 'package:karyad/features/garage/data/garage_repository.dart';
import 'package:karyad/features/garage/domain/maintenance_planner.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/catalog_fixture.dart';

Future<GarageController> _pumpApp(WidgetTester tester) async {
  // A phone-width, extra-tall screen so whole forms are laid out at once.
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(400 * 3, 1600 * 3);
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

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding with a remembered oil change reaches home', (
    tester,
  ) async {
    final controller = await _pumpApp(tester);

    expect(find.text('با ماشینت چه کار می‌کنی؟'), findsOneWidget);
    await _tapText(tester, 'ماشین شخصی');

    await tester.enterText(find.byKey(const Key('model-search')), 'کوییک');
    await tester.pumpAndSettle();
    await _tapText(tester, 'کوییک');

    await tester.enterText(find.byKey(const Key('current-km')), '۳۰٬۰۰۰');
    await tester.enterText(find.byKey(const Key('last-oil-km')), '28000');
    await _tapText(tester, 'شروع');

    expect(find.text('سرویس بعدی'), findsOneWidget);
    expect(find.text('روغن موتور و فیلتر روغن'), findsWidgets);
    expect(find.text('آخرین بار کی انجام شد؟'), findsOneWidget);

    final oil = controller
        .duesFor(controller.primaryVehicle!)
        .firstWhere((d) => d.item.partId == 'engine_oil');
    expect(oil.lastDoneKm, 28000);
    expect(oil.status, DueStatus.ok);
  });

  testWidgets('validates odometer and oil answers before starting', (
    tester,
  ) async {
    final controller = await _pumpApp(tester);

    await _tapText(tester, 'با ماشینم کار می‌کنم');
    await tester.enterText(find.byKey(const Key('model-search')), 'دنا');
    await tester.pumpAndSettle();
    await _tapText(tester, 'دنا');
    await _tapText(tester, 'شروع');

    expect(find.text('کیلومتر فعلی ماشین را وارد کنید'), findsOneWidget);
    expect(
      find.text('کیلومتر آخرین تعویض را بنویس یا «یادم نیست» را بزن'),
      findsOneWidget,
    );
    expect(controller.isOnboarded, isFalse);
  });

  testWidgets('"I don\'t remember" lets onboarding finish without oil km', (
    tester,
  ) async {
    final controller = await _pumpApp(tester);

    await _tapText(tester, 'ماشین شخصی');
    await tester.enterText(find.byKey(const Key('model-search')), 'پراید');
    await tester.pumpAndSettle();
    await _tapText(tester, 'پراید ۱۳۱');
    await tester.enterText(find.byKey(const Key('current-km')), '150000');
    await _tapText(tester, 'یادم نیست');
    await _tapText(tester, 'شروع');

    expect(controller.isOnboarded, isTrue);
    expect(find.text('آخرین بار کی انجام شد؟'), findsOneWidget);
  });

  testWidgets('model search folds Arabic letters and handles no results', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _tapText(tester, 'ماشین شخصی');

    // Arabic kaf (ك) and yeh (ي) still find «کوییک».
    await tester.enterText(find.byKey(const Key('model-search')), 'كوييك');
    await tester.pumpAndSettle();
    expect(find.text('کوییک'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('model-search')), 'تسلا');
    await tester.pumpAndSettle();
    expect(
      find.text('این مدل هنوز در فهرست نیست. به‌زودی اضافه می‌شود.'),
      findsOneWidget,
    );
  });
}
