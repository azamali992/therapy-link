import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /you/care — add a clinician by invite code, view/remove linked clinicians.
///
/// TODO(core-team): wire to /care/links and /me/clinician API endpoints.
class CareScreen extends StatelessWidget {
  const CareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.careTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyState(
            title: l.careEmptyTitle,
            body: l.careEmptyBody,
          ),
          const SizedBox(height: Tokens.s24),
          TextFormField(
            decoration: InputDecoration(
              labelText: l.careInvite,
              hintText: l.careInviteHint,
            ),
          ),
          const SizedBox(height: Tokens.s12),
          FilledButton(
            onPressed: () {
              // TODO(core-team): link clinician by invite code.
            },
            child: Text(l.careInvite),
          ),
        ],
      ),
    );
  }
}
