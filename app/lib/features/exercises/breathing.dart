import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

enum BreathPhase { inhale, holdIn, exhale, holdOut }

@immutable
class BreathStep {
  const BreathStep(this.phase, this.seconds);

  final BreathPhase phase;
  final int seconds;
}

@immutable
class BreathingPattern {
  const BreathingPattern({
    required this.id,
    required this.steps,
    required this.defaultCycles,
    this.evidence,
  });

  final String id;
  final List<BreathStep> steps;
  final int defaultCycles;

  /// Why this pattern exists, shown to the user. Claims here should be defensible.
  final String? evidence;

  Duration get cycle => Duration(seconds: steps.fold(0, (a, s) => a + s.seconds));
  Duration total(int cycles) => cycle * cycles;
}

/// Three patterns, deliberately few. Each is widely taught and low-risk; none of them claims to
/// treat anything. The physiological sigh is first because it works fastest when someone is
/// already escalated, which is when they are most likely to open this screen.
const breathingPatterns = <BreathingPattern>[
  BreathingPattern(
    id: 'sigh',
    steps: [
      BreathStep(BreathPhase.inhale, 4),
      BreathStep(BreathPhase.holdIn, 1),
      BreathStep(BreathPhase.inhale, 2),
      BreathStep(BreathPhase.exhale, 6),
    ],
    defaultCycles: 5,
  ),
  BreathingPattern(
    id: 'box',
    steps: [
      BreathStep(BreathPhase.inhale, 4),
      BreathStep(BreathPhase.holdIn, 4),
      BreathStep(BreathPhase.exhale, 4),
      BreathStep(BreathPhase.holdOut, 4),
    ],
    defaultCycles: 6,
  ),
  BreathingPattern(
    id: 'calming',
    steps: [
      BreathStep(BreathPhase.inhale, 4),
      BreathStep(BreathPhase.holdIn, 7),
      BreathStep(BreathPhase.exhale, 8),
    ],
    defaultCycles: 4,
  ),
];

BreathingPattern? patternById(String id) {
  for (final p in breathingPatterns) {
    if (p.id == id) return p;
  }
  return null;
}

/// A flattened timeline so the player can seek by elapsed seconds rather than juggling timers.
@immutable
class BreathTimeline {
  BreathTimeline(this.pattern, this.cycles)
      : _steps = [for (var c = 0; c < cycles; c++) ...pattern.steps];

  final BreathingPattern pattern;
  final int cycles;
  final List<BreathStep> _steps;

  int get totalSeconds => _steps.fold(0, (a, s) => a + s.seconds);

  /// The step covering [elapsed], how far through it we are (0..1), and seconds remaining in it.
  ({BreathStep step, double progress, int remaining, int index}) at(double elapsed) {
    var t = elapsed.clamp(0, totalSeconds.toDouble());
    for (var i = 0; i < _steps.length; i++) {
      final s = _steps[i];
      if (t < s.seconds || i == _steps.length - 1) {
        final p = (t / s.seconds).clamp(0.0, 1.0);
        return (step: s, progress: p, remaining: (s.seconds - t).ceil().clamp(1, s.seconds), index: i);
      }
      t -= s.seconds;
    }
    throw StateError('unreachable');
  }

  int cycleAt(double elapsed) {
    final i = at(elapsed).index;
    return (i ~/ pattern.steps.length) + 1;
  }
}

/// How large the guide circle should be for a phase — the visual the user paces their breath to.
double breathScale(BreathPhase phase, double progress) => switch (phase) {
  BreathPhase.inhale => 0.45 + 0.55 * Curves.easeInOutSine.transform(progress),
  BreathPhase.holdIn => 1.0,
  BreathPhase.exhale => 1.0 - 0.55 * Curves.easeInOutSine.transform(progress),
  BreathPhase.holdOut => 0.45,
};
