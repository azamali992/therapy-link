import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/locale.dart';
import '../../app/theme/tokens.dart';
import '../../core/api/models.dart';
import '../../core/security/privacy_settings.dart';
import '../../core/security/quick_exit.dart';
import '../../ui/components/insight_card.dart';
import '../../ui/components/inline_note.dart';
import '../../ui/components/jugnu_app_bar.dart' as jab;
import '../../ui/components/jugnu_scaffold.dart';
import '../../ui/components/mood_picker.dart';
import '../../ui/components/slab.dart';
import '../../ui/components/week_trend.dart';
import '../assessments/assessment_outbox.dart';
import '../shared/widgets.dart'
    show showCrisisSheet, bandLabel, instrumentTitle, L10nX;
import 'insights.dart';
import 'today_providers.dart';

/// /today -- mood check-in, week trend, insights, and assessment entry points.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// Whether the mood picker has folded to its summary line.
  bool _pickerFolded = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final showQuickExit = ref.watch(
      privacySettingsProvider.select((s) => s.quickExit),
    );

    final todayMoodAsync = ref.watch(todayMoodProvider);
    final checkInCountAsync = ref.watch(moodCheckInCountProvider);
    final weekAsync = ref.watch(weekTrendProvider);
    final insightAsync = ref.watch(moodInsightProvider);
    final assessmentsAsync = ref.watch(assessmentsProvider);
    final outbox = ref.watch(assessmentOutboxProvider);

    // Pre-populate the picker with today's already-saved check-in, if any.
    final MoodSummary? preloadedSummary = todayMoodAsync.whenOrNull(
      data: (v) =>
          v == null ? null : MoodSummary(valence: v, savedAt: DateTime.now()),
    );
    // Once data loads and shows a prior check-in, start the picker folded.
    if (preloadedSummary != null && !_pickerFolded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pickerFolded = true);
      });
    }

    final showScaleEnds = checkInCountAsync.maybeWhen(
      data: (n) => n < 3,
      orElse: () => true,
    );

    return JugnuScaffold(
      appBar: jab.JugnuAppBar(
        title: Text(l.tabToday, style: text.titleLarge),
        onGetHelp: () => showCrisisSheet(context),
        showQuickExit: showQuickExit,
        onQuickExit: showQuickExit
            ? () => ref.read(quickExitProvider.notifier).exit()
            : null,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Jugnu.readingWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Jugnu.s20,
                Jugnu.s4,
                Jugnu.s20,
                Jugnu.s48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date + time-of-day greeting.
                  _DateLine(),
                  const SizedBox(height: Jugnu.s12),

                  // Mood check-in slab.
                  Slab(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question header collapses when the picker folds.
                        AnimatedSize(
                          duration: context.motion(Jugnu.motionFold),
                          curve: Jugnu.curveEaseOut,
                          child: _pickerFolded
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.moodPrompt, style: text.titleMedium),
                                    const SizedBox(height: Jugnu.s12),
                                  ],
                                ),
                        ),
                        MoodPicker(
                          summary: preloadedSummary,
                          showScaleEnds: showScaleEnds,
                          onSelected: (valence) =>
                              recordManualMood(ref, valence - 2),
                          onFolded: (_) => setState(() => _pickerFolded = true),
                          onChange: () => setState(() => _pickerFolded = false),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Jugnu.s12),

                  // This week slab.
                  Slab(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.moodTrendWeek, style: text.titleMedium),
                        const SizedBox(height: Jugnu.s12),
                        weekAsync.when(
                          loading: () => const SizedBox(
                            height: 104,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          error: (_, _) => const SizedBox(height: 104),
                          data: (days) => WeekTrend(days: days),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Jugnu.s12),

                  // Insight card + breathing row (or standalone breathing row when no insight).
                  insightAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (insight) {
                      final breathRow = _BreathingRowContent(
                        colors: colors,
                        text: text,
                        scheme: scheme,
                      );
                      if (insight.kind == InsightKind.notEnoughData) {
                        return Slab(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Jugnu.slabPadding,
                            vertical: 14,
                          ),
                          child: breathRow,
                        );
                      }
                      return InsightCard(
                        body: _insightBody(context, insight),
                        checkInCount: insight.samples ?? 0,
                        action: breathRow,
                      );
                    },
                  ),

                  const SizedBox(height: Jugnu.s12),

                  // PHQ-9 entry slab.
                  _AssessmentSlab(
                    instrument: Instrument.phq9,
                    assessmentsAsync: assessmentsAsync,
                    onTap: () => context.go('/today/assess/phq9'),
                  ),

                  const SizedBox(height: 10),

                  // GAD-7 entry slab.
                  _AssessmentSlab(
                    instrument: Instrument.gad7,
                    assessmentsAsync: assessmentsAsync,
                    onTap: () => context.go('/today/assess/gad7'),
                  ),

                  // Offline outbox note when assessments are queued but unsent.
                  if (outbox.pending.isNotEmpty) ...[
                    const SizedBox(height: Jugnu.s16),
                    InlineNote(
                      text:
                          '${outbox.pending.length} '
                          'check-in${outbox.pending.length == 1 ? '' : 's'} '
                          'saved on this phone and will upload when you are back online.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _insightBody(BuildContext context, MoodInsight insight) {
    final l = context.l10n;
    return switch (insight.kind) {
      InsightKind.timeOfDay => l.insightTimeOfDay(
        _timeLabel(context, insight.worseLabel),
        _timeLabel(context, insight.betterLabel),
      ),
      InsightKind.weekOverWeek =>
        insight.betterLabel == 'up' ? l.insightWeekUp : l.insightWeekDown,
      InsightKind.notEnoughData || InsightKind.dayOfWeek => '',
    };
  }

  String _timeLabel(BuildContext context, String? raw) {
    if (raw == null) return '';
    final l = context.l10n;
    return switch (raw) {
      'morning' => l.insightMorning,
      'afternoon' => l.insightAfternoon,
      'evening' => l.insightEvening,
      _ => raw,
    };
  }
}

// ---------------------------------------------------------------------------
// Date / greeting line
// ---------------------------------------------------------------------------

class _DateLine extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(todayClockProvider)();
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final text = Theme.of(context).textTheme;
    final locale = dateLocaleOf(context);
    final l = context.l10n;
    final dayName = DateFormat('EEEE', locale).format(now);
    // Use the last word of the greeting string as a concise time-of-day label.
    final greeting = now.hour < 12
        ? l.todayMorning
        : now.hour < 17
        ? l.todayAfternoon
        : l.todayEvening;
    final timePart = greeting.split(' ').last.toLowerCase();

    return Text(
      '$dayName, $timePart',
      style: text.bodyMedium?.copyWith(color: colors.ink2),
    );
  }
}

// ---------------------------------------------------------------------------
// Breathing entry row (inline action, reused in InsightCard and standalone)
// ---------------------------------------------------------------------------

class _BreathingRowContent extends StatelessWidget {
  const _BreathingRowContent({
    required this.colors,
    required this.text,
    required this.scheme,
  });

  final JugnuColors colors;
  final TextTheme text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      onTap: () => context.go('/today/exercises/box'),
      child: Semantics(
        button: true,
        label: l.exerciseBox,
        child: Container(
          constraints: const BoxConstraints(minHeight: Jugnu.minTarget),
          child: Row(
            children: [
              Icon(Icons.air, size: 22, color: scheme.onSurface),
              const SizedBox(width: Jugnu.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.exerciseBox, style: text.bodyLarge),
                    Text(
                      l.exerciseBoxSub,
                      style: text.bodyMedium?.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.ink3, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assessment entry slab
// ---------------------------------------------------------------------------

class _AssessmentSlab extends ConsumerWidget {
  const _AssessmentSlab({
    required this.instrument,
    required this.assessmentsAsync,
    required this.onTap,
  });

  final Instrument instrument;
  final AsyncValue<List<Assessment>> assessmentsAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final subtitle = instrument == Instrument.phq9
        ? l.assessmentPhq9Sub
        : l.assessmentGad7Sub;

    final Assessment? latest = assessmentsAsync.whenOrNull(
      data: (list) {
        final filtered = list.where((a) => a.instrument == instrument).toList();
        if (filtered.isEmpty) return null;
        filtered.sort((a, b) => b.takenAt.compareTo(a.takenAt));
        return filtered.first;
      },
    );

    // Build trailing score/loading widgets.
    Widget? scoreWidget;
    String? bandDaysLabel;
    if (assessmentsAsync.isLoading) {
      scoreWidget = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.ink3),
      );
    } else if (latest != null) {
      final daysAgo = ref
          .watch(todayClockProvider)()
          .difference(latest.takenAt)
          .inDays;
      scoreWidget = Text(
        '${latest.score}',
        style: text.titleMedium?.copyWith(color: scheme.primary),
      );
      bandDaysLabel =
          '${bandLabel(context, latest.band)} · ${l.assessmentAgo(daysAgo)}';
    }

    return Slab(
      padding: const EdgeInsets.symmetric(
        horizontal: Jugnu.slabPadding,
        vertical: 14,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: instrumentTitle(context, instrument),
          child: Container(
            constraints: const BoxConstraints(minHeight: Jugnu.minTarget),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: title + score + chevron.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        instrumentTitle(context, instrument),
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (scoreWidget != null) ...[
                      const SizedBox(width: Jugnu.s8),
                      scoreWidget,
                    ],
                    const SizedBox(width: Jugnu.s8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.ink3,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Row 2: subtitle + band/days.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: text.bodyMedium?.copyWith(color: colors.ink2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (bandDaysLabel != null) ...[
                      const SizedBox(width: Jugnu.s8),
                      Text(
                        bandDaysLabel,
                        style: text.labelSmall?.copyWith(color: colors.ink2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
