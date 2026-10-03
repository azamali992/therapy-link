import 'package:flutter/material.dart';

import '../shared/widgets.dart';

/// /you/access-log — shows every time a clinician accessed the user's data.
///
/// TODO(core-team): wire to /me/access-log API endpoint.
class AccessLogScreen extends StatelessWidget {
  const AccessLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.accessLogTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l.accessLogIntro,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          EmptyState(
            title: l.accessLogEmpty,
            body: '',
          ),
        ],
      ),
    );
  }
}
