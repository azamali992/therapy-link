import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/components/jugnu_nav_bar.dart';
import '../shared/widgets.dart';

/// Bottom-navigation (or side-rail on wide screens) shell for patient users.
///
/// Tab order: Eve (0) · Today (1) · Journal (2) · You (3).
/// Uses [JugnuNavBar] on narrow screens for the Jugnu design language.
class PatientShell extends StatelessWidget {
  const PatientShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final l = context.l10n;
    final labels = [l.tabEve, l.tabToday, l.tabJournal, l.tabYou];

    void go(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);

    if (wide) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 16),
              destinations: [
                for (var i = 0; i < 4; i++)
                  NavigationRailDestination(
                    icon: const Icon(Icons.circle_outlined),
                    label: Text(labels[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: shell,
      bottomNavigationBar: JugnuNavBar(
        currentIndex: shell.currentIndex,
        onTap: go,
      ),
    );
  }
}
