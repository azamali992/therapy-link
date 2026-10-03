import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /welcome — first screen new users see.
///
/// Shows the value proposition and a language preference picker. "Get help now"
/// is visible here so help is reachable before sign-in.
///
/// TODO(core-team): add language-selection state (shared_preferences) and
/// navigation to /consent once the user has chosen a language.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Screen(
      title: l.appName,
      quickExit: false, // No quick exit needed before any data is entered.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Tokens.s48),
          Text(l.welcomeTitle,
              style: t.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: Tokens.s16),
          Text(l.welcomeBody,
              style: t.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: Tokens.s32),
          // Language tiles
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(l.welcomeEnglish),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16),
                  onTap: () {},
                ),
                Divider(height: 1,
                    color: scheme.onSurface.withValues(alpha: 0.08)),
                ListTile(
                  title: Text(l.welcomeRomanUrdu),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.s24),
          Text(l.welcomePointPrivate,
              style: t.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: Tokens.s8),
          Text(l.welcomePointHelp,
              style: t.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
