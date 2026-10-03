import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /clinic — clinician caseload (patient list).
///
/// TODO(core-team): wire to /clinician/patients API endpoint.
class CaseloadScreen extends StatelessWidget {
  const CaseloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.clinicianCaseload,
      actions: [
        IconButton(
          icon: const Icon(Icons.pending_actions_rounded),
          tooltip: l.clinicianRequests,
          onPressed: () => context.go('/clinic/requests'),
        ),
      ],
      child: EmptyState(
        title: l.clinicianEmpty,
        body: l.clinicianCodeHelp,
        action: Card(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.clinicianYourId,
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: Tokens.s8),
                Row(
                  children: [
                    Expanded(
                      child: Text('— invite code placeholder —',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO(core-team): copy invite code to clipboard.
                      },
                      child: Text(l.clinicianCopyId),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
