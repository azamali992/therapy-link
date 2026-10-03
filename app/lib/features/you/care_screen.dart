import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/setting_row.dart';
import '../../ui/components/slab.dart';
import '../shared/widgets.dart';

final careLinksProvider = FutureProvider<List<CareLink>>(
    (ref) => ref.watch(apiClientProvider).careLinks());

class CareScreen extends ConsumerStatefulWidget {
  const CareScreen({super.key});

  @override
  ConsumerState<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends ConsumerState<CareScreen> {
  final _id = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      ref.invalidate(careLinksProvider);
    } catch (e) {
      final notFound =
          e is DioException && e.response?.statusCode == 404;
      if (mounted) {
        setState(() => _error = notFound
            ? context.l10n.careInviteNotFound
            : context.l10n.errorGeneric);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final links = ref.watch(careLinksProvider);
    final api = ref.read(apiClientProvider);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return Screen(
      title: l.careTitle,
      child: links.when(
        loading: () => const SkeletonList(rows: 2),
        error: (_, _) =>
            ErrorState(onRetry: () => ref.invalidate(careLinksProvider)),
        data: (rows) {
          final active = rows
              .where((r) => r.status == LinkStatus.active)
              .toList();
          final pending = rows
              .where((r) => r.status == LinkStatus.pending)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (active.isEmpty && pending.isEmpty)
                EmptyState(
                    title: l.careEmptyTitle, body: l.careEmptyBody),

              // Pending invites
              if (pending.isNotEmpty) ...[
                SectionTitle(l.carePendingTitle),
                for (final link in pending) ...[
                  Slab(
                    padding: const EdgeInsets.all(Tokens.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link.clinicianName ?? link.clinicianUid,
                          style: t.titleMedium,
                        ),
                        const SizedBox(height: Tokens.s4),
                        Text(
                          l.carePendingBody,
                          style: t.bodyMedium
                              ?.copyWith(color: colors.ink2),
                        ),
                        const SizedBox(height: Tokens.s12),
                        GhostButton(
                          label: l.carePendingCancel,
                          onPressed: _busy
                              ? () {}
                              : () => _act(
                                  () => api.revokeLink(link.id)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Tokens.s8),
                ],
              ],

              // Active links
              if (active.isNotEmpty && pending.isNotEmpty)
                SectionTitle(l.careActiveTitle),
              for (final link in active) ...[
                Slab(
                  padding: const EdgeInsets.all(Tokens.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              link.clinicianName ?? link.clinicianUid,
                              style: t.titleMedium,
                            ),
                          ),
                          if (link.clinicianVerified) ...[
                            Icon(Icons.verified_outlined,
                                size: 18, color: scheme.primary),
                            const SizedBox(width: Tokens.s4),
                            Text(
                              l.careVerified,
                              style: t.labelMedium
                                  ?.copyWith(color: scheme.primary),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Tokens.s12),
                      Text(
                        l.careConsentTitle,
                        style: t.bodyMedium
                            ?.copyWith(color: colors.ink2),
                      ),
                      const SizedBox(height: Tokens.s4),
                      SettingRow(
                        title: l.careShareAssessments,
                        value: link.shareAssessments,
                        onChanged: _busy
                            ? (_) {}
                            : (v) => _act(() => api.setConsent(
                                link.id,
                                {'share_assessments': v})),
                      ),
                      Divider(height: 1, color: colors.hair),
                      SettingRow(
                        title: l.careShareMood,
                        value: link.shareMoodTrend,
                        onChanged: _busy
                            ? (_) {}
                            : (v) => _act(() => api.setConsent(
                                link.id, {'share_mood_trend': v})),
                      ),
                      Divider(height: 1, color: colors.hair),
                      SettingRow(
                        title: l.careShareJournal,
                        value: link.shareJournal,
                        onChanged: _busy
                            ? (_) {}
                            : (v) => _act(() => api.setConsent(
                                link.id, {'share_journal': v})),
                      ),
                      const SizedBox(height: Tokens.s12),
                      GhostButton(
                        label: l.careRevoke,
                        onPressed: _busy
                            ? () {}
                            : () =>
                                _act(() => api.revokeLink(link.id)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Tokens.s8),
              ],

              // Connect a clinician
              SectionTitle(l.careInvite),
              TextField(
                controller: _id,
                decoration:
                    InputDecoration(labelText: l.careInviteHint),
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: Tokens.s8),
                  child: Text(_error!,
                      style: TextStyle(color: scheme.error)),
                ),
              const SizedBox(height: Tokens.s16),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _act(() async {
                          await api.inviteClinician(_id.text.trim());
                          _id.clear();
                        }),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(Tokens.s48)),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.careInvite),
              ),
            ],
          );
        },
      ),
    );
  }
}
