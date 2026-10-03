import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'moon_glyph.dart';

/// One column in the seven-day trend.
class WeekDay {
  const WeekDay({
    required this.label,
    required this.isToday,
    this.valence,
  });

  /// Day label — e.g. "Mon", "Tue".
  final String label;
  final bool isToday;

  /// 0–4 if a check-in was logged; null if the day was missed or is future.
  final int? valence;
}

/// Phases corresponding to valence values 0–4.
const _kPhases = [
  MoonPhase.newMoon,
  MoonPhase.crescent,
  MoonPhase.half,
  MoonPhase.gibbous,
  MoonPhase.full,
];

/// Seven-day mood trend: moons placed by value, joined by a polyline.
/// Missed days show a flat dash, never a moon. The line breaks around gaps.
///
/// Height is fixed at 104 dp to match the concept page.
///
/// Semantics: a single label reads the entire week aloud.
class WeekTrend extends StatelessWidget {
  const WeekTrend({
    super.key,
    required this.days,
  }) : assert(days.length == 7);

  final List<WeekDay> days;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final text = Theme.of(context).textTheme;
    final ink = Theme.of(context).colorScheme.onSurface;

    // Build a semantic description of the whole week.
    final semanticLabel = _buildSemanticLabel();

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: 104,
        child: CustomMultiChildLayout(
          delegate: _WeekLayout(),
          children: [
            LayoutId(
              id: '_polyline',
              child: CustomPaint(
                painter: _PolylinePainter(
                  days: days,
                  stroke: colors.moonRing,
                ),
              ),
            ),
            for (int i = 0; i < 7; i++)
              LayoutId(
                id: 'col_$i',
                child: _DayColumn(
                  day: days[i],
                  colors: colors,
                  text: text,
                  ink: ink,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildSemanticLabel() {
    final buf = StringBuffer('Week mood: ');
    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      buf.write(d.label);
      buf.write(' ');
      if (d.valence == null) {
        buf.write('no entry');
      } else {
        const names = ['hardest', 'not great', 'okay', 'good', 'best'];
        buf.write(names[d.valence!]);
      }
      if (i < days.length - 1) buf.write(', ');
    }
    return buf.toString();
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.colors,
    required this.text,
    required this.ink,
  });

  final WeekDay day;
  final JugnuColors colors;
  final TextTheme text;
  final Color ink;

  /// Maps valence 0–4 to a Y position in [0..86] dp (top of the 86 dp chart
  /// area); full mood = top (y=0), empty = bottom (y=86).
  static double yForValence(int v) => (4 - v) / 4 * 86;

  @override
  Widget build(BuildContext context) {
    final hasEntry = day.valence != null;
    final y = hasEntry ? yForValence(day.valence!) : 43.0; // centre for missed

    return Stack(
      children: [
        // Moon or missed dash
        Positioned(
          top: y - 9, // moon radius = 9 dp (18/2)
          left: 0,
          right: 0,
          child: Center(
            child: hasEntry
                ? MoonGlyph(phase: _kPhases[day.valence!], size: 18)
                : const MoonGlyph(missed: true, size: 18),
          ),
        ),
        // Day label at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Text(
            day.label,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: day.isToday ? ink : colors.ink2,
              fontWeight: day.isToday ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final colW = size.width / 7;
    final chartH = 86.0;

    layoutChild('_polyline', BoxConstraints.expand(
        width: size.width, height: chartH));
    positionChild('_polyline', Offset.zero);

    for (int i = 0; i < 7; i++) {
      final id = 'col_$i';
      layoutChild(id, BoxConstraints.tightFor(width: colW, height: size.height));
      positionChild(id, Offset(i * colW, 0));
    }
  }

  @override
  bool shouldRelayout(_WeekLayout old) => false;
}

class _PolylinePainter extends CustomPainter {
  _PolylinePainter({required this.days, required this.stroke});

  final List<WeekDay> days;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final colW = size.width / 7;

    // Build line segments; break around missed days.
    List<Offset> segment = [];

    void flushSegment() {
      if (segment.length >= 2) {
        final path = Path()..moveTo(segment[0].dx, segment[0].dy);
        for (int k = 1; k < segment.length; k++) {
          path.lineTo(segment[k].dx, segment[k].dy);
        }
        canvas.drawPath(path, paint);
      }
      segment = [];
    }

    for (int i = 0; i < days.length; i++) {
      final v = days[i].valence;
      if (v == null) {
        flushSegment();
      } else {
        final x = colW * i + colW / 2;
        final y = _DayColumn.yForValence(v);
        segment.add(Offset(x, y));
      }
    }
    flushSegment();
  }

  @override
  bool shouldRepaint(_PolylinePainter old) =>
      old.days != days || old.stroke != stroke;
}
