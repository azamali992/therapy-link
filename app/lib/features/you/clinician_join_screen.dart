import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /you/clinician — enrol as a clinician (licence verification flow).
///
/// This switches the account to clinician mode, hiding the patient tabs.
/// Shown only when the user explicitly requests it from the You tab.
///
/// TODO(core-team): wire to /clinician API endpoint and router redirect.
class ClinicianJoinScreen extends StatelessWidget {
  const ClinicianJoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.clinicianJoinTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Tokens.s16),
          Text(l.clinicianJoinBody,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Tokens.s24),
          TextFormField(
            decoration: InputDecoration(
                labelText: l.clinicianLicense),
          ),
          const SizedBox(height: Tokens.s12),
          TextFormField(
            decoration: InputDecoration(
                labelText: l.clinicianSpecialty),
          ),
          const SizedBox(height: Tokens.s24),
          FilledButton(
            onPressed: () {
              // TODO(core-team): submit licence and switch role.
            },
            child: Text(l.clinicianJoinAction),
          ),
          const SizedBox(height: Tokens.s12),
          OutlinedButton(
            onPressed: () {
              // TODO(core-team): go back / cancel.
            },
            child: Text(l.clinicianUsePatient),
          ),
        ],
      ),
    );
  }
}
