import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/locale.dart';
import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../ui/components/slab.dart';
import '../shared/widgets.dart';

/// Provider for a single patient's overview. Family keyed on patient UID.
///
/// Exposes the consented sections (assessments, mood trend, summaries, journal)
/// from the link date onward. Raw chat is never included.
final patientOverviewProvider =
    FutureProvider.family<PatientOverview, String>(
  (ref, uid) => ref.watch(apiClientProvider).patientOverview(uid),
);

/// /clinic/patients/:id — individual patient overview.
///
/// Shows only the sections the patient consented to share:
/// - Check-in scores as number + band, newest first.
/// - Mood trend.
/// - Weekly summaries.
/// - Journal entries (shared only if the patient switches it on).
///
/// Never shows raw Eve chat. Assessment scores are numbers + band only;
/// every score has a "A pattern, not a diagnosis." footnote.
class PatientScreen extends ConsumerWidget {
  const PatientScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    return Screen(
      title: l.clinicianCaseload,
      help: false,
      quickExit: false,
      child: ref.watch(patientOverviewProvider(uid)).when(
        loading: () => const SkeletonList(rows: 4),
        error: (_, _) =>
            ErrorState(onRetry: () => ref.invalidate(patientOverviewProvider(uid))),
        data: (overview) => _PatientBody(overview: overview),
      ),
    );
  }
}

class _PatientBody extends StatelessWidget {
  const _PatientBody({required this.overview});

  final PatientOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final consent = overview.consent;

    final hasAnything = consent.shareAssessments ||
        consent.shareMoodTrend ||
        consent.shareJournal ||
        consent.shareSummaries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Tokens.s16),
        // Patient name
        Text(
          overview.patient.displayName ?? overview.patient.uid,
          style: t.titleLarge,
        ),
        const SizedBox(height: Tokens.s4),
        if (!hasAnything) ...[
          const SizedBox(height: Tokens.s24),
          EmptyState(
            title: l.clinicianNoConsent,
            body: l.clinicianCodeHelp,
          ),
        ] else ...[
          // Assessments
          if (consent.shareAssessments) ...[
            _SectionHeader(l.clinicianAssessments),
            Slab(
              padding: const EdgeInsets.all(Tokens.s16),
              child: _AssessmentsBlock(
                  assessments: overview.assessments ?? []),
            ),
          ],

          // Mood trend
          if (consent.shareMoodTrend &&
              (overview.moodTrend?.isNotEmpty ?? false)) ...[
            _SectionHeader(l.clinicianMood),
            Slab(
              padding: const EdgeInsets.all(Tokens.s16),
              child: Text(
                l.moodTrend,
                style: t.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],

          // Weekly summaries
          if (consent.shareSummaries &&
              (overview.summaries?.isNotEmpty ?? false)) ...[
            _SectionHeader(l.clinicianSummaries),
            for (final s in overview.summaries!) ...[
              Slab(
                padding: const EdgeInsets.all(Tokens.s16),
                child: Text(s.content,
                    style: t.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(height: Tokens.s8),
            ],
          ],

          // Journal entries (shared)
          if (consent.shareJournal &&
              (overview.journal?.isNotEmpty ?? false)) ...[
            _SectionHeader(l.clinicianJournal),
            for (final e in overview.journal!) ...[
              Slab(
                padding: const EdgeInsets.all(Tokens.s16),
                child: Text(
                  e.body,
                  style: t.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: Tokens.s8),
            ],
          ],
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.s24, bottom: Tokens.s12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Grouped assessment scores by instrument, newest first.
class _AssessmentsBlock extends StatelessWidget {
  const _AssessmentsBlock({required this.assessments});

  final List<Assessment> assessments;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final df = DateFormat.yMMMd(dateLocaleOf(context));

    if (assessments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Tokens.s12),
        child: Text(l.clinicianNoCheckins,
            style: t.bodyMedium?.copyWith(color: colors.ink2)),
      );
    }

    // Group by instrument
    final byInstrument = <Instrument, List<Assessment>>{};
    for (final a in assessments) {
      byInstrument.putIfAbsent(a.instrument, () => []).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final instrument in Instrument.values) ...[
          if (byInstrument.containsKey(instrument)) ...[
            Text(instrumentTitle(context, instrument),
                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Tokens.s8),
            for (final a in byInstrument[instrument]!) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Score number
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${a.score}',
                        style: t.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(bandLabel(context, a.band),
                                  style: t.bodyMedium),
                              const Spacer(),
                              Text(
                                df.format(a.takenAt),
                                style: t.labelSmall?.copyWith(
                                    color: colors.ink2),
                              ),
                            ],
                          ),
                          // Attention flags
                          if (a.flags.isNotEmpty) ...[
                            const SizedBox(height: Tokens.s4),
                            Wrap(
                              spacing: Tokens.s4,
                              children: [
                                for (final flag in a.flags)
                                  _AttentionChip(_flagLabel(context, flag)),
                              ],
                            ),
                          ],
                          if (a.unvalidatedTranslation) ...[
                            const SizedBox(height: Tokens.s4),
                            const UnvalidatedTranslationNotice(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Tokens.s8),
          ],
        ],
        // "A pattern, not a diagnosis." disclaimer
        Text(
          l.insightBasis(assessments.length),
          style: t.bodySmall?.copyWith(color: colors.ink3),
        ),
        const SizedBox(height: Tokens.s16),
      ],
    );
  }

  String _flagLabel(BuildContext context, String flag) {
    final l = context.l10n;
    return switch (flag) {
      'risk_item' => l.clinicianAttentionRisk,
      'worsened' => l.clinicianAttentionWorsened,
      'severe' => l.clinicianAttentionSevere,
      _ => flag,
    };
  }
}

class _AttentionChip extends StatelessWidget {
  const _AttentionChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;
    // Use the action (primary) colour to draw attention, never red.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: t.labelMedium?.copyWith(
          color: colors.actionText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Small inline notice for assessment scores answered in Roman Urdu wording.
///
/// Shown in the clinician patient view next to any score where
/// [Assessment.unvalidatedTranslation] is true.
class UnvalidatedTranslationNotice extends StatelessWidget {
  const UnvalidatedTranslationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_outlined, size: 14, color: colors.ink3),
        const SizedBox(width: 4),
        Text(
          l.clinicianUnvalidatedTranslation,
          style: t.bodySmall?.copyWith(color: colors.ink3),
        ),
      ],
    );
  }
}
