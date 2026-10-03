import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';
import 'slab.dart';

/// One-sentence insight with a source footnote and an optional action row.
///
/// Text: [body] at 16 sp. Footnote: "Based on [checkInCount] check-ins.
/// A pattern, not a diagnosis." at 14 sp with an info icon.
/// [action] is rendered below the footnote — used for an inline row-link
/// (e.g. a breathing exercise shortcut from the Today screen).
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.body,
    required this.checkInCount,
    this.action,
  });

  final String body;
  final int checkInCount;

  /// Optional widget at the bottom of the card, after the footnote.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final text = Theme.of(context).textTheme;

    return Slab(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: text.bodyLarge),
          const SizedBox(height: Jugnu.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(JugnuIcons.info,
                  size: 15, color: colors.ink2),
              const SizedBox(width: Jugnu.s8),
              Expanded(
                child: Text(
                  'Based on $checkInCount check-ins. A pattern, not a diagnosis.',
                  style: text.bodyMedium?.copyWith(color: colors.ink2),
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: Jugnu.s8),
            action!,
          ],
        ],
      ),
    );
  }
}
