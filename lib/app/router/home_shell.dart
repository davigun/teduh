import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/tokens/app_colors.dart';

/// The persistent 4-tab shell (Beranda / Alkitab / Bersama / Pengaturan).
/// Native manners: a CupertinoTabBar on iOS, a Material NavigationBar on
/// Android — both in Teduh's palette. Reader/plan push above this shell.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _labels = ['Beranda', 'Alkitab', 'Bersama', 'Pengaturan'];
  static const _material = [
    (Icons.home_outlined, Icons.home),
    (Icons.menu_book_outlined, Icons.menu_book),
    (Icons.people_outline, Icons.people),
    (Icons.settings_outlined, Icons.settings),
  ];
  static const _cupertino = [
    CupertinoIcons.house,
    CupertinoIcons.book,
    CupertinoIcons.person_2,
    CupertinoIcons.settings,
  ];

  void _go(int i) =>
      navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: CupertinoTabBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _go,
          // HIG: ~50pt bar with ~25pt tab icons. Flutter's default 30pt icon
          // crowds the top of the fixed-height bar, so bring it to spec.
          iconSize: 25,
          height: 50,
          backgroundColor: c.surface.withValues(alpha: 0.94),
          activeColor: c.accent,
          inactiveColor: c.muted,
          border: Border(top: BorderSide(color: c.hairline, width: 0.5)),
          items: [
            for (var i = 0; i < _labels.length; i++)
              BottomNavigationBarItem(
                  icon: Icon(_cupertino[i]), label: _labels[i]),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(
              icon: Icon(_material[i].$1),
              selectedIcon: Icon(_material[i].$2),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}
