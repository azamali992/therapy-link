import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/locale.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/theme.dart' show jugnuTimestamp;
import '../../core/api/models.dart';
import '../../ui/components/inline_note.dart';
import '../../ui/components/moon_glyph.dart';
import '../shared/widgets.dart';
import 'journal_providers.dart';

/// Maps a mood valence (-2..+2) to a [MoonPhase].
MoonPhase _moodToPhase(int? mood) => switch (mood) {
  -2 => MoonPhase.newMoon,
  -1 => MoonPhase.crescent,
  0 => MoonPhase.half,
  1 => MoonPhase.gibbous,
  _ => MoonPhase.full,
};

/// Returns true when [text] contains Arabic-script characters (Urdu, Arabic).
bool _hasUrduScript(String text) =>
    text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text(l.journalNew),
        onPressed: () => context.go('/journal/new'),
      ),
      child: entries.when(
        loading: () => const SkeletonList(rows: 4),
        error: (_, _) =>
            ErrorState(onRetry: () => ref.invalidate(journalProvider)),
        data: (rows) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prompt chips — writing seeds
            _PromptRow(
              prompts: [l.journalPrompt1, l.journalPrompt2, l.journalPrompt3],
              label: l.journalPromptsTitle,
            ),
            const SizedBox(height: Tokens.s8),

            if (rows.isEmpty)
              EmptyState(
                title: l.journalEmptyTitle,
                body: l.journalEmptyBody,
                action: FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.journalNew),
                  onPressed: () => context.go('/journal/new'),
                ),
              )
            else
              _EntryList(rows: rows),

            // Storage note at bottom
            if (rows.isNotEmpty) ...[
              const SizedBox(height: Tokens.s16),
              InlineNote(text: l.journalEmptyBody),
              const SizedBox(height: Tokens.s32),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prompt chips
// ---------------------------------------------------------------------------

class _PromptRow extends StatelessWidget {
  const _PromptRow({required this.prompts, required this.label});

  final List<String> prompts;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Tokens.s8),
        Text(label, style: t.labelMedium?.copyWith(color: colors.ink2)),
        const SizedBox(height: Tokens.s8),
        Wrap(
          spacing: Tokens.s8,
          runSpacing: Tokens.s8,
          children: [
            for (final p in prompts)
              _PromptChip(text: p),
          ],
        ),
      ],
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.go('/journal/new', extra: text),
      child: Semantics(
        button: true,
        label: text,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s16, vertical: 10),
          constraints: const BoxConstraints(minHeight: Jugnu.minTarget),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.hairStrong),
          ),
          child: Text(
            text,
            style:
                t.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entry list
// ---------------------------------------------------------------------------

class _EntryList extends StatelessWidget {
  const _EntryList({required this.rows});

  final List<JournalEntry> rows;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM', dateLocaleOf(context));
    final colors = Theme.of(context).extension<JugnuColors>()!;
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Moon glyph — mood or default full if no mood set
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: Tokens.s12),
                    child: MoonGlyph(
                      phase: _moodToPhase(e.mood),
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.title?.isNotEmpty == true
                                    ? e.title!
                                    : e.body.split('\n').first,
                                style: t.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: Tokens.s8),
                            // Mono timestamp per design
                            Text(
                              df.format(e.createdAt),
                              style: jugnuTimestamp(scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        if (e.body.isNotEmpty) ...[
                          const SizedBox(height: Tokens.s4),
                          _BodyPreview(body: e.body),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: colors.hair),
        ],
      ],
    );
  }
}

/// Shows up to 2 lines of the entry body. If the text contains Urdu script,
/// renders it in Nastaliq RTL.
class _BodyPreview extends StatelessWidget {
  const _BodyPreview({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isUrdu = _hasUrduScript(body);

    if (isUrdu) {
      // Urdu script — Noto Nastaliq, RTL layout, generous line height.
      return Text.rich(
        TextSpan(
          text: body,
          style: TextStyle(
            fontFamily: 'NotoNastaliqUrdu',
            fontSize: 16,
            height: 2.0,
            color: scheme.onSurfaceVariant,
          ),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        locale: const Locale('ur'),
      );
    }

    return Text(
      body,
      style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
