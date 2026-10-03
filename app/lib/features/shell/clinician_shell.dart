import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// Frame around the clinician workspace screens.
///
/// Clinicians only have one primary destination (the caseload). Material's
/// NavigationBar and NavigationRail both require ≥ 2 items and throw with one,
/// so narrow screens get no navigation chrome — the caseload AppBar carries
/// sign-out. Wide screens get a plain sidebar instead of a rail.
class ClinicianShell extends StatelessWidget {
  const ClinicianShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 840) return child;

    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 220,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.appName, style: t.titleMedium),
                    const SizedBox(height: Tokens.s24),
                    ListTile(
                      selected: true,
                      selectedTileColor: scheme.secondaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: const Icon(Icons.people_rounded),
                      title: Text(l.clinicianCaseload),
                      onTap: () => context.go('/clinic'),
                    ),
                    const Spacer(),
                    // TODO(core-team): wire to signOutWithConfirm from account_actions.dart.
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(l.signOut),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: Tokens.clinicianRail),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
