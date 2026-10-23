import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tab.dart';
import 'exercises/exercises_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';
import 'program/program_screen.dart';

/// Uygulamanın kökü: alt gezinme çubuğu ve dört sekme (Antrenmanlar, Program, Hareketler, Profil).
///
/// Her sekmenin kendi [Navigator]'ı vardır; sekme değişince ekran ve kaydırma konumu korunur.
/// Antrenman ve Ayarlar gibi tam ekran sayfalar kök navigator'da açılır ve çubuğun üstünü kaplar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Sekme kökleri; sırası [AppTab] ve [NavigationBar] hedefleriyle aynıdır.
  static const List<Widget> _tabRoots = [
    HistoryScreen(),
    ProgramScreen(),
    ExercisesScreen(),
    ProfileScreen(),
  ];

  /// Her sekmenin navigator'ına ayrı anahtarla erişilir (geri tuşu ve köke dönüş için).
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final AppTabNotifier _tab = AppTabNotifier(AppTab.workouts);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// Aktif sekmeyi seçer; aynı sekmeye tekrar dokunulursa o sekmenin yığını köke döner.
  void _onDestinationSelected(int index) {
    final tab = AppTab.values[index];
    if (tab == _tab.value) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
    _tab.select(tab);
  }

  /// Geri tuşu: önce aktif sekmenin yığını, sonra sekme 0'a dönüş, en son uygulamayı kapatma.
  Future<void> _handleBack() async {
    final navigator = _navigatorKeys[_tab.value.index].currentState;
    if (navigator != null && await navigator.maybePop()) return;

    if (_tab.value != AppTab.workouts) {
      _tab.select(AppTab.workouts);
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppTabScope(
      notifier: _tab,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBack();
        },
        child: ValueListenableBuilder<AppTab>(
          valueListenable: _tab,
          builder: (context, selectedTab, _) => Scaffold(
            body: IndexedStack(
              index: selectedTab.index,
              children: [
                for (var i = 0; i < _tabRoots.length; i++)
                  Navigator(
                    key: _navigatorKeys[i],
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => _tabRoots[i],
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedTab.index,
              onDestinationSelected: _onDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.fitness_center),
                  label: 'Antrenmanlar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note),
                  label: 'Program',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Hareketler',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
