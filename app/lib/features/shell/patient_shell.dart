import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// Bottom-navigation (or side-rail on wide screens) shell for patient users.
///
/// Tab order matches the v16 spec: Eve · Today · Journal · You.
class PatientShell extends StatelessWidget {
  const PatientShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // The four tabs in display order.
  static const _tabs = [
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'tabEve'),
    (Icons.wb_sunny_outlined, Icons.wb_sunny_rounded, 'tabToday'),
    (Icons.edit_note_outlined, Icons.edit_note_rounded, 'tabJournal'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'tabYou'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= 840;

    // Map enum-key strings to localised labels.
    final labels = [l.tabEve, l.tabToday, l.tabJournal, l.tabYou];

    void go(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: Tokens.s16),
              destinations: [
                for (var i = 0; i < _tabs.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_tabs[i].$1),
                    selectedIcon: Icon(_tabs[i].$2),
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
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: go,
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: Icon(_tabs[i].$1),
              selectedIcon: Icon(_tabs[i].$2),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}
