import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';
import 'today_providers.dart';

/// /today — mood check-in, trend chart and assessment links.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;

    return Screen(
      title: l.tabToday,
      scroll: false,
      padding: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            Tokens.s20, Tokens.s8, Tokens.s20, Tokens.s48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mood check-in
            SectionTitle(l.moodPrompt),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var v = -2; v <= 2; v++)
                      _MoodButton(
                        valence: v,
                        label: switch (v) {
                          -2 => l.moodVeryLow,
                          -1 => l.moodLow,
                          0 => l.moodOkay,
                          1 => l.moodGood,
                          _ => l.moodGreat,
                        },
                        onTap: () => recordManualMood(ref, v),
                      ),
                  ],
                ),
              ),
            ),

            // Assessments
            SectionTitle(l.assessmentsTitle),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(l.assessmentPhq9),
                    subtitle: Text(l.assessmentPhq9Sub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/today/assess/phq9'),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                  ),
                  ListTile(
                    title: Text(l.assessmentGad7),
                    subtitle: Text(l.assessmentGad7Sub),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/today/assess/gad7'),
                  ),
                ],
              ),
            ),

            // Quick exercises link
            SectionTitle(l.todayTakeAMinute),
            Card(
              child: ListTile(
                leading: const Icon(Icons.air_rounded),
                title: Text(l.exercisesTitle),
                subtitle: Text(l.exercisesSub),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/today/exercises/box'),
              ),
            ),

            // Trend chart placeholder
            SectionTitle(l.moodTrend),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.s48),
                child: Center(
                  child: Text(l.moodTrendEmpty,
                      style: t.bodyMedium,
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton({
    required this.valence,
    required this.label,
    required this.onTap,
  });

  final int valence;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Tokens.valenceColor(valence);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Tokens.rSmall),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: Text(
                  (valence + 3).toString(),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: Tokens.s4),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
