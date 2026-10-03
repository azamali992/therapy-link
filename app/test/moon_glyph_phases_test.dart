import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/app/theme/theme.dart' show buildTheme;
import 'package:therapylink/ui/components/moon_glyph.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Renders a [MoonGlyph] at [glyphSize] logical pixels inside a 200×200 canvas,
/// captures it via [RepaintBoundary], and returns the fraction of pixels that
/// are "lit" — i.e. not nearly identical to the scaffold background colour.
///
/// "Lit" is detected by brightness: the dark-theme moon fill is pale/white,
/// while the scaffold background is very dark. Any pixel with brightness > 80
/// (out of 255) counts as lit.
Future<double> _litFraction(
  WidgetTester tester,
  MoonPhase phase, {
  double glyphSize = 60,
}) async {
  final repaintKey = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: glyphSize,
              height: glyphSize,
              child: MoonGlyph(phase: phase, size: glyphSize),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  // toImage() and toByteData() must be awaited via tester.runAsync so the real
  // async work (rasterisation on the raster thread) completes in widget tests.
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  if (image == null) return 0;
  final byteData =
      await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
  if (byteData == null) return 0;

  final width = image.width;
  final height = image.height;
  int lit = 0;
  final total = width * height;

  for (int i = 0; i < total; i++) {
    final offset = i * 4;
    final r = byteData.getUint8(offset);
    final g = byteData.getUint8(offset + 1);
    final b = byteData.getUint8(offset + 2);
    // Luminance — moon fill is bright, background is near-black.
    final brightness = r * 0.299 + g * 0.587 + b * 0.114;
    if (brightness > 80) lit++;
  }

  return lit / total;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MoonGlyph – phase pixel coverage', () {
    testWidgets('newMoon has only ring pixels lit (< 15 %)',
        (tester) async {
      final f = await _litFraction(tester, MoonPhase.newMoon);
      // A 1.5 dp ring stroke on a 60 px bounding box covers ~7–8 % of pixels.
      // No fill should be present, so expect well under 15 %.
      expect(f, lessThan(0.15),
          reason: 'newMoon got $f; should be < 0.15 (ring only, no fill)');
    });

    testWidgets('crescent is a thin sliver (10 %–35 % coverage)',
        (tester) async {
      final f = await _litFraction(tester, MoonPhase.crescent);
      // Must be visibly more lit than the newMoon ring (~8 %) but much less
      // than a half moon.
      expect(f, greaterThan(0.10),
          reason: 'crescent got $f; should be visibly lit (> 0.10)');
      expect(f, lessThan(0.35),
          reason: 'crescent got $f; should be much less than half (< 0.35)');
    });

    testWidgets('half moon covers roughly the right half (30 %–60 %)',
        (tester) async {
      final f = await _litFraction(tester, MoonPhase.half);
      expect(f, greaterThan(0.30),
          reason: 'half got $f; should be at least 30 %');
      expect(f, lessThan(0.60),
          reason: 'half got $f; should be at most 60 %');
    });

    testWidgets('gibbous is more than half lit (55 %–90 %)',
        (tester) async {
      final f = await _litFraction(tester, MoonPhase.gibbous);
      expect(f, greaterThan(0.55),
          reason: 'gibbous got $f; should be more than half (> 0.55)');
      expect(f, lessThan(0.90),
          reason: 'gibbous got $f; must leave a dark edge (< 0.90)');
    });

    testWidgets('full moon is mostly lit (> 70 %)',
        (tester) async {
      final f = await _litFraction(tester, MoonPhase.full);
      expect(f, greaterThan(0.70),
          reason: 'full got $f; should be mostly lit (> 0.70)');
    });
  });

  group('MoonGlyph – phase ordering', () {
    testWidgets('lit fractions increase monotonically newMoon → full',
        (tester) async {
      final phases = [
        MoonPhase.newMoon,
        MoonPhase.crescent,
        MoonPhase.half,
        MoonPhase.gibbous,
        MoonPhase.full,
      ];

      double prev = -1;
      for (final phase in phases) {
        final f = await _litFraction(tester, phase);
        expect(f, greaterThan(prev),
            reason:
                '$phase (f=$f) must be greater than previous phase (f=$prev)');
        prev = f;
      }
    });
  });
}
