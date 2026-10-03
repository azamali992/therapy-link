import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../shared/widgets.dart';

final careLinksProvider = FutureProvider<List<CareLink>>((ref) => ref.watch(apiClientProvider).careLinks());

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
      final notFound = e is DioException && e.response?.statusCode == 404;
      if (mounted) setState(() => _error = notFound ? context.l10n.careInviteNotFound : context.l10n.errorGeneric);
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

    return Screen(
      title: l.careTitle,
      child: links.when(
        loading: () => const SkeletonList(rows: 2),
        error: (_, _) => ErrorState(onRetry: () => ref.invalidate(careLinksProvider)),
        data: (rows) {
          final active = rows.where((r) => r.status == LinkStatus.active).toList();
          final pending = rows.where((r) => r.status == LinkStatus.pending).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (active.isEmpty && pending.isEmpty) EmptyState(title: l.careEmptyTitle, body: l.careEmptyBody),
              if (pending.isNotEmpty) ...[
                SectionTitle(l.carePendingTitle),
                for (final link in pending) ...[
                  Text(link.clinicianName ?? link.clinicianUid, style: t.titleMedium),
                  const SizedBox(height: Tokens.s4),
                  Text(l.carePendingBody, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: _busy ? null : () => _act(() => api.revokeLink(link.id)),
                      style: TextButton.styleFrom(foregroundColor: scheme.tertiary),
                      child: Text(l.carePendingCancel),
                    ),
                  ),
                  const Divider(),
                ],
              ],
              if (active.isNotEmpty && pending.isNotEmpty) SectionTitle(l.careActiveTitle),
              for (final link in active) ...[
                SectionTitle(
                  link.clinicianName ?? link.clinicianUid,
                  trailing: link.clinicianVerified
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_outlined, size: 18, color: scheme.primary),
                            const SizedBox(width: Tokens.s4),
                            Text(l.careVerified, style: t.labelMedium?.copyWith(color: scheme.primary)),
                          ],
                        )
                      : null,
                ),
                Text(l.careConsentTitle, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: Tokens.s4),
                _Consent(label: l.careShareAssessments, value: link.shareAssessments, busy: _busy, onChanged: (v) => _act(() => api.setConsent(link.id, {'share_assessments': v}))),
                _Consent(label: l.careShareMood, value: link.shareMoodTrend, busy: _busy, onChanged: (v) => _act(() => api.setConsent(link.id, {'share_mood_trend': v}))),
                _Consent(label: l.careShareJournal, value: link.shareJournal, busy: _busy, onChanged: (v) => _act(() => api.setConsent(link.id, {'share_journal': v}))),
                const SizedBox(height: Tokens.s8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _busy ? null : () => _act(() => api.revokeLink(link.id)),
                    style: TextButton.styleFrom(foregroundColor: scheme.tertiary),
                    child: Text(l.careRevoke),
                  ),
                ),
                const Divider(),
              ],
              SectionTitle(l.careInvite),
              TextField(
                controller: _id,
                decoration: InputDecoration(labelText: l.careInviteHint),
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: Tokens.s8), child: Text(_error!, style: TextStyle(color: scheme.error))),
              const SizedBox(height: Tokens.s12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _act(() async {
                          await api.inviteClinician(_id.text.trim());
                          _id.clear();
                        }),
                child: Text(l.careInvite),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Consent extends StatelessWidget {
  const _Consent({required this.label, required this.value, required this.busy, required this.onChanged});

  final String label;
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: Text(label), value: value, onChanged: busy ? null : onChanged);
  }
}
