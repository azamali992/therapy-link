import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /consent — versioned consent screen shown to all users before the app opens.
///
/// TODO(core-team): wire accept/decline to the consent-sync provider so the
/// router redirect re-evaluates and the server records the accepted version.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;

    return Screen(
      title: l.consentTitle,
      quickExit: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Tokens.s16),
          _ConsentSection(
            title: l.consentAiTitle,
            body: l.consentAiBody,
          ),
          const SizedBox(height: Tokens.s16),
          _ConsentSection(
            title: l.consentEmergencyTitle,
            body: l.consentEmergencyBody,
          ),
          const SizedBox(height: Tokens.s16),
          _ConsentSection(
            title: l.consentDataTitle,
            body: l.consentDataBody,
          ),
          const SizedBox(height: Tokens.s24),
          // Age gate
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () {
                      // TODO(core-team): record consent accepted.
                    },
                    child: Text(l.consentAccept),
                  ),
                  const SizedBox(height: Tokens.s8),
                  OutlinedButton(
                    onPressed: () {
                      // TODO(core-team): show under-18 screen.
                    },
                    child: Text(l.consentUnder18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Tokens.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                  onPressed: () {}, child: Text(l.consentTerms)),
              Text(' · ',
                  style: t.bodySmall),
              TextButton(
                  onPressed: () {}, child: Text(l.consentPrivacy)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsentSection extends StatelessWidget {
  const _ConsentSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.titleSmall),
            const SizedBox(height: Tokens.s8),
            Text(body, style: t.bodyMedium),
          ],
        ),
      ),
    );
  }
}
