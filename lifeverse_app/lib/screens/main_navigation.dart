import 'package:flutter/material.dart';
import '../theme/lifeverse_theme.dart';
import 'home_dashboard.dart';
import 'progress_screen.dart';
import 'hde_dashboard.dart';
import 'reflect_hub_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _profileRefreshToken = 0;
  final List<Widget?> _pages = [const HomeDashboard(), null, null, null, null];

  static const _destinations = [
    _Destination('Home', Icons.home_outlined, Icons.home),
    _Destination('Progress', Icons.insights_outlined, Icons.insights),
    _Destination('Evolution', Icons.auto_awesome_outlined, Icons.auto_awesome),
    _Destination('Reflect', Icons.forum_outlined, Icons.forum),
    _Destination('Profile', Icons.person_outline, Icons.person),
  ];

  Widget _page(int index) => _pages[index] ??= switch (index) {
    0 => const HomeDashboard(),
    1 => const ProgressScreen(),
    2 => const HDEDashboard(showBackButton: false),
    3 => const ReflectHubScreen(),
    _ => ProfileScreen(
      showBackButton: false,
      refreshToken: _profileRefreshToken,
    ),
  };

  void _select(int index) => setState(() {
    _currentIndex = index;
    if (index == 4) {
      _profileRefreshToken += 1;
      _pages[index] = ProfileScreen(
        showBackButton: false,
        refreshToken: _profileRefreshToken,
      );
    } else {
      _page(index);
    }
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      return Scaffold(
        backgroundColor: LifeVerseColors.canvas,
        body: Row(children: [
          if (wide)
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              backgroundColor: LifeVerseColors.surface,
              indicatorColor: LifeVerseColors.primary.withValues(alpha: .15),
              selectedIconTheme: const IconThemeData(color: LifeVerseColors.primary),
              unselectedIconTheme: const IconThemeData(color: LifeVerseColors.muted),
              selectedLabelTextStyle: const TextStyle(color: LifeVerseColors.primary, fontWeight: FontWeight.w700),
              unselectedLabelTextStyle: const TextStyle(color: LifeVerseColors.muted),
              leading: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Icon(Icons.all_inclusive, color: LifeVerseColors.primary, size: 28)),
              destinations: _destinations.map((d) => NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label))).toList(),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: SizedBox.expand(
                  child: IndexedStack(index: _currentIndex, children: List.generate(5, (i) => _pages[i] ?? const SizedBox.shrink())),
                ),
              ),
            ),
          ),
        ]),
        bottomNavigationBar: wide ? null : NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _select,
          backgroundColor: LifeVerseColors.surface,
          indicatorColor: LifeVerseColors.primary.withValues(alpha: .15),
          destinations: _destinations.map((d) => NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label)).toList(),
        ),
      );
    });
  }
}

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Destination(this.label, this.icon, this.selectedIcon);
}
