/// Patient shell — wraps the four tabs (Eve · Today · Journal · You).
///
/// On narrow screens: JugnuNavBar at the bottom over the ground gradient.
/// On wide screens (≥840 dp): Material NavigationRail on the left.
///
/// The ground gradient is painted at this shell level via DecoratedBox so every
/// tab screen (which uses a transparent Scaffold background) inherits it without
/// each screen needing its own JugnuScaffold.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../ui/components/jugnu_nav_bar.dart';

class PatientShell extends StatelessWidget {
  const PatientShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final wide = MediaQuery.sizeOf(context).width >= 840;

    void go(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);

    if (wide) {
      // Wide layout: side rail, no bottom bar.
      return DecoratedBox(
        decoration: BoxDecoration(gradient: colors.ground),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: go,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.transparent,
                leading: const SizedBox(height: Jugnu.s16),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.chat_bubble_outline_rounded),
                    selectedIcon: Icon(Icons.chat_bubble_rounded),
                    label: Text('Eve'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.wb_sunny_outlined),
                    selectedIcon: Icon(Icons.wb_sunny_rounded),
                    label: Text('Today'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book_rounded),
                    label: Text('Journal'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: Text('You'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: shell),
            ],
          ),
        ),
      );
    }

    // Narrow layout: JugnuNavBar + ground gradient.
    return DecoratedBox(
      decoration: BoxDecoration(gradient: colors.ground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: shell,
        bottomNavigationBar: JugnuNavBar(
          currentIndex: shell.currentIndex,
          onTap: go,
        ),
      ),
    );
  }
}
