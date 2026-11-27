import 'package:material_ui/material_ui.dart';

import '../application/garage_controller.dart';
import 'car_tab.dart';
import 'history_tab.dart';
import 'home_tab.dart';

/// Bottom navigation: home, history, car.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final GarageController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            HomeTab(controller: controller),
            HistoryTab(controller: controller),
            CarTab(controller: controller),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'سوابق',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'ماشین',
          ),
        ],
      ),
    );
  }
}
