import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

// ── Eve message (unboxed) ─────────────────────────────────────────────────

/// An unboxed message from Eve.
///
/// Shows a 20 dp Eve mark + "Eve" label in [evePresence] on the first message
/// of a group ([showHeader] = true). Body text is 16 sp, max 92% width.
///
/// Semantics: labelled "Eve said: [text]".
class EveMessage extends StatelessWidget {
  const EveMessage({
    super.key,
    required this.text,
    this.showHeader = false,
  });

  final String text;

  /// Set true for the first message in a consecutive Eve group.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Eve said: $text',
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                Row(
                  children: [
                    _EveMark(size: 20),
                    const SizedBox(width: Jugnu.s8),
                    Text(
                      'Eve',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.evePresence,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                text,
                style: textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 20 dp Eve presence mark: a disc coloured with the eve palette.
class _EveMark extends StatelessWidget {
  const _EveMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    // In light mode the eve mark sits on a dark disc (eve renders on dark ground).
    const discColor = Color(0xFF1E1F2D);

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: discColor,
      ),
      child: Center(
        child: Container(
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.evePresence,
          ),
        ),
      ),
    );
  }
}

// ── User message (raised slab bubble) ────────────────────────────────────

/// A user message in a raised slab.
///
/// Radius 24 on all corners, 8 dp on the bottom-right "speech corner".
/// Max 82% width.
class MyMessage extends StatelessWidget {
  const MyMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(Jugnu.rSlab),
              topRight: Radius.circular(Jugnu.rSlab),
              bottomLeft: Radius.circular(Jugnu.rSlab),
              bottomRight: Radius.circular(Jugnu.rSpeech),
            ),
          ),
          child: Text(text, style: textTheme.bodyLarge),
        ),
      ),
    );
  }
}

// ── Thinking indicator ────────────────────────────────────────────────────

/// "Eve soch rahi hai" thinking row — shown while Eve generates a reply.
///
/// 20 dp Eve mark + text in [evePresence] with an opacity pulse (800 ms).
/// Under reduced motion: text only, no pulse.
class ThinkingLine extends StatefulWidget {
  const ThinkingLine({super.key});

  @override
  State<ThinkingLine> createState() => _ThinkingLineState();
}

class _ThinkingLineState extends State<ThinkingLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Jugnu.motionThinkingPulse,
    );
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final textWidget = Text(
      'Eve soch rahi hai…',
      style: textTheme.bodyMedium?.copyWith(color: colors.evePresence),
    );

    return Row(
      children: [
        _EveMark(size: 20),
        const SizedBox(width: Jugnu.s8),
        if (reduceMotion)
          textWidget
        else
          FadeTransition(opacity: _opacity, child: textWidget),
      ],
    );
  }
}
