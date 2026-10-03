import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// A Jugnu content slab.
///
/// Slabs hold content (cards, sheets, notes). Radius 24, padding 18,
/// 1 px hairline border, surface fill (6% white in dark, solid white in light).
///
/// Use [NestedCard] inside a slab for sub-cards (radius 18, 6 dp inset).
class Slab extends StatelessWidget {
  const Slab({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Jugnu.slabPadding),
    this.radius = Jugnu.rSlab,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.hair, width: 1),
      ),
      child: child,
    );
  }
}

/// A card nested inside a [Slab] — radius 18 (slab 24 minus 6 dp inset).
class NestedCard extends StatelessWidget {
  const NestedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Jugnu.rNested),
        border: Border.all(color: colors.hair, width: 1),
      ),
      child: child,
    );
  }
}
