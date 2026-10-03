import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/security/privacy_settings.dart';
import '../../core/security/quick_exit.dart';
import '../../ui/components/jugnu_app_bar.dart' as jab;
import '../../ui/components/jugnu_scaffold.dart';
import '../../ui/components/slab.dart';
import '../assessments/assessment_items.dart';
import '../assessments/assessment_outbox.dart';
import '../shared/widgets.dart'
    show showCrisisSheet, bandLabel, instrumentTitle, L10nX;
import 'today_providers.dart';

/// /today/assess/:instrument -- PHQ-9 or GAD-7 one-question-per-step flow.
///
/// All behaviour (offline queue, item 9 crisis sheet, submit) is preserved from v1.
/// The visual redesign replaces [Screen] + [Tokens] with [JugnuScaffold] and the
/// Jugnu slab-card option style.
class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key, required this.instrument});

  final Instrument instrument;

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  late final List<int?> _answers;
  int _index = 0;
  bool _submitting = false;
  Assessment? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _answers =
        List<int?>.filled(assessmentItems(widget.instrument, 'en').length, null);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final castAnswers = _answers.cast<int>();
    // Check item 9 on the phone first — does not wait on the server and works offline.
    final flagged = itemNineFlagged(widget.instrument, _answers);
    Assessment? result;
    bool queued = false;
    try {
      result = await ref
          .read(apiClientProvider)
          .submitAssessment(widget.instrument, castAnswers);
      ref.invalidate(assessmentsProvider);
    } catch (_) {
      // Offline or server error: queue for retry.
      await ref.read(assessmentOutboxProvider).add(widget.instrument, castAnswers);
      queued = true;
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _submitting = false;
    });
    if (flagged) {
      await showCrisisSheet(context);
      if (!mounted) return;
    }
    if (queued) {
      // Nothing to show without a result; go back so the screen is not stranded.
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final items = assessmentItems(widget.instrument, lang);
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final showQuickExit =
        ref.watch(privacySettingsProvider.select((s) => s.quickExit));

    if (_result != null) {
      return AssessmentResultView(
        instrument: widget.instrument,
        result: _result!,
        showQuickExit: showQuickExit,
        onQuickExit: showQuickExit
            ? () => ref.read(quickExitProvider.notifier).exit()
            : null,
      );
    }

    final options = [
      l.optNotAtAll,
      l.optSeveralDays,
      l.optMoreThanHalf,
      l.optNearlyEveryDay,
    ];
    final answered = _answers[_index] != null;
    final last = _index == items.length - 1;

    return JugnuScaffold(
      appBar: jab.JugnuAppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => context.go('/today'),
        ),
        title: Text(instrumentTitle(context, widget.instrument),
            style: t.titleMedium),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Jugnu.s20, Jugnu.s8, Jugnu.s20, Jugnu.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress bar — animated to current question.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (_index + 1) / items.length),
                      duration: context.motion(Jugnu.motionSummaryIn),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) =>
                          LinearProgressIndicator(value: v, minHeight: 4),
                    ),
                  ),
                  const SizedBox(height: Jugnu.s12),
                  Text(
                    l.assessmentQuestionOf(_index + 1, items.length),
                    style: t.labelLarge?.copyWith(color: colors.ink2),
                  ),
                  const SizedBox(height: Jugnu.s8),
                  if (_index == 0) ...[
                    Text(
                      l.assessmentIntro,
                      style: t.bodyMedium?.copyWith(color: colors.ink2),
                    ),
                    const SizedBox(height: Jugnu.s12),
                  ],
                  // Question text + options area — scrollable in case text is long.
                  Expanded(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: context.motion(Jugnu.motionSummaryIn),
                        switchInCurve: Curves.easeOutCubic,
                        child: Column(
                          key: ValueKey(_index),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(items[_index], style: t.headlineSmall),
                            const SizedBox(height: Jugnu.s20),
                            for (var i = 0; i < options.length; i++) ...[
                              _Option(
                                label: options[i],
                                selected: _answers[_index] == i,
                                onTap: () =>
                                    setState(() => _answers[_index] = i),
                              ),
                              const SizedBox(height: Jugnu.s8),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: Jugnu.s12),
                      child: Text(
                        _error!,
                        style: t.bodyMedium?.copyWith(color: scheme.error),
                      ),
                    ),
                  // Navigation row — Back + Next / See result.
                  Row(
                    children: [
                      if (_index > 0)
                        TextButton(
                          onPressed: () => setState(() => _index--),
                          child: Text(l.assessmentBack),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: !answered || _submitting
                            ? null
                            : last
                                ? _submit
                                : () => setState(() => _index++),
                        style: FilledButton.styleFrom(
                          minimumSize:
                              const Size(140, Jugnu.primaryButtonHeight),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Text(last
                                ? l.assessmentFinish
                                : l.assessmentNext),
                      ),
                    ],
                  ),
                  const SizedBox(height: Jugnu.s8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Option card — 48 dp min height, slab outline style.
// ---------------------------------------------------------------------------

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motion(Jugnu.motionPress),
          constraints:
              const BoxConstraints(minHeight: Jugnu.minTarget),
          padding: const EdgeInsets.symmetric(
              horizontal: Jugnu.slabPadding, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? colors.raised
                : colors.surface,
            borderRadius: BorderRadius.circular(Jugnu.rNested),
            border: Border.all(
              color: selected ? colors.eve : colors.hair,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: t.bodyLarge)),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? colors.eve : colors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result view — score, band, explanation, "Talk it through with Eve" link.
// ---------------------------------------------------------------------------

/// Shows the score, band, explanation and follow-up actions after submission.
///
/// Exported for use in golden review tests.
class AssessmentResultView extends StatelessWidget {
  const AssessmentResultView({
    super.key,
    required this.instrument,
    required this.result,
    required this.showQuickExit,
    this.onQuickExit,
  });

  final Instrument instrument;
  final Assessment result;
  final bool showQuickExit;
  final VoidCallback? onQuickExit;

  /// Returns the plain-English band explanation string for a given band.
  String _bandExplain(BuildContext context, String band) {
    final l = context.l10n;
    return switch (band) {
      'minimal' => l.resultExplainMinimal,
      'mild' => l.resultExplainMild,
      'moderate' => l.resultExplainModerate,
      'moderately_severe' => l.resultExplainModeratelySevere,
      'severe' => l.resultExplainSevere,
      _ => l.resultNote,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final flagged = result.flags.contains('suicidal_ideation_item');
    final delta = result.delta;

    return JugnuScaffold(
      appBar: jab.JugnuAppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Done',
          onPressed: () => context.go('/today'),
        ),
        title: Text(l.resultTitle, style: t.titleMedium),
        onGetHelp: () => showCrisisSheet(context),
        showQuickExit: showQuickExit,
        onQuickExit: onQuickExit,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Jugnu.readingWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  Jugnu.s20, Jugnu.s16, Jugnu.s20, Jugnu.s48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score slab.
                  Slab(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instrumentTitle(context, instrument),
                          style: t.labelLarge?.copyWith(color: colors.ink2),
                        ),
                        const SizedBox(height: Jugnu.s8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${result.score}',
                              style: t.displaySmall,
                            ),
                            const SizedBox(width: Jugnu.s8),
                            Text(
                              l.resultScore(
                                  result.score, assessmentMax(instrument)),
                              style:
                                  t.bodyMedium?.copyWith(color: colors.ink2),
                            ),
                          ],
                        ),
                        const SizedBox(height: Jugnu.s4),
                        // Band label — neutral colour, no red/green.
                        Text(
                          bandLabel(context, result.band),
                          style: t.titleMedium,
                        ),
                        if (delta != null) ...[
                          const SizedBox(height: Jugnu.s8),
                          Text(
                            l.resultDelta(delta > 0 ? '+$delta' : '$delta'),
                            style:
                                t.bodyMedium?.copyWith(color: colors.ink2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Jugnu.s12),

                  // Band explanation slab — what the score range means.
                  Slab(
                    child: Text(
                      _bandExplain(context, result.band),
                      style: t.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: Jugnu.s8),

                  // Footnote.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Jugnu.s4),
                    child: Text(
                      l.resultNote,
                      style:
                          t.bodyMedium?.copyWith(color: colors.ink2),
                    ),
                  ),

                  // Item 9 flagged — crisis support note.
                  if (flagged) ...[
                    const SizedBox(height: Jugnu.s20),
                    Slab(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.resultFlagged, style: t.bodyMedium),
                          const SizedBox(height: Jugnu.s12),
                          // Never animated, never disabled.
                          TextButton(
                            onPressed: () => showCrisisSheet(context),
                            child: Text(l.crisisCallUmang),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: Jugnu.s24),

                  // "Talk it through with Eve" link.
                  Slab(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Jugnu.slabPadding, vertical: 14),
                    child: GestureDetector(
                      onTap: () => context.go('/eve'),
                      child: Semantics(
                        button: true,
                        label: l.resultTalkToEve,
                        child: Container(
                          constraints: const BoxConstraints(
                              minHeight: Jugnu.minTarget),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.resultTalkToEve,
                                  style: t.bodyLarge,
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: colors.ink3, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: Jugnu.s32),
                  FilledButton(
                    onPressed: () => context.go('/today'),
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(Jugnu.primaryButtonHeight),
                    ),
                    child: Text(l.resultDone),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
