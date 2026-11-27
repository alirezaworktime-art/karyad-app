import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../features/garage/application/garage_controller.dart';
import '../features/garage/presentation/home_screen.dart';
import '../features/garage/presentation/onboarding_screen.dart';
import 'theme.dart';

class KaryadApp extends StatelessWidget {
  const KaryadApp({super.key, required this.controller});

  final GarageController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'کاریاد',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (!controller.isLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return controller.isOnboarded
              ? HomeScreen(controller: controller)
              : OnboardingScreen(controller: controller);
        },
      ),
    );
  }
}
