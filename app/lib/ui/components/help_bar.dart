import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';

/// Persistent "help is here" bar shown above the composer during a crisis
/// session. Cannot be dismissed.
///
/// Uses [helpSurface] colours. No animation (DESIGN.md: crisis UI never
/// animates).
class HelpBar extends StatelessWidget {
  const HelpBar({
    super.key,
    this.label = 'Madad yahan hai',
    required this.onGetHelp,
  });

  final String label;
  final VoidCallback onGetHelp;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colors.helpSurface,
      child: InkWell(
        onTap: onGetHelp,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Jugnu.s20, vertical: 10),
          child: Row(
            children: [
              Icon(JugnuIcons.heartFill,
                  size: 18, color: colors.onHelpSurface),
              const SizedBox(width: Jugnu.s8),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onHelpSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(JugnuIcons.chevronRight,
                  size: 18, color: colors.onHelpSurface),
            ],
          ),
        ),
      ),
    );
  }
}
