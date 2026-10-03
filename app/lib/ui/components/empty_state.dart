import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Generic empty-state widget.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Jugnu.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.ink3),
            const SizedBox(height: Jugnu.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: Jugnu.s8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colors.ink2),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Jugnu.s24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
