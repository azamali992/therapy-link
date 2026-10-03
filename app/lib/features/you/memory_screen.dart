import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/locale.dart';
import '../../app/theme/tokens.dart';
import '../../core/db/database.dart';
import '../../core/settings/settings.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/inline_note.dart';
import '../../ui/components/setting_row.dart';
import '../../ui/components/slab.dart';
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
      builder: (ctx) => AlertDialog(
        title: Text(l.memoryForgetAllTitle),
        content: Text(l.memoryForgetAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, Tokens.s48)),
            child: Text(l.memoryForgetAll),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(databaseProvider).clearMemories();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final enabled =
        ref.watch(settingsProvider.select((s) => s.memoryEnabled));
    final memories = ref.watch(memoriesProvider);
    final df = DateFormat.MMMd(dateLocaleOf(context));

    return Screen(
      title: l.memoryTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Eve's memory stays on-device: surface-level notice.
          InlineNote(text: l.memoryIntro, isProtected: true),
          const SizedBox(height: Tokens.s16),
          SettingRow(
            title: l.memoryToggle,
            subtitle: enabled ? l.memoryToggleOn : l.memoryToggleOff,
            value: enabled,
            onChanged:
                ref.read(settingsProvider.notifier).setMemoryEnabled,
            icon: Icons.psychology_outlined,
          ),
          Divider(height: 1, color: colors.hair),
          const SizedBox(height: Tokens.s16),
          memories.when(
            loading: () => const SkeletonList(rows: 3),
            error: (_, _) => ErrorState(
                onRetry: () => ref.invalidate(memoriesProvider)),
            data: (rows) {
              if (rows.isEmpty) {
                return EmptyState(
                  title: l.memoryEmptyTitle,
                  body: l.memoryEmptyBody,
                );
              }
              final byKind = <String, List<Memory>>{};
              for (final m in rows) {
                byKind.putIfAbsent(m.kind, () => []).add(m);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final kind
                      in memoryKinds.where(byKind.containsKey)) ...[
                    SectionTitle(memoryKindLabel(context, kind)),
                    Slab(
                      padding: const EdgeInsets.all(Tokens.s12),
                      child: Column(
                        children: [
                          for (final m in byKind[kind]!) ...[
                            _MemoryRow(
                              memory: m,
                              dateLabel: df.format(m.createdAt),
                              colors: colors,
                              t: t,
                              onDelete: () => ref
                                  .read(databaseProvider)
                                  .deleteMemory(m.id),
                            ),
                            if (m != byKind[kind]!.last)
                              Divider(height: 1, color: colors.hair),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: Tokens.s24),
                  GhostButton(
                    label: l.memoryForgetAll,
                    onPressed: () => _forgetAll(context, ref),
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

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({
    required this.memory,
    required this.dateLabel,
    required this.colors,
    required this.t,
    required this.onDelete,
  });

  final Memory memory;
  final String dateLabel;
  final JugnuColors colors;
  final TextTheme t;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(memory.content, style: t.bodyLarge),
                const SizedBox(height: 2),
                Text(dateLabel,
                    style:
                        t.labelSmall?.copyWith(color: colors.ink2)),
              ],
            ),
          ),
          SizedBox(
            width: Tokens.s48,
            height: Tokens.s48,
            child: IconButton(
              tooltip: context.l10n.memoryDelete,
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
