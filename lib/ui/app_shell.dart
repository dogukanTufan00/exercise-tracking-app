import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'exercises/exercises_screen.dart';
import 'history/history_screen.dart';
import 'profile/profile_screen.dart';

/// Uygulamanın kökü: alt gezinme çubuğu ve üç sekme (Antrenmanlar, Hareketler, Profil).
///
/// Her sekmenin kendi [Navigator]'ı vardır; sekme değişince ekran ve kaydırma konumu korunur.
/// Antrenman ve Ayarlar gibi tam ekran sayfalar kök navigator'da açılır ve çubuğun üstünü kaplar.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Sekme kökleri; sırası [NavigationBar] hedefleriyle aynıdır.
  static const List<Widget> _tabRoots = [
    HistoryScreen(),
    ExercisesScreen(),
    ProfileScreen(),
  ];

  /// Her sekmenin navigator'ına ayrı anahtarla erişilir (geri tuşu ve köke dönüş için).
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  int _selectedIndex = 0;

  /// Aktif sekmeyi seçer; aynı sekmeye tekrar dokunulursa o sekmenin yığını köke döner.
  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  /// Geri tuşu: önce aktif sekmenin yığını, sonra sekme 0'a dönüş, en son uygulamayı kapatma.
  Future<void> _handleBack() async {
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    if (navigator != null && await navigator.maybePop()) return;

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
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
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.fitness_center),
              label: 'Antrenmanlar',
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
    );
  }
}
