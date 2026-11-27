import 'package:material_ui/material_ui.dart';

import '../features/garage/application/garage_controller.dart';
import '../features/garage/presentation/home_shell.dart';
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
      // One clear light theme for now; a matching dark theme comes later.
      themeMode: ThemeMode.light,
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
              ? HomeShell(controller: controller)
              : OnboardingScreen(controller: controller);
        },
      ),
    );
  }
}
