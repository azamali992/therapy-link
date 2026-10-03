/// Tests for the rendering ladder selection logic (chooseRung — pure function).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/ui/presence/presence_assets.dart' show EvePresenceState;
import 'package:therapylink/ui/presence/presence_rung.dart';

void main() {
  group('chooseRung', () {
    test('no signals → 720 px video', () {
      const signals = DeviceSignals();
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.video);
      expect(choice.quality, VideoQuality.hd);
    });

    test('reduced motion → poster', () {
      const signals = DeviceSignals(reducedMotion: true);
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.poster);
    });

    test('battery saver → 360 px video', () {
      const signals = DeviceSignals(batterySaver: true);
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.video);
      expect(choice.quality, VideoQuality.low);
    });

    test('low RAM → 360 px video', () {
      const signals = DeviceSignals(lowRam: true);
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.video);
      expect(choice.quality, VideoQuality.low);
    });

    test('data saver → 360 px video', () {
      const signals = DeviceSignals(dataSaver: true);
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.video);
      expect(choice.quality, VideoQuality.low);
    });

    test('reduced motion beats battery saver (poster wins)', () {
      const signals = DeviceSignals(reducedMotion: true, batterySaver: true);
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.poster);
    });

    test('reduced motion beats low RAM (poster wins)', () {
      const signals = DeviceSignals(reducedMotion: true, lowRam: true);
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.poster);
    });

    test('reduced motion beats data saver (poster wins)', () {
      const signals = DeviceSignals(reducedMotion: true, dataSaver: true);
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.poster);
    });

    test('all low-cost signals together → 360 px video', () {
      const signals = DeviceSignals(
        batterySaver: true,
        lowRam: true,
        dataSaver: true,
      );
      final choice = chooseRung(signals);
      expect(choice.rung, PresenceRung.video);
      expect(choice.quality, VideoQuality.low);
    });
  });

  group('RungChoice equality', () {
    test('same rung and quality are equal', () {
      expect(
        const RungChoice(PresenceRung.video, quality: VideoQuality.hd),
        const RungChoice(PresenceRung.video, quality: VideoQuality.hd),
      );
    });

    test('different quality is not equal', () {
      expect(
        const RungChoice(PresenceRung.video, quality: VideoQuality.hd),
        isNot(const RungChoice(PresenceRung.video, quality: VideoQuality.low)),
      );
    });

    test('different rung is not equal', () {
      expect(
        const RungChoice(PresenceRung.poster),
        isNot(const RungChoice(PresenceRung.video)),
      );
    });
  });

  group('video asset path selection', () {
    test('idle HD returns the HD mp4', () {
      expect(_videoFor(EvePresenceState.idle, VideoQuality.hd), contains('eve-idle.mp4'));
    });

    test('idle low returns the 360 mp4', () {
      expect(_videoFor(EvePresenceState.idle, VideoQuality.low), contains('eve-idle-360.mp4'));
    });

    test('listening HD', () {
      expect(_videoFor(EvePresenceState.listening, VideoQuality.hd), contains('eve-listening.mp4'));
    });

    test('listening low', () {
      expect(_videoFor(EvePresenceState.listening, VideoQuality.low), contains('eve-listening-360.mp4'));
    });

    test('thinking HD', () {
      expect(_videoFor(EvePresenceState.thinking, VideoQuality.hd), contains('eve-thinking.mp4'));
    });

    test('thinking low', () {
      expect(_videoFor(EvePresenceState.thinking, VideoQuality.low), contains('eve-thinking-360.mp4'));
    });
  });

  group('DeviceSignals', () {
    test('default has all false', () {
      const s = DeviceSignals();
      expect(s.reducedMotion, isFalse);
      expect(s.batterySaver, isFalse);
      expect(s.lowRam, isFalse);
      expect(s.dataSaver, isFalse);
    });

    test('toString includes all fields', () {
      const s = DeviceSignals(reducedMotion: true, batterySaver: false);
      expect(s.toString(), contains('reducedMotion: true'));
      expect(s.toString(), contains('batterySaver: false'));
    });
  });
}

/// Mirrors EveAssets.videoFor without importing the full asset class.
String _videoFor(EvePresenceState state, VideoQuality quality) {
  const base = 'assets/3d/';
  final low = quality == VideoQuality.low;
  return switch (state) {
    EvePresenceState.idle => '${base}eve-${low ? 'idle-360' : 'idle'}.mp4',
    EvePresenceState.listening =>
      '${base}eve-${low ? 'listening-360' : 'listening'}.mp4',
    EvePresenceState.thinking =>
      '${base}eve-${low ? 'thinking-360' : 'thinking'}.mp4',
  };
}
