import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/me_provider.dart';
import '../shared/widgets.dart';

/// /you/clinician — enrol as a clinician (licence verification flow).
///
/// Submits the licence to the server; on success the Me.role changes to clinician
/// and the router redirect immediately sends the user to /clinic.
class ClinicianJoinScreen extends ConsumerStatefulWidget {
  const ClinicianJoinScreen({super.key});

  @override
  ConsumerState<ClinicianJoinScreen> createState() => _ClinicianJoinScreenState();
}

class _ClinicianJoinScreenState extends ConsumerState<ClinicianJoinScreen> {
  final _license = TextEditingController();
  final _specialty = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _license.dispose();
    _specialty.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final licenseText = _license.text.trim();
    if (licenseText.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).becomeClinician(
        licenseNo: licenseText,
        specialty: _specialty.text.trim().isEmpty ? null : _specialty.text.trim(),
      );
      // Invalidate me so the router picks up the new role and redirects to /clinic.
      ref.invalidate(meProvider);
      if (mounted) context.go('/clinic');
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = context.l10n.errorGeneric;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.clinicianJoinTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Tokens.s16),
          Text(l.clinicianJoinBody, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Tokens.s24),
          TextFormField(
            controller: _license,
            decoration: InputDecoration(labelText: l.clinicianLicense),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
          ),
          const SizedBox(height: Tokens.s12),
          TextFormField(
            controller: _specialty,
            decoration: InputDecoration(labelText: l.clinicianSpecialty),
            textCapitalization: TextCapitalization.words,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Tokens.s12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: Tokens.s24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.clinicianJoinAction),
          ),
          const SizedBox(height: Tokens.s12),
          OutlinedButton(
            onPressed: _busy ? null : () => context.pop(),
            child: Text(l.clinicianUsePatient),
          ),
        ],
      ),
    );
  }
}
