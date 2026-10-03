import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/me_provider.dart';
import '../../core/api/models.dart';
import '../shared/widgets.dart';

/// Provider for the clinician's patient list. Ordered server-side by urgency.
final caseloadProvider = FutureProvider<List<CaseloadRow>>(
  (ref) => ref.watch(apiClientProvider).caseload(),
);

/// /clinic — clinician caseload (patient list).
///
/// Shows the clinician's invite code and a list of linked patients.
/// Patients are ordered by urgency (attention flags first). Tapping a patient
/// opens [PatientScreen].
class CaseloadScreen extends ConsumerStatefulWidget {
  const CaseloadScreen({super.key});

  @override
  ConsumerState<CaseloadScreen> createState() => _CaseloadScreenState();
}

class _CaseloadScreenState extends ConsumerState<CaseloadScreen> {
  bool _codeCopied = false;
  bool _rotatingCode = false;

  Future<void> _rotateCode() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.clinicianNewCode),
        content: Text(l.clinicianNewCodeBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.clinicianNewCode)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _rotatingCode = true);
    try {
      await ref.read(apiClientProvider).rotateInviteCode();
      ref.invalidate(meProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.clinicianNewCodeDone)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _rotatingCode = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(meProvider).value;
    final inviteCode = me?.inviteCode;
    final isPending = me != null && !me.clinicianVerified;

    return Screen(
      title: l.clinicianCaseload,
      help: false,
      quickExit: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.pending_actions_rounded),
          tooltip: l.clinicianRequests,
          onPressed: () => context.go('/clinic/requests'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verification-pending banner
          if (isPending) ...[
            const SizedBox(height: Tokens.s16),
            _PendingBanner(text: l.clinicianPending),
            const SizedBox(height: Tokens.s16),
          ],

          // Invite code card
          if (inviteCode != null) ...[
            const SizedBox(height: Tokens.s16),
            _InviteCodeCard(
              code: inviteCode,
              copied: _codeCopied,
              rotating: _rotatingCode,
              onCopy: () => _copyCode(inviteCode),
              onRotate: _rotateCode,
            ),
          ],

          const SizedBox(height: Tokens.s8),

          // Patient list
          ref.watch(caseloadProvider).when(
            loading: () => const SkeletonList(rows: 3),
            error: (_, _) =>
                ErrorState(onRetry: () => ref.invalidate(caseloadProvider)),
            data: (rows) {
              if (rows.isEmpty) {
                return EmptyState(
                  title: l.clinicianEmpty,
                  body: l.clinicianCodeHelp,
                );
              }
              return _PatientList(rows: rows);
            },
          ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Jugnu.rNested),
        border: Border.all(color: colors.hair),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: 20, color: colors.ink2),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Text(text,
                style: t.bodyMedium?.copyWith(color: colors.ink2)),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.code,
    required this.copied,
    required this.rotating,
    required this.onCopy,
    required this.onRotate,
  });

  final String code;
  final bool copied;
  final bool rotating;
  final VoidCallback onCopy;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(Tokens.s16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Jugnu.rSlab),
        border: Border.all(color: colors.hair),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.clinicianYourId,
              style: t.labelMedium?.copyWith(color: colors.ink2)),
          const SizedBox(height: Tokens.s8),
          Row(
            children: [
              Expanded(
                child: Text(code,
                    style: t.titleMedium?.copyWith(
                        fontFamily: 'AtkinsonHyperlegibleMono',
                        letterSpacing: 2)),
              ),
              if (rotating)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                TextButton(
                  onPressed: onCopy,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, Jugnu.minTarget),
                    padding:
                        const EdgeInsets.symmetric(horizontal: Tokens.s8),
                  ),
                  child: Text(copied ? l.clinicianCopied : l.clinicianCopyId),
                ),
                const SizedBox(width: Tokens.s4),
                IconButton(
                  tooltip: l.clinicianNewCode,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: onRotate,
                ),
              ],
            ],
          ),
          Text(l.clinicianCodeHelp,
              style: t.bodySmall?.copyWith(color: colors.ink3)),
        ],
      ),
    );
  }
}

class _PatientList extends StatelessWidget {
  const _PatientList({required this.rows});
  final List<CaseloadRow> rows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return Column(
      children: [
        for (final row in rows) ...[
          InkWell(
            onTap: () => context.go('/clinic/patients/${row.patient.uid}'),
            borderRadius: BorderRadius.circular(Tokens.rSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.s16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.patient.displayName ?? row.patient.uid,
                          style: t.titleMedium,
                        ),
                        const SizedBox(height: Tokens.s4),
                        if (!row.sharesAssessments)
                          Text(l.clinicianNotSharing,
                              style: t.bodySmall
                                  ?.copyWith(color: colors.ink2))
                        else if (row.latest.isEmpty)
                          Text(l.clinicianNoCheckins,
                              style: t.bodySmall
                                  ?.copyWith(color: colors.ink2))
                        else
                          Text(
                            row.latest
                                .map((a) =>
                                    '${instrumentTitle(context, a.instrument)}: ${a.score} ${bandLabel(context, a.band)}')
                                .join(' · '),
                            style: t.bodySmall
                                ?.copyWith(color: colors.ink2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (row.attention.isNotEmpty) ...[
                          const SizedBox(height: Tokens.s4),
                          Wrap(
                            spacing: Tokens.s4,
                            children: [
                              for (final flag in row.attention)
                                _MiniFlag(_attentionLabel(context, flag)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: colors.ink3, size: 20),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: colors.hair),
        ],
      ],
    );
  }

  String _attentionLabel(BuildContext context, String flag) {
    final l = context.l10n;
    return switch (flag) {
      'risk_item' => l.clinicianAttentionRisk,
      'worsened' => l.clinicianAttentionWorsened,
      'severe' => l.clinicianAttentionSevere,
      _ => flag,
    };
  }
}

class _MiniFlag extends StatelessWidget {
  const _MiniFlag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: t.bodySmall?.copyWith(
          color: colors.actionText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
