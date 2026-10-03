import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/locale.dart';
import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../ui/components/inline_note.dart';
import '../../ui/components/slab.dart';
import '../shared/widgets.dart';

final accessLogProvider = FutureProvider<List<AccessLogEntry>>(
    (ref) => ref.watch(apiClientProvider).accessLog());

/// Every time a linked clinician was shown this person's data, and what
/// they were shown.
class AccessLogScreen extends ConsumerWidget {
  const AccessLogScreen({super.key});

  String _section(BuildContext context, String s) => switch (s) {
    'assessments' => context.l10n.clinicianAssessments,
    'mood_trend' => context.l10n.clinicianMood,
    'summaries' => context.l10n.clinicianSummaries,
    'journal' => context.l10n.clinicianJournal,
    _ => s,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final when = DateFormat.yMMMd(dateLocaleOf(context)).add_jm();

    return Screen(
      title: l.accessLogTitle,
      child: ref.watch(accessLogProvider).when(
        loading: () => const SkeletonList(rows: 4),
        error: (_, _) => ErrorState(
            onRetry: () => ref.invalidate(accessLogProvider)),
        data: (rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Tokens.s8),
            InlineNote(text: l.accessLogIntro),
            const SizedBox(height: Tokens.s16),
            if (rows.isEmpty)
              EmptyState(
                  title: l.accessLogTitle, body: l.accessLogEmpty),
            for (final e in rows) ...[
              Slab(
                padding: const EdgeInsets.all(Tokens.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            e.clinicianName ?? l.accessLogSomeone,
                            style: t.titleMedium,
                          ),
                        ),
                        const SizedBox(width: Tokens.s8),
                        Text(
                          when.format(e.at),
                          style: t.bodySmall
                              ?.copyWith(color: colors.ink2),
                        ),
                      ],
                    ),
                    const SizedBox(height: Tokens.s4),
                    Text(
                      e.action == 'caseload'
                          ? l.accessLogCaseload
                          : l.accessLogOverview,
                      style: t.bodyMedium,
                    ),
                    if (e.sections.isNotEmpty) ...[
                      const SizedBox(height: Tokens.s4),
                      Text(
                        e.sections
                            .map((s) => _section(context, s))
                            .join(' · '),
                        style: t.bodySmall
                            ?.copyWith(color: colors.ink2),
                      ),
                    ] else ...[
                      const SizedBox(height: Tokens.s4),
                      Text(
                        l.accessLogNothingShown,
                        style: t.bodySmall
                            ?.copyWith(color: colors.ink3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Tokens.s8),
            ],
          ],
        ),
      ),
    );
  }
}
