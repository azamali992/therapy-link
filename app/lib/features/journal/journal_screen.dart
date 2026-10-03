import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/locale.dart';
import '../../app/theme/tokens.dart';
import '../../core/api/models.dart';
import '../shared/widgets.dart';
import 'journal_providers.dart';

/// /journal — journal entry list.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final entries = ref.watch(journalProvider);

    return Screen(
      title: l.journalTitle,
      fab: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(l.journalNew),
        onPressed: () => context.go('/journal/new'),
      ),
      child: entries.when(
        loading: () => const SkeletonList(rows: 4),
        error: (_, _) => ErrorState(onRetry: () => ref.invalidate(journalProvider)),
        data: (rows) => rows.isEmpty
            ? EmptyState(
                title: l.journalEmptyTitle,
                body: l.journalEmptyBody,
                action: FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.journalNew),
                  onPressed: () => context.go('/journal/new'),
                ),
              )
            : _EntryList(rows: rows),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.rows});

  final List<JournalEntry> rows;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd(dateLocaleOf(context));
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final e in rows) ...[
          InkWell(
            onTap: () => context.go('/journal/${e.id}'),
            borderRadius: BorderRadius.circular(Tokens.rSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.title?.isNotEmpty == true ? e.title! : e.body.split('\n').first,
                          style: t.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Tokens.s8),
                      Text(df.format(e.createdAt), style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  if (e.body.isNotEmpty) ...[
                    const SizedBox(height: Tokens.s4),
                    Text(e.body, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}
