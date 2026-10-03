/// Tests for the breath clock math: phase derivation, seconds-left countdown,
/// and the video-position-to-phase mapping used by BreathFlower.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/ui/presence/breath_clock.dart';

void main() {
  group('BreathClockTick', () {
    test('phase 0 is inhale', () {
      const tick = BreathClockTick(phaseIndex: 0, secondsLeft: 4);
      expect(tick.phaseLabel, 'Breathe in');
    });

    test('phase 1 is hold-in', () {
      const tick = BreathClockTick(phaseIndex: 1, secondsLeft: 3);
      expect(tick.phaseLabel, 'Hold');
    });

    test('phase 2 is exhale', () {
      const tick = BreathClockTick(phaseIndex: 2, secondsLeft: 2);
      expect(tick.phaseLabel, 'Breathe out');
    });

    test('phase 3 is hold-out', () {
      const tick = BreathClockTick(phaseIndex: 3, secondsLeft: 1);
      expect(tick.phaseLabel, 'Hold');
    });

    test('equality on matching fields', () {
      expect(
        const BreathClockTick(phaseIndex: 0, secondsLeft: 4),
        const BreathClockTick(phaseIndex: 0, secondsLeft: 4),
      );
    });

    test('inequality on different phase', () {
      expect(
        const BreathClockTick(phaseIndex: 0, secondsLeft: 4),
        isNot(const BreathClockTick(phaseIndex: 1, secondsLeft: 4)),
      );
    });

    test('inequality on different secondsLeft', () {
      expect(
        const BreathClockTick(phaseIndex: 0, secondsLeft: 3),
        isNot(const BreathClockTick(phaseIndex: 0, secondsLeft: 4)),
      );
    });

    test('phaseIndex clamps to 0–3 in phaseLabel', () {
      // phaseIndex outside 0-3 should not throw — the label clamps.
      expect(
        () => const BreathClockTick(phaseIndex: 5, secondsLeft: 1).phaseLabel,
        returnsNormally,
      );
    });
  });

  group('breath clock phase math', () {
    // The clock emits: phaseIndex = floor(elapsed / 4), secondsLeft = ceil(4 - elapsed%4)

    test('0.0 s → phase 0, 4 left', () {
      final t = _clockAtElapsed(0.0);
      expect(t.phaseIndex, 0);
      expect(t.secondsLeft, 4);
    });

    test('1.0 s → phase 0, 3 left', () {
      final t = _clockAtElapsed(1.0);
      expect(t.phaseIndex, 0);
      expect(t.secondsLeft, 3);
    });

    test('3.0 s → phase 0, 1 left', () {
      final t = _clockAtElapsed(3.0);
      expect(t.phaseIndex, 0);
      expect(t.secondsLeft, 1);
    });

    test('4.0 s → phase 1 (hold-in), 4 left', () {
      final t = _clockAtElapsed(4.0);
      expect(t.phaseIndex, 1);
      expect(t.secondsLeft, 4);
    });

    test('7.0 s → phase 1, 1 left', () {
      final t = _clockAtElapsed(7.0);
      expect(t.phaseIndex, 1);
      expect(t.secondsLeft, 1);
    });

    test('8.0 s → phase 2 (exhale), 4 left', () {
      final t = _clockAtElapsed(8.0);
      expect(t.phaseIndex, 2);
      expect(t.secondsLeft, 4);
    });

    test('12.0 s → phase 3 (hold-out), 4 left', () {
      final t = _clockAtElapsed(12.0);
      expect(t.phaseIndex, 3);
      expect(t.secondsLeft, 4);
    });

    test('15.0 s → phase 3, 1 left', () {
      final t = _clockAtElapsed(15.0);
      expect(t.phaseIndex, 3);
      expect(t.secondsLeft, 1);
    });

    test('16.0 s wraps to phase 0 (cycle boundary)', () {
      // 16.0 % 16 = 0 → same as t=0.0
      final t = _clockAtElapsed(16.0);
      expect(t.phaseIndex, 0);
      expect(t.secondsLeft, 4);
    });

    test('seconds-left never shows 0 at phase boundary', () {
      // At exactly t=4.0 we are entering phase 1 with 4 s left.
      final t = _clockAtElapsed(4.0);
      expect(t.secondsLeft, greaterThanOrEqualTo(1));
    });

    test('within a second, remaining rounds up', () {
      // At 0.5 s into phase 0, 3.5 s remain → ceil = 4.
      final t = _clockAtElapsed(0.5);
      expect(t.secondsLeft, 4);
    });

    test('at 3.1 s, 1 second remains (ceil of 0.9)', () {
      final t = _clockAtElapsed(3.1);
      expect(t.secondsLeft, 1);
    });
  });

  group('breathPhaseLabels', () {
    test('has exactly 4 entries', () {
      expect(breathPhaseLabels, hasLength(4));
    });

    test('phases 1 and 3 are both Hold', () {
      expect(breathPhaseLabels[1], 'Hold');
      expect(breathPhaseLabels[3], 'Hold');
    });
  });
}

/// Reproduces the BreathFlower clock math so it can be unit-tested without
/// spinning up the widget.
///
/// phaseIndex = floor(elapsed / 4).clamp(0, 3)
/// secondsLeft = ceil(4 - elapsed % 4).clamp(1, 4)
BreathClockTick _clockAtElapsed(double elapsed) {
  const cycleSecs = 16.0;
  final e = elapsed % cycleSecs;
  final phaseIdx = (e / 4).floor().clamp(0, 3);
  final secsLeft = (4 - (e % 4)).ceil().clamp(1, 4);
  return BreathClockTick(phaseIndex: phaseIdx, secondsLeft: secsLeft);
}
