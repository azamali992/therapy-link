import 'dart:math' as math;

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

    // Clip to circle so the inner ellipse (height == size.height) can't
    // protrude past the top/bottom of the ring.
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Inner ellipse matching the CSS `radial-gradient(ellipse 34% 50% …)`:
    //   horizontal semi-axis = 34 % of width, vertical semi-axis = 50 % of height.
    final innerEllipseRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: size.width * 0.68,   // 2 × 34 %
      height: size.height,         // 2 × 50 %
    );

    switch (phase) {
      case MoonPhase.crescent:
        // Right semicircle minus the inner ellipse → thin right-edge crescent.
        final rightHalf = _rightHalfPath(Offset(cx, cy), r);
        final ellipse = Path()..addOval(innerEllipseRect);
        canvas.drawPath(
            Path.combine(PathOperation.difference, rightHalf, ellipse),
            fillPaint);
      case MoonPhase.half:
        // Right semicircle only.
        canvas.drawPath(_rightHalfPath(Offset(cx, cy), r), fillPaint);
      case MoonPhase.gibbous:
        // Right semicircle union inner ellipse → more-than-half lit area.
        final rightHalf = _rightHalfPath(Offset(cx, cy), r);
        final ellipse = Path()..addOval(innerEllipseRect);
        canvas.drawPath(
            Path.combine(PathOperation.union, rightHalf, ellipse),
            fillPaint);
      case MoonPhase.full:
        canvas.drawCircle(Offset(cx, cy), r, fillPaint);
      case MoonPhase.newMoon:
        break;
    }

    canvas.restore();
  }

  /// Right semicircle as a closed path (from top, sweeping clockwise 180°).
  Path _rightHalfPath(Offset center, double r) {
    return Path()
      ..moveTo(center.dx, center.dy - r)
      ..arcTo(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        math.pi,
        false,
      )
      ..close(); // straight line from bottom back to top, forming the diameter chord
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.phase != phase || old.fill != fill || old.ring != ring;
}
