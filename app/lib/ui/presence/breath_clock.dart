/// BreathClock — the tick type emitted by BreathFlower's clock stream.
///
/// The screen reads this to show phase words, the countdown number and the
/// four phase pills. The stream emits once per second.
library;

import 'package:flutter/foundation.dart';

/// Phase labels for the four box-breathing phases.
const breathPhaseLabels = [
  'Breathe in',
  'Hold',
  'Breathe out',
  'Hold',
];

/// A single tick from the BreathFlower clock stream.
@immutable
class BreathClockTick {
  const BreathClockTick({
    required this.phaseIndex,
    required this.secondsLeft,
  });

  /// Index 0–3 into the box-breathing phases:
  ///   0 = inhale (0–4 s), 1 = hold-in (4–8 s),
  ///   2 = exhale (8–12 s), 3 = hold-out (12–16 s).
  final int phaseIndex;

  /// Seconds remaining in the current phase, 1–4. Never zero.
  final int secondsLeft;

  /// Human-readable label for this phase.
  String get phaseLabel => breathPhaseLabels[phaseIndex.clamp(0, 3)];

  @override
  String toString() =>
      'BreathClockTick(phase: $phaseIndex ($phaseLabel), left: $secondsLeft)';

  @override
  bool operator ==(Object other) =>
      other is BreathClockTick &&
      other.phaseIndex == phaseIndex &&
      other.secondsLeft == secondsLeft;

  @override
  int get hashCode => Object.hash(phaseIndex, secondsLeft);
}
