import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets.dart';

/// /journal — journal entry list.
///
/// TODO(core-team): wire to the drift database for encrypted journal entries.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.journalTitle,
      fab: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(l.journalNew),
        onPressed: () => context.go('/journal/new'),
      ),
      child: EmptyState(
        title: l.journalEmptyTitle,
        body: l.journalEmptyBody,
        action: FilledButton.icon(
          icon: const Icon(Icons.add_rounded),
          label: Text(l.journalNew),
          onPressed: () => context.go('/journal/new'),
        ),
      ),
    );
  }
}
