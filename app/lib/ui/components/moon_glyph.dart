import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Moon phase index values (0 = new/empty … 4 = full).
enum MoonPhase {
  /// Phase 0: new moon (empty ring) — hardest mood (Bahut bura).
  newMoon,
  /// Phase 1: waxing crescent (right quarter visible).
  crescent,
  /// Phase 2: half moon (right half).
  half,
  /// Phase 3: waxing gibbous.
  gibbous,
  /// Phase 4: full moon.
  full,
}

/// A single moon-phase glyph or the missed-day dash.
///
/// - [size] defaults to 28 dp (mood picker) — use 18 for the week trend.
/// - [selected] draws a 2 dp action ring with 3 dp offset and scales to 1.1.
/// - [missed] draws a 12 × 2 dp flat dash instead of a moon; this must never
///   look like the new-moon phase (see DESIGN.md CRITIQUE.md).
class MoonGlyph extends StatelessWidget {
  const MoonGlyph({
    super.key,
    this.phase = MoonPhase.full,
    this.size = 28,
    this.selected = false,
    this.missed = false,
  });

  final MoonPhase phase;
  final double size;
  final bool selected;

  /// Show as a missed-day dash instead of a moon.
  final bool missed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;

    if (missed) {
      // 12 × 2 dp flat dash — smaller than any moon, never round.
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: 12,
            height: 2,
            decoration: BoxDecoration(
              color: colors.moonRing,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    }

    final scale = selected ? 1.1 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: Jugnu.motionMood,
      curve: Jugnu.curveEaseOut,
      child: Container(
        width: size,
        height: size,
        decoration: selected
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              )
            : null,
        child: Padding(
          padding: selected ? const EdgeInsets.all(3) : EdgeInsets.zero,
          child: CustomPaint(
            size: Size(selected ? size - 6 : size,
                selected ? size - 6 : size),
            painter: _MoonPainter(
              phase: phase,
              fill: colors.moonFill,
              ring: colors.moonRing,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({
    required this.phase,
    required this.fill,
    required this.ring,
  });

  final MoonPhase phase;
  final Color fill;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 0.75;

    final ringPaint = Paint()
      ..color = ring
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Ring
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);

    if (phase == MoonPhase.newMoon) return;

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    canvas.save();
    // Clip to circle boundary
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    switch (phase) {
      case MoonPhase.crescent:
        // Right quarter crescent: full right half minus a large ellipse on the left
        final path = Path();
        // Right semicircle
        path.addArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.5708, 3.1416);
        canvas.drawPath(path, fillPaint);
        // Erase most of that fill with BlendMode.clear ellipse
        final erasePaint = Paint()
          ..blendMode = BlendMode.clear;
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx - r * 0.34, cy),
                width: r * 1.36,
                height: r * 2),
            erasePaint);
      case MoonPhase.half:
        // Right half
        canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r),
            -1.5708, 3.1416, true, fillPaint);
      case MoonPhase.gibbous:
        // Full right half + left partial (gibbous)
        final path = Path();
        // Fill right half
        path.addArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r), -1.5708, 3.1416);
        canvas.drawPath(path, fillPaint);
        // Fill left partial via wide ellipse covering most of left half
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(cx - r * 0.22, cy),
                width: r * 1.44,
                height: r * 2),
            fillPaint);
      case MoonPhase.full:
        canvas.drawCircle(Offset(cx, cy), r, fillPaint);
      case MoonPhase.newMoon:
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.phase != phase || old.fill != fill || old.ring != ring;
}
