import 'package:flutter/material.dart';

import '../shared/widgets.dart';

/// /you/memory — view and delete Eve's memory notes.
///
/// TODO(core-team): wire to the drift database (memory_notes table).
class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.memoryTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.memoryIntro,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Card(
            child: SwitchListTile(
              title: Text(l.memoryToggle),
              subtitle: Text(l.memoryToggleOn),
              value: true,
              onChanged: (_) {
                // TODO(core-team): toggle memory in settings.
              },
            ),
          ),
          const SizedBox(height: 16),
          EmptyState(
            title: l.memoryEmptyTitle,
            body: l.memoryEmptyBody,
          ),
        ],
      ),
    );
  }
}
