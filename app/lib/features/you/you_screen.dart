import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets.dart';

/// /you — account and settings hub.
///
/// TODO(core-team): wire sign-out (with confirmation + local DB wipe), export
/// and delete-account actions.
class YouScreen extends StatelessWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.youTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(l.youCare),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline_rounded),
              title: Text(l.youCare),
              subtitle: Text(l.youCareSub),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go('/you/care'),
            ),
          ),
          SectionTitle(l.youSettings),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(l.youSettings),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/you/settings'),
                ),
                ListTile(
                  leading: const Icon(Icons.psychology_outlined),
                  title: Text(l.memoryTitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/you/memory'),
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(l.accessLogTitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/you/access-log'),
                ),
                ListTile(
                  leading: const Icon(Icons.local_hospital_outlined),
                  title: Text(l.youClinician),
                  subtitle: Text(l.youClinicianSub),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go('/you/clinician'),
                ),
              ],
            ),
          ),
          SectionTitle(l.youDataTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.youDataBody,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
