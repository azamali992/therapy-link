import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/locale.dart';
import '../../app/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../ui/components/slab.dart';
import '../shared/widgets.dart';

/// Provider for the clinician's pending link requests.
final clinicianRequestsProvider = FutureProvider<List<LinkRequest>>(
  (ref) => ref.watch(apiClientProvider).clinicianRequests(),
);

/// /clinic/requests -- pending patient link requests.
///
/// Each request shows the patient name, when they asked, and
/// Accept / Decline buttons. All touch targets are >= 48 dp.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  final _busy = <String, bool>{};

  Future<void> _accept(String linkId) async {
    setState(() => _busy[linkId] = true);
    try {
      await ref.read(apiClientProvider).acceptRequest(linkId);
      ref.invalidate(clinicianRequestsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(linkId));
    }
  }

  Future<void> _decline(String linkId) async {
    setState(() => _busy[linkId] = true);
    try {
      await ref.read(apiClientProvider).declineRequest(linkId);
      ref.invalidate(clinicianRequestsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(linkId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.clinicianRequests,
      help: false,
      quickExit: false,
      child: ref.watch(clinicianRequestsProvider).when(
        loading: () => const SkeletonList(rows: 3),
        error: (_, _) => ErrorState(
            onRetry: () =>
                ref.invalidate(clinicianRequestsProvider)),
        data: (requests) {
          if (requests.isEmpty) {
            return EmptyState(
              title: l.clinicianRequestsEmpty,
              body: l.clinicianRequestsHelp,
            );
          }
          return _RequestList(
            requests: requests,
            busy: _busy,
            onAccept: _accept,
            onDecline: _decline,
          );
        },
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.requests,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final List<LinkRequest> requests;
  final Map<String, bool> busy;
  final void Function(String) onAccept;
  final void Function(String) onDecline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final df = DateFormat.yMMMd(dateLocaleOf(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Tokens.s8),
        Text(l.clinicianRequestsHelp,
            style: t.bodyMedium?.copyWith(color: colors.ink2)),
        const SizedBox(height: Tokens.s16),
        for (final r in requests) ...[
          Slab(
            padding: const EdgeInsets.all(Tokens.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.patient.displayName ?? r.patient.uid,
                        style: t.titleMedium,
                      ),
                    ),
                    if (r.requestedAt != null)
                      Text(
                        l.clinicianRequestedOn(
                            df.format(r.requestedAt!)),
                        style: t.labelSmall
                            ?.copyWith(color: colors.ink2),
                      ),
                  ],
                ),
                const SizedBox(height: Tokens.s12),
                Row(
                  children: [
                    // Accept: FilledButton with Jugnu 48dp min target.
                    // (PrimaryButton has no disabled/loading state;
                    //  FilledButton is used only here for the loading spinner.)
                    FilledButton(
                      onPressed: busy[r.linkId] == true
                          ? null
                          : () => onAccept(r.linkId),
                      style: FilledButton.styleFrom(
                        minimumSize:
                            const Size(88, Tokens.s48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: Tokens.s16),
                      ),
                      child: busy[r.linkId] == true
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : Text(l.clinicianRequestAccept),
                    ),
                    const SizedBox(width: Tokens.s12),
                    TextButton(
                      onPressed: busy[r.linkId] == true
                          ? null
                          : () => onDecline(r.linkId),
                      style: TextButton.styleFrom(
                        minimumSize:
                            const Size(88, Tokens.s48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: Tokens.s16),
                      ),
                      child: Text(l.clinicianRequestDecline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.s8),
        ],
      ],
    );
  }
}
