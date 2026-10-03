import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../assessments/assessment_items.dart';
import '../assessments/assessment_outbox.dart';
import '../shared/widgets.dart';
import 'today_providers.dart';

/// /today/assess/:instrument — PHQ-9 or GAD-7 full question flow.
///
/// The router redirect ensures [instrument] is always a known value.
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
    _answers = List<int?>.filled(assessmentItems(widget.instrument, 'en').length, null);
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
      result = await ref.read(apiClientProvider).submitAssessment(widget.instrument, castAnswers);
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
      // Nothing to show without a result; go back so the screen isn't stranded.
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final items = assessmentItems(widget.instrument, lang);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (_result != null) return _ResultView(instrument: widget.instrument, result: _result!);

    final options = [l.optNotAtAll, l.optSeveralDays, l.optMoreThanHalf, l.optNearlyEveryDay];
    final answered = _answers[_index] != null;
    final last = _index == items.length - 1;

    return Screen(
      title: instrumentTitle(context, widget.instrument),
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Tokens.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_index + 1) / items.length),
              duration: context.motion(Tokens.normal),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4),
            ),
          ),
          const SizedBox(height: Tokens.s12),
          Text(l.assessmentQuestionOf(_index + 1, items.length), style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Tokens.s8),
          if (_index == 0) ...[Text(l.assessmentIntro, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)), const SizedBox(height: Tokens.s12)],
          Expanded(
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: context.motion(Tokens.normal),
                switchInCurve: Curves.easeOutCubic,
                child: Column(
                  key: ValueKey(_index),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(items[_index], style: t.headlineSmall),
                    const SizedBox(height: Tokens.s24),
                    for (var i = 0; i < options.length; i++) ...[
                      _Option(label: options[i], selected: _answers[_index] == i, onTap: () => setState(() => _answers[_index] = i)),
                      const SizedBox(height: Tokens.s8),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: Tokens.s12), child: Text(_error!, style: TextStyle(color: scheme.error))),
          Row(
            children: [
              if (_index > 0) TextButton(onPressed: () => setState(() => _index--), child: Text(l.assessmentBack)),
              const Spacer(),
              FilledButton(
                onPressed: !answered || _submitting
                    ? null
                    : last
                        ? _submit
                        : () => setState(() => _index++),
                style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(last ? l.assessmentFinish : l.assessmentNext),
              ),
            ],
          ),
          const SizedBox(height: Tokens.s8),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.rSmall),
        child: AnimatedContainer(
          duration: context.motion(Tokens.fast),
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s16),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.12) : Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(Tokens.rSmall),
            border: Border.all(color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.10), width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
              Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.instrument, required this.result});

  final Instrument instrument;
  final Assessment result;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final flagged = result.flags.contains('suicidal_ideation_item');
    final delta = result.delta;

    return Screen(
      title: l.resultTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Tokens.s16),
          Text(instrumentTitle(context, instrument), style: t.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Tokens.s8),
          Text(l.resultScore(result.score, assessmentMax(instrument)), style: t.displaySmall),
          const SizedBox(height: Tokens.s4),
          Text(bandLabel(context, result.band), style: t.titleLarge?.copyWith(color: scheme.primary)),
          if (delta != null) ...[
            const SizedBox(height: Tokens.s8),
            Text(l.resultDelta(delta > 0 ? '+$delta' : '$delta'), style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: Tokens.s24),
          Text(l.resultNote, style: t.bodyMedium),
          if (flagged) ...[
            const SizedBox(height: Tokens.s20),
            Container(
              padding: const EdgeInsets.all(Tokens.s16),
              decoration: BoxDecoration(color: scheme.tertiary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(Tokens.rSmall)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.resultFlagged, style: t.bodyMedium),
                  const SizedBox(height: Tokens.s12),
                  TextButton(onPressed: () => showCrisisSheet(context), child: Text(l.crisisCallUmang)),
                ],
              ),
            ),
          ],
          const SizedBox(height: Tokens.s32),
          FilledButton(onPressed: () => context.go('/today'), child: Text(l.resultDone)),
        ],
      ),
    );
  }
}

