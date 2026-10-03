import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/locale.dart';
import '../../app/theme/tokens.dart';
import '../../core/db/database.dart';
import '../../core/settings/settings.dart';
import '../eve/memory.dart';
import '../shared/widgets.dart';

String memoryKindLabel(BuildContext context, String kind) => switch (kind) {
  'person' => context.l10n.memoryKindPerson,
  'situation' => context.l10n.memoryKindSituation,
  'goal' => context.l10n.memoryKindGoal,
  'helped' => context.l10n.memoryKindHelped,
  _ => context.l10n.memoryKindPlan,
};

/// Everything Eve carries between conversations, in the person's hands.
class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  Future<void> _forgetAll(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.memoryForgetAllTitle),
        content: Text(l.memoryForgetAllBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.memoryForgetAll)),
        ],
      ),
    );
    if (ok == true) await ref.read(databaseProvider).clearMemories();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final enabled = ref.watch(settingsProvider.select((s) => s.memoryEnabled));
    final memories = ref.watch(memoriesProvider);
    final df = DateFormat.MMMd(dateLocaleOf(context));

    return Screen(
      title: l.memoryTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.memoryIntro, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Tokens.s12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.memoryToggle),
            subtitle: Text(enabled ? l.memoryToggleOn : l.memoryToggleOff),
            value: enabled,
            onChanged: ref.read(settingsProvider.notifier).setMemoryEnabled,
          ),
          const Divider(),
          memories.when(
            loading: () => const SkeletonList(rows: 3),
            error: (_, _) => ErrorState(onRetry: () => ref.invalidate(memoriesProvider)),
            data: (rows) {
              if (rows.isEmpty) return EmptyState(title: l.memoryEmptyTitle, body: l.memoryEmptyBody);
              final byKind = <String, List<Memory>>{};
              for (final m in rows) {
                byKind.putIfAbsent(m.kind, () => []).add(m);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final kind in memoryKinds.where(byKind.containsKey)) ...[
                    SectionTitle(memoryKindLabel(context, kind)),
                    for (final m in byKind[kind]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Tokens.s4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: Tokens.s12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.content, style: t.bodyLarge),
                                    Text(df.format(m.createdAt), style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: l.memoryDelete,
                              onPressed: () => ref.read(databaseProvider).deleteMemory(m.id),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: Tokens.s24),
                  OutlinedButton.icon(
                    onPressed: () => _forgetAll(context, ref),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: Text(l.memoryForgetAll),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
