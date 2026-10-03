import 'package:flutter/material.dart';

import '../shared/widgets.dart';

/// /clinic/requests — pending patient link requests.
///
/// TODO(core-team): wire to /clinician/requests API endpoint.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.clinicianRequests,
      child: EmptyState(
        title: l.clinicianRequestsEmpty,
        body: l.clinicianRequestsHelp,
      ),
    );
  }
}
