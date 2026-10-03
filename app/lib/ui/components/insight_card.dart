import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';
import 'slab.dart';

/// One-sentence insight with a source footnote.
///
/// Text: [body] at 16 sp. Footnote: "Based on [checkInCount] check-ins.
/// A pattern, not a diagnosis." at 14 sp with an info icon.
class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.body,
    required this.checkInCount,
  });

  final String body;
  final int checkInCount;

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
        ],
      ),
    );
  }
}
