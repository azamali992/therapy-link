import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/me_provider.dart';
import '../../core/auth/auth_providers.dart';
import '../shared/widgets.dart';
import 'account_actions.dart';

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(meProvider).value;
    final user = ref.watch(authStateProvider).value;
    final email = user?.email;
    String? nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    final name = nonEmpty(me?.displayName) ?? nonEmpty(user?.displayName) ?? nonEmpty(email?.split('@').first) ?? '';
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Screen(
      title: l.youTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Tokens.s8),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                foregroundColor: scheme.primary,
                child: Text(initial, style: t.titleLarge?.copyWith(color: scheme.primary)),
              ),
              const SizedBox(width: Tokens.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: t.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (email != null) Text(email, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.s24),
          RowTile(title: l.youCare, subtitle: l.youCareSub, leading: Icons.groups_outlined, onTap: () => context.push('/you/care')),
          const Divider(),
          RowTile(title: l.youSettings, leading: Icons.tune_rounded, onTap: () => context.push('/you/settings')),
          const Divider(),
          RowTile(title: l.getHelpNow, subtitle: l.youHelpSub, leading: Icons.favorite_outline_rounded, onTap: () => showCrisisSheet(context)),
          const Divider(),
          RowTile(
            title: l.youClinician,
            subtitle: l.youClinicianSub,
            leading: Icons.medical_services_outlined,
            onTap: () async {
              final ok = await confirmDestructive(context, title: l.clinicianConfirmTitle, body: l.clinicianConfirmBody, action: l.clinicianConfirmAction);
              if (ok && context.mounted) context.push('/you/clinician');
            },
          ),
          const Divider(),
          SectionTitle(l.youDataTitle),
          Text(l.youDataBody, style: t.bodyMedium),
          const SizedBox(height: Tokens.s12),
          RowTile(title: l.accessLogTitle, subtitle: l.accessLogSub, leading: Icons.visibility_outlined, onTap: () => context.push('/you/access-log')),
          const Divider(),
          RowTile(title: l.youExport, subtitle: l.youExportSub, leading: Icons.download_outlined, onTap: () => downloadMyData(context, ref)),
          const Divider(),
          RowTile(title: l.youDeleteChats, subtitle: l.youDeleteChatsSub, leading: Icons.delete_sweep_outlined, onTap: () => deleteChatsWithConfirm(context, ref)),
          const Divider(),
          RowTile(title: l.youDeleteAccount, subtitle: l.youDeleteAccountSub, leading: Icons.person_remove_outlined, onTap: () => deleteAccountWithConfirm(context, ref)),
          const SizedBox(height: Tokens.s32),
          OutlinedButton.icon(
            onPressed: () => signOutWithConfirm(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l.signOut),
          ),
        ],
      ),
    );
  }
}
