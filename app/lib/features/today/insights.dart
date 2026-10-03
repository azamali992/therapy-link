import 'package:flutter/foundation.dart';

/// A pattern found in someone's own mood history.
///
/// Every finding has to clear a sample-size floor *and* a minimum effect size before it is shown.
/// Telling someone "your evenings are harder" on the strength of three taps would be inventing a
/// pattern and handing it to them as fact, which in this app is worse than saying nothing.
enum InsightKind { timeOfDay, dayOfWeek, weekOverWeek, notEnoughData }

@immutable
class MoodInsight {
  const MoodInsight(this.kind, {this.betterLabel, this.worseLabel, this.delta, this.samples});

  final InsightKind kind;
  final String? betterLabel;
  final String? worseLabel;
  final double? delta;
  final int? samples;

  static const none = MoodInsight(InsightKind.notEnoughData);
}

@immutable
class MoodSample {
  const MoodSample(this.at, this.valence);

  final DateTime at;
  final int valence;
}

/// Minimum readings in *each* compared group.
const _minPerGroup = 4;

/// Minimum difference in mean valence (scale is -2..2) before a gap counts as a pattern rather
/// than noise. 0.6 is a little under a third of one step on the five-point scale.
const _minDelta = 0.6;

enum DayPart { morning, afternoon, evening }

DayPart dayPartOf(DateTime t) {
  if (t.hour < 12) return DayPart.morning;
  if (t.hour < 17) return DayPart.afternoon;
  return DayPart.evening;
}

double? _mean(Iterable<int> xs) {
  final list = xs.toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

/// The single strongest finding, or [MoodInsight.none]. One insight at a time — a distressed
/// reader should not be handed a dashboard of correlations to interpret.
MoodInsight findInsight(List<MoodSample> samples, {DateTime? now}) {
  if (samples.length < _minPerGroup * 2) return MoodInsight.none;
  final candidates = [
    _timeOfDay(samples),
    _weekOverWeek(samples, now ?? DateTime.now()),
  ].whereType<MoodInsight>().toList();
  if (candidates.isEmpty) return MoodInsight.none;
  candidates.sort((a, b) => (b.delta ?? 0).compareTo(a.delta ?? 0));
  return candidates.first;
}

MoodInsight? _timeOfDay(List<MoodSample> samples) {
  final byPart = <DayPart, List<int>>{};
  for (final s in samples) {
    byPart.putIfAbsent(dayPartOf(s.at), () => []).add(s.valence);
  }
  final eligible = byPart.entries.where((e) => e.value.length >= _minPerGroup).toList();
  if (eligible.length < 2) return null;

  eligible.sort((a, b) => _mean(a.value)!.compareTo(_mean(b.value)!));
  final worst = eligible.first;
  final best = eligible.last;
  final delta = _mean(best.value)! - _mean(worst.value)!;
  if (delta < _minDelta) return null;

  return MoodInsight(
    InsightKind.timeOfDay,
    betterLabel: best.key.name,
    worseLabel: worst.key.name,
    delta: delta,
    samples: best.value.length + worst.value.length,
  );
}

MoodInsight? _weekOverWeek(List<MoodSample> samples, DateTime now) {
  final weekAgo = now.subtract(const Duration(days: 7));
  final twoWeeksAgo = now.subtract(const Duration(days: 14));
  final thisWeek = [for (final s in samples) if (s.at.isAfter(weekAgo)) s.valence];
  final lastWeek = [
    for (final s in samples)
      if (s.at.isAfter(twoWeeksAgo) && !s.at.isAfter(weekAgo)) s.valence,
  ];
  if (thisWeek.length < _minPerGroup || lastWeek.length < _minPerGroup) return null;

  final delta = _mean(thisWeek)! - _mean(lastWeek)!;
  if (delta.abs() < _minDelta) return null;

  return MoodInsight(
    InsightKind.weekOverWeek,
    delta: delta.abs(),
    samples: thisWeek.length + lastWeek.length,
    betterLabel: delta > 0 ? 'up' : 'down',
  );
}
