/// EveHalo — the violet→pink radial gradient halo behind Eve.
///
/// Animation:
///   idle / listening  → breathe: gently expands and contracts on a 6 s cycle.
///   thinking          → pulse: sharp pulsation on a 1.6 s cycle.
///   reduced motion    → static; no animation.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Which animation pattern the halo uses.
enum HaloMode {
  /// Gentle breathing, 6 s cycle (idle and listening).
  breathe,

  /// Quick pulse, 1.6 s cycle (thinking).
  pulse,
}

/// The CSS-like violet→pink radial gradient halo that sits behind Eve.
///
/// [size] is the overall bounding box (the halo draws slightly larger than Eve
/// so it bleeds out from behind her).
///
/// [mode] switches between the breathing (6 s) and pulsing (1.6 s) patterns.
///
/// When [reducedMotion] is true the halo renders as a static gradient — no
/// scale animation at all. Callers should pass the result of
/// `MediaQuery.disableAnimationsOf(context)` here.
class EveHalo extends StatefulWidget {
  const EveHalo({
    super.key,
    required this.size,
    this.mode = HaloMode.breathe,
    this.reducedMotion = false,
  });

  final double size;
  final HaloMode mode;
  final bool reducedMotion;

  @override
  State<EveHalo> createState() => _EveHaloState();
}

class _EveHaloState extends State<EveHalo> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _phase = 0;
  Duration _lastTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTime).inMicroseconds / 1e6;
    _lastTime = elapsed;
    setState(() {
      _phase = (_phase + dt) % _period;
    });
  }

  /// Period in seconds.
  double get _period => widget.mode == HaloMode.pulse ? 1.6 : 6.0;

  /// Current scale multiplier for the halo.
  double get _scale {
    if (widget.reducedMotion) return 1.0;
    final t = _phase / _period;
    if (widget.mode == HaloMode.pulse) {
      // Sharp gaussian pulse: peak at t=0, falls off quickly, base stays visible.
      return 1.0 + 0.12 * math.exp(-math.pow((t - 0.0) * 4.0, 2));
    } else {
      // Smooth sine breathe: 0 → 1 → 0 over the period.
      return 1.0 + 0.08 * math.sin(math.pi * 2 * t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final haloSize = widget.size * 1.55;
    return Transform.scale(
      scale: _scale,
      child: CustomPaint(
        size: Size.square(haloSize),
        painter: _HaloPainter(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _HaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Outer violet ring.
    final outer = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x00000000),
          Color(0x158A4FFF), // violet, very faint
          Color(0x358A4FFF), // violet
          Color(0x50A36FFF), // violet-soft peak
          Color(0x40F23598), // pink
          Color(0x20F23598), // pink fading
          Color(0x00000000),
        ],
        stops: const [0.0, 0.25, 0.45, 0.58, 0.72, 0.86, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, outer);
  }

  @override
  bool shouldRepaint(_HaloPainter old) => false;
}
