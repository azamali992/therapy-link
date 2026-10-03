import 'package:flutter/material.dart';

import '../shared/widgets.dart';

/// /clinic/patients/:id — individual patient overview.
///
/// [uid] is the patient's Firebase UID.
///
/// TODO(core-team): wire to /clinician/patients/:uid API endpoint; show
/// consented sections only (check-ins, mood trend, journal).
class PatientScreen extends StatelessWidget {
  const PatientScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.clinicianCaseload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text('Patient UID: $uid',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          EmptyState(
            title: l.clinicianNoConsent,
            body: l.clinicianCodeHelp,
          ),
        ],
      ),
    );
  }
}
