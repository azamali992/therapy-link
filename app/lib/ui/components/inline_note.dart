import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../jugnu_icons.dart';

/// Inline privacy or informational note inside the chat.
///
/// Surface nested slab (radius 18), 14 sp text. When [isProtected] is true
/// the icon is tinted [safeText] and indicates a protection is active.
///
/// Never claim Eve runs on the phone.
class InlineNote extends StatelessWidget {
  const InlineNote({
    super.key,
    required this.text,
    this.isProtected = false,
  });

  final String text;

  /// True for notes that describe an active privacy protection
  /// (icon tinted in [safeText]).
  final bool isProtected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;

    final iconColor = isProtected ? colors.safeText : colors.ink3;
    final icon = isProtected ? JugnuIcons.shieldCheck : JugnuIcons.info;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Jugnu.rNested),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(color: colors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
