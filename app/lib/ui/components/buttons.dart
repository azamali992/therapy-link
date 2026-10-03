import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';

// ── Press-scale animation mixin ──────────────────────────────────────────

/// Wraps [child] in a 0.97-scale press animation (160 ms ease-out).
/// Skipped when [MediaQuery.disableAnimations] is true (colour change only).
class _PressScaleRegion extends StatefulWidget {
  const _PressScaleRegion({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressScaleRegion> createState() => _PressScaleRegionState();
}

class _PressScaleRegionState extends State<_PressScaleRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Jugnu.motionPress,
      reverseDuration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: Jugnu.pressScale).animate(
      CurvedAnimation(parent: _ctrl, curve: Jugnu.curveEaseOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down() {
    if (!MediaQuery.disableAnimationsOf(context)) _ctrl.forward();
  }

  void _up() {
    _ctrl.reverse();
    widget.onTap();
  }

  void _cancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
          child: widget.child,
        ),
      );
}

// ── Primary button ────────────────────────────────────────────────────────

/// The one pink pill action button per screen.
///
/// Pass [showArrow] to add a nested circular arrow after the label, as used
/// on the Welcome / onboarding CTA.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showArrow = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: scheme.onPrimary);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: Jugnu.s24),
        Text(label, style: textStyle),
        if (showArrow) ...[
          const SizedBox(width: Jugnu.s12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.14),
            ),
            child: Icon(JugnuIcons.arrowRight,
                size: 20, color: scheme.onPrimary),
          ),
          const SizedBox(width: 8),
        ] else
          const SizedBox(width: Jugnu.s24),
      ],
    );

    return _PressScaleRegion(
      onTap: onPressed,
      child: Container(
        height: Jugnu.primaryButtonHeight,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(child: content),
      ),
    );
  }
}

// ── Ghost button ──────────────────────────────────────────────────────────

/// Outlined ghost button (strong hairline, ink text).
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final ink = Theme.of(context).colorScheme.onSurface;
    final textStyle =
        Theme.of(context).textTheme.labelLarge?.copyWith(color: ink);

    return _PressScaleRegion(
      onTap: onPressed,
      child: Container(
        height: Jugnu.primaryButtonHeight,
        padding:
            const EdgeInsets.symmetric(horizontal: Jugnu.s24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.hairStrong, width: 1.5),
        ),
        child: Center(child: Text(label, style: textStyle)),
      ),
    );
  }
}

// ── Chip button ───────────────────────────────────────────────────────────

/// Outlined pill chip. 48 dp minimum height, 14–15 sp Atkinson 600.
/// Used for quick-reply options above the composer.
class ChipButton extends StatelessWidget {
  const ChipButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// When true, the chip is highlighted with the action-text colour.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final ink = Theme.of(context).colorScheme.onSurface;
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? colors.primaryActionText : ink,
          fontWeight: FontWeight.w600,
        );

    return _PressScaleRegion(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: Jugnu.minTarget),
        padding: const EdgeInsets.symmetric(
            horizontal: Jugnu.s16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? colors.primaryActionText : colors.hairStrong,
            width: 1.5,
          ),
        ),
        child: Center(child: Text(label, style: textStyle)),
      ),
    );
  }
}
