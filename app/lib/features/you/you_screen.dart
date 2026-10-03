import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/me_provider.dart';
import '../../core/auth/auth_providers.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/setting_row.dart';
import '../../ui/components/slab.dart';
import '../shared/widgets.dart';
import 'account_actions.dart';

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(meProvider).value;
    final user = ref.watch(authStateProvider).value;
    final email = user?.email;
    String? nonEmpty(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    final name = nonEmpty(me?.displayName) ??
        nonEmpty(user?.displayName) ??
        nonEmpty(email?.split('@').first) ??
        '';
    final initial =
        name.isEmpty ? '?' : name.characters.first.toUpperCase();

    return Screen(
      title: l.youTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Tokens.s8),

          // ── Profile slab ──────────────────────────────────────────────
          Slab(
            padding: const EdgeInsets.all(Tokens.s16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      scheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    initial,
                    style: t.titleLarge?.copyWith(color: scheme.primary),
                  ),
                ),
                const SizedBox(width: Tokens.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: t.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (email != null)
                        Text(
                          email,
                          style: t.bodyMedium
                              ?.copyWith(color: colors.ink2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tokens.s24),

          // ── Primary actions ───────────────────────────────────────────
          RowTile(
            title: l.youCare,
            subtitle: l.youCareSub,
            leading: Icons.groups_outlined,
            onTap: () => context.push('/you/care'),
          ),
          Divider(height: 1, color: colors.hair),
          RowTile(
            title: l.youSettings,
            leading: Icons.tune_rounded,
            onTap: () => context.push('/you/settings'),
          ),
          Divider(height: 1, color: colors.hair),
          RowTile(
            title: l.memoryTitle,
            leading: Icons.psychology_outlined,
            onTap: () => context.push('/you/memory'),
          ),
          Divider(height: 1, color: colors.hair),
          RowTile(
            title: l.getHelpNow,
            subtitle: l.youHelpSub,
            leading: Icons.favorite_outline_rounded,
            onTap: () => showCrisisSheet(context),
          ),
          Divider(height: 1, color: colors.hair),
          RowTile(
            title: l.youClinician,
            subtitle: l.youClinicianSub,
            leading: Icons.medical_services_outlined,
            onTap: () async {
              final ok = await confirmDestructive(
                context,
                title: l.clinicianConfirmTitle,
                body: l.clinicianConfirmBody,
                action: l.clinicianConfirmAction,
              );
              if (ok && context.mounted) context.push('/you/clinician');
            },
          ),

          // ── Where your data lives ─────────────────────────────────────
          SectionTitle(l.youDataTitle),
          Text(l.youDataBody,
              style: t.bodyMedium?.copyWith(color: colors.ink2)),
          const SizedBox(height: Tokens.s16),
          Slab(
            padding: const EdgeInsets.all(Tokens.s16),
            child: StorageRow(),
          ),
          const SizedBox(height: Tokens.s16),
          Divider(height: 1, color: colors.hair),

          RowTile(
            title: l.accessLogTitle,
            subtitle: l.accessLogSub,
            leading: Icons.visibility_outlined,
            onTap: () => context.push('/you/access-log'),
          ),
          Divider(height: 1, color: colors.hair),
          RowTile(
            title: l.youExport,
            subtitle: l.youExportSub,
            leading: Icons.download_outlined,
            onTap: () => downloadMyData(context, ref),
          ),
          Divider(height: 1, color: colors.hair),
          RowTile(
            title: l.youDeleteChats,
            subtitle: l.youDeleteChatsSub,
            leading: Icons.delete_sweep_outlined,
            onTap: () => deleteChatsWithConfirm(context, ref),
          ),
          Divider(height: 1, color: colors.hair),
          RowTile(
            title: l.youDeleteAccount,
            subtitle: l.youDeleteAccountSub,
            leading: Icons.person_remove_outlined,
            onTap: () => deleteAccountWithConfirm(context, ref),
          ),

          const SizedBox(height: Tokens.s32),
          GhostButton(
            label: l.signOut,
            onPressed: () => signOutWithConfirm(context, ref),
          ),
          const SizedBox(height: Tokens.s16),
        ],
      ),
    );
  }
}
