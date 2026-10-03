import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/features/exercises/breathing.dart';

void main() {
  final box = patternById('box')!;

  test('every pattern resolves and has a positive cycle', () {
    for (final p in breathingPatterns) {
      expect(patternById(p.id), isNotNull);
      expect(p.cycle.inSeconds, greaterThan(0));
      expect(p.defaultCycles, greaterThan(0));
    }
  });

  test('box breathing is four equal counts', () {
    expect(box.steps.map((s) => s.seconds), everyElement(4));
    expect(box.cycle.inSeconds, 16);
  });

  group('timeline', () {
    final t = BreathTimeline(box, 3);

    test('total length is cycle times count', () {
      expect(t.totalSeconds, 48);
    });

    test('resolves the phase at a given moment', () {
      expect(t.at(0).step.phase, BreathPhase.inhale);
      expect(t.at(5).step.phase, BreathPhase.holdIn);
      expect(t.at(9).step.phase, BreathPhase.exhale);
      expect(t.at(13).step.phase, BreathPhase.holdOut);
      expect(t.at(17).step.phase, BreathPhase.inhale);
    });

    test('counts rounds', () {
      expect(t.cycleAt(0), 1);
      expect(t.cycleAt(17), 2);
      expect(t.cycleAt(33), 3);
    });

    test('remaining counts down whole seconds and never shows zero', () {
      expect(t.at(0).remaining, 4);
      expect(t.at(3.2).remaining, 1);
      expect(t.at(3.99).remaining, greaterThanOrEqualTo(1));
    });

    test('clamps past the end rather than throwing', () {
      expect(() => t.at(999), returnsNormally);
      expect(t.at(999).step.phase, BreathPhase.holdOut);
    });
  });

  group('guide scale', () {
    test('inhale grows, exhale shrinks, holds are steady', () {
      expect(breathScale(BreathPhase.inhale, 0), lessThan(breathScale(BreathPhase.inhale, 1)));
      expect(breathScale(BreathPhase.exhale, 0), greaterThan(breathScale(BreathPhase.exhale, 1)));
      expect(breathScale(BreathPhase.holdIn, 0), breathScale(BreathPhase.holdIn, 1));
      expect(breathScale(BreathPhase.holdOut, 0), breathScale(BreathPhase.holdOut, 1));
    });

    test('phases meet so the circle never jumps between them', () {
      expect(breathScale(BreathPhase.inhale, 1), closeTo(breathScale(BreathPhase.holdIn, 0), 0.001));
      expect(breathScale(BreathPhase.holdIn, 1), closeTo(breathScale(BreathPhase.exhale, 0), 0.001));
      expect(breathScale(BreathPhase.exhale, 1), closeTo(breathScale(BreathPhase.holdOut, 0), 0.001));
      expect(breathScale(BreathPhase.holdOut, 1), closeTo(breathScale(BreathPhase.inhale, 0), 0.001));
    });

    test('stays within the drawable range', () {
      for (final phase in BreathPhase.values) {
        for (var p = 0.0; p <= 1.0; p += 0.1) {
          final s = breathScale(phase, p);
          expect(s, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });
}
