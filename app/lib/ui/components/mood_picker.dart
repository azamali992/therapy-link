import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'moon_glyph.dart';

/// The five mood options in order (semantic labels, no embedded newlines).
const _kLabels = ['Bahut bura', 'Theek nahi', 'Theek hoon', 'Acha', 'Zabardast'];

/// Display label for the picker: breaks two-word labels at the space so each
/// option column is only as wide as its longest single word (≈ CSS `min-content`).
/// Single-word labels like "Acha" and "Zabardast" are returned unchanged.
String _pickerLabel(String label) => label.replaceFirst(' ', '\n');
const _kPhases = [
  MoonPhase.newMoon,
  MoonPhase.crescent,
  MoonPhase.half,
  MoonPhase.gibbous,
  MoonPhase.full,
];

/// Summary view-model produced when the picker folds.
class MoodSummary {
  const MoodSummary({
    required this.valence,
    required this.savedAt,
  });

  /// 0 = hardest … 4 = best.
  final int valence;
  final DateTime savedAt;
}

/// Mood check-in picker with fold-to-summary behaviour.
///
/// On first tap the five moons + labels are shown. 450 ms after a tap the row
/// folds to a single summary line: moon + label + timestamp + "Change" link.
/// No confirm step, no loading state.
///
/// Callbacks:
/// - [onSelected] fires immediately on tap (valence 0–4).
/// - [onFolded] fires after the fold animation completes.
///
/// [summary] pre-populates the folded state (pass a saved check-in on reload).
/// [showScaleEnds] controls the "Empty moon: hardest / Full: best" hint row;
/// hide after three logged check-ins.
class MoodPicker extends StatefulWidget {
  const MoodPicker({
    super.key,
    this.summary,
    this.showScaleEnds = true,
    this.onSelected,
    this.onFolded,
    this.onChange,
  });

  final MoodSummary? summary;
  final bool showScaleEnds;
  final ValueChanged<int>? onSelected;

  /// Called after the fold animation completes.
  final ValueChanged<MoodSummary>? onFolded;

  /// Called when the user taps "Change" in the summary line.
  final VoidCallback? onChange;

  @override
  State<MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends State<MoodPicker>
    with TickerProviderStateMixin {
  late AnimationController _foldCtrl;
  late Animation<double> _foldAnim;
  late AnimationController _summaryCtrl;
  late Animation<double> _summaryFade;
  late Animation<Offset> _summarySlide;

  int? _selected;
  bool _folded = false;
  MoodSummary? _summary;

  @override
  void initState() {
    super.initState();
    _foldCtrl = AnimationController(
        vsync: this, duration: Jugnu.motionFold);
    _foldAnim = CurvedAnimation(parent: _foldCtrl, curve: Jugnu.curveEaseOut);

    _summaryCtrl = AnimationController(
        vsync: this, duration: Jugnu.motionSummaryIn);
    _summaryFade =
        Tween<double>(begin: 0, end: 1).animate(_summaryCtrl);
    _summarySlide = Tween<Offset>(
            begin: const Offset(0, 4 / 24), end: Offset.zero)
        .animate(CurvedAnimation(parent: _summaryCtrl, curve: Jugnu.curveEaseOut));

    if (widget.summary != null) {
      _summary = widget.summary;
      _selected = widget.summary!.valence;
      _folded = true;
      _foldCtrl.value = 1.0;
      _summaryCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _foldCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTap(int valence) async {
    if (_folded) return;
    setState(() => _selected = valence);
    widget.onSelected?.call(valence);

    // Honour reduce-motion: skip 450 ms hold + fold animation.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      final now = DateTime.now();
      setState(() {
        _folded = true;
        _summary = MoodSummary(valence: valence, savedAt: now);
        _foldCtrl.value = 1.0;
        _summaryCtrl.value = 1.0;
      });
      widget.onFolded?.call(_summary!);
    } else {
      await Future.delayed(Jugnu.motionFoldHold);
      if (!mounted) return;
      await _foldCtrl.forward();
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _folded = true;
        _summary = MoodSummary(valence: valence, savedAt: now);
      });
      await _summaryCtrl.forward();
      if (!mounted) return;
      widget.onFolded?.call(_summary!);
    }
  }

  void _onChange() {
    setState(() {
      _folded = false;
      _foldCtrl.value = 0;
      _summaryCtrl.value = 0;
    });
    widget.onChange?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Picker row (collapses to 0 height when folded)
        SizeTransition(
          sizeFactor: ReverseAnimation(_foldAnim),
          child: Column(
            children: [
              Semantics(
                label: 'Mood check-in, radio group',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  // Top-align so every moon sits on the same baseline regardless
                  // of whether the label below it is one line or two.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(5, (i) => _MoodOption(
                    phase: _kPhases[i],
                    label: _kLabels[i],
                    selected: _selected == i,
                    onTap: () => _onTap(i),
                  )),
                ),
              ),
              if (widget.showScaleEnds) ...[
                const SizedBox(height: Jugnu.s4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Empty moon: hardest',
                        style: text.bodyMedium?.copyWith(color: colors.ink2)),
                    Text('Full: best',
                        style: text.bodyMedium?.copyWith(color: colors.ink2)),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Summary line (appears after fold)
        if (_folded && _summary != null)
          FadeTransition(
            opacity: _summaryFade,
            child: SlideTransition(
              position: _summarySlide,
              child: _SummaryLine(
                summary: _summary!,
                onChange: _onChange,
              ),
            ),
          ),
      ],
    );
  }
}

class _MoodOption extends StatelessWidget {
  const _MoodOption({
    required this.phase,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final MoonPhase phase;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final text = Theme.of(context).textTheme;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Jugnu.motionMood,
          curve: Jugnu.curveEaseOut,
          constraints: const BoxConstraints(
              minWidth: Jugnu.minTarget, minHeight: 84),
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(Jugnu.rNested),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoonGlyph(phase: phase, size: 28, selected: selected),
              const SizedBox(height: Jugnu.s8),
              // No fixed width: let the label take its intrinsic width so that
              // "Zabardast" stays on one line while two-word labels break at
              // the explicit '\n' inserted by _pickerLabel.
              Text(
                _pickerLabel(label),
                textAlign: TextAlign.center,
                style: text.labelMedium?.copyWith(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : colors.ink2,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.summary,
    required this.onChange,
  });

  final MoodSummary summary;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final text = Theme.of(context).textTheme;
    final v = summary.valence;
    final hour = summary.savedAt.hour.toString().padLeft(2, '0');
    final min = summary.savedAt.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$min';
    final amPm = summary.savedAt.hour < 12 ? 'am' : 'pm';

    return Row(
      children: [
        MoonGlyph(phase: _kPhases[v], size: 18),
        const SizedBox(width: Jugnu.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_kLabels[v], style: text.bodyLarge),
              Text(
                'Saved on this phone, $timeStr $amPm',
                style: text.labelSmall?.copyWith(color: colors.ink2),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onChange,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 0),
            child: SizedBox(
              height: Jugnu.minTarget,
              child: Center(
                child: Text(
                  'Change',
                  style: text.labelMedium?.copyWith(
                    color: colors.primaryActionText,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.primaryActionText,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
