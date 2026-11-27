import 'package:flutter_test/flutter_test.dart';
import 'package:karyad/app/app.dart';
import 'package:karyad/features/garage/application/garage_controller.dart';
import 'package:karyad/features/garage/data/garage_repository.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/catalog_fixture.dart';

void main() {
  testWidgets('onboarding leads to the home screen with due items', (
    tester,
  ) async {
    final controller = GarageController(
      repository: InMemoryGarageRepository(),
      catalog: loadCatalog(),
      clock: () => DateTime(2026, 11, 27),
    );
    await controller.load();
    await tester.pumpWidget(KaryadApp(controller: controller));
    await tester.pumpAndSettle();

    // Step 1: usage.
    expect(find.text('با ماشینت چه کار می‌کنی؟'), findsOneWidget);
    await tester.tap(find.text('ماشین شخصی'));
    await tester.pumpAndSettle();

    // Step 2: maker and model.
    await tester.tap(find.text('سایپا'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('کوییک'));
    await tester.pumpAndSettle();

    // Step 3: odometer, then start.
    await tester.enterText(find.byType(TextField), '۳۰٬۰۰۰');
    await tester.tap(find.text('شروع'));
    await tester.pumpAndSettle();

    expect(find.text('سرویس‌های پیش رو'), findsOneWidget);
    expect(find.text('روغن موتور و فیلتر روغن'), findsOneWidget);
    expect(controller.primaryVehicle?.trackingStart.km, 30000);
  });

  testWidgets('rejects onboarding without an odometer value', (tester) async {
    final controller = GarageController(
      repository: InMemoryGarageRepository(),
      catalog: loadCatalog(),
    );
    await controller.load();
    await tester.pumpWidget(KaryadApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('با ماشینم کار می‌کنم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دنا'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شروع'));
    await tester.pumpAndSettle();

    expect(find.text('کیلومتر فعلی ماشین را وارد کنید'), findsOneWidget);
    expect(controller.isOnboarded, isFalse);
  });
}
