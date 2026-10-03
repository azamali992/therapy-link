/// Contrast assertions for key Jugnu token pairs.
///
/// WCAG 2.2 relative luminance algorithm — pure Dart, no golden files.
/// All pairs must pass AA (>= 4.5:1 for normal text, >= 3.0:1 for non-text).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:therapylink/app/theme/tokens.dart';

void main() {
  group('Contrast: dark mode', () {
    test('ink on night ground >= 7:1 (AAA)', () {
      _assertContrast(Jugnu.ink, Jugnu.night, 7.0, 'ink on night');
    });

    test('ink on plum ground >= 7:1 (AAA)', () {
      _assertContrast(Jugnu.ink, Jugnu.plum, 7.0, 'ink on plum');
    });

    test('action-text #FF6EB4 on night >= 4.5:1 (AA)', () {
      _assertContrast(
          Jugnu.actionText, Jugnu.night, 4.5, 'actionText on night');
    });

    test('onAction #16061C on action #F23598 >= 4.5:1 (AA)', () {
      _assertContrast(
          Jugnu.onAction, Jugnu.action, 4.5, 'onAction on action');
    });

    test('eve #B48BFF on night >= 4.5:1 (AA)', () {
      _assertContrast(Jugnu.eve, Jugnu.night, 4.5, 'eve on night');
    });

    test('safe #89F336 on night >= 7:1 (AAA)', () {
      _assertContrast(Jugnu.safe, Jugnu.night, 7.0, 'safe on night');
    });

    test('navy on paper (help) >= 7:1 (AAA)', () {
      _assertContrast(Jugnu.navy, Jugnu.paper, 7.0, 'navy on paper');
    });
  });

  group('Contrast: light mode', () {
    test('navy ink on groundLightTop >= 7:1 (AAA)', () {
      _assertContrast(
          Jugnu.navy, Jugnu.groundLightTop, 7.0, 'navy on groundLightTop');
    });

    test('white on actionLight #B80F66 >= 4.5:1 (AA)', () {
      _assertContrast(
          Colors.white, Jugnu.actionLight, 4.5, 'white on actionLight');
    });

    test('paper on navy (help in light) >= 7:1 (AAA)', () {
      _assertContrast(Jugnu.paper, Jugnu.navy, 7.0, 'paper on navy');
    });

    test('eveLight #6E29FF on groundLightTop >= 4.5:1 (AA)', () {
      _assertContrast(
          Jugnu.eveLight, Jugnu.groundLightTop, 4.5, 'eveLight on groundLightTop');
    });

    test('safeTextLight #2B7A0E on white >= 4.5:1 (AA)', () {
      _assertContrast(
          Jugnu.safeTextLight, Colors.white, 4.5, 'safeTextLight on white');
    });
  });

  group('Contrast: JugnuColors extension', () {
    test('dark: onHelpSurface on helpSurface >= 7:1', () {
      const ext = JugnuColors.dark;
      _assertContrast(ext.onHelpSurface, ext.helpSurface, 7.0,
          'dark onHelpSurface on helpSurface');
    });

    test('light: onHelpSurface on helpSurface >= 7:1', () {
      const ext = JugnuColors.light;
      _assertContrast(ext.onHelpSurface, ext.helpSurface, 7.0,
          'light onHelpSurface on helpSurface');
    });

    test('dark: evePresence on night ground >= 4.5:1', () {
      const ext = JugnuColors.dark;
      _assertContrast(ext.evePresence, Jugnu.night, 4.5,
          'evePresence on dark ground (approx night)');
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────

/// Extract RGBA channels from a [Color] in [0.0, 1.0] range.
(double r, double g, double b, double a) _channels(Color c) {
  // Color.r/g/b are in [0.0, 1.0] in Flutter 3.10+.
  // For older APIs use value-based extraction as a fallback.
  return (c.r, c.g, c.b, c.a);
}

/// WCAG 2.2 relative luminance.
double _luminance(Color c) {
  final (r, g, b, _) = _channels(c);
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

/// Alpha-composite [fg] over [bg] (ignores bg alpha, assumes opaque bg).
Color _flatten(Color fg, Color bg) {
  final (fr, fg_, fb, fa) = _channels(fg);
  final (br, bg_, bb, _) = _channels(bg);
  if (fa >= 1.0) return fg;
  return Color.fromARGB(
    255,
    ((fr * fa + br * (1.0 - fa)) * 255).round().clamp(0, 255),
    ((fg_ * fa + bg_ * (1.0 - fa)) * 255).round().clamp(0, 255),
    ((fb * fa + bb * (1.0 - fa)) * 255).round().clamp(0, 255),
  );
}

void _assertContrast(
  Color foreground,
  Color background,
  double minRatio,
  String pairName,
) {
  final fg = _flatten(foreground, background);
  final l1 = _luminance(fg);
  final l2 = _luminance(background);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  final ratio = (lighter + 0.05) / (darker + 0.05);

  expect(
    ratio,
    greaterThanOrEqualTo(minRatio),
    reason: '$pairName: contrast ${ratio.toStringAsFixed(2)}:1, '
        'expected >= ${minRatio.toStringAsFixed(1)}:1',
  );
}
