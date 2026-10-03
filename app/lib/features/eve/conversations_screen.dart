import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme/tokens.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/jugnu_app_bar.dart';
import '../../ui/components/jugnu_scaffold.dart';
import '../../ui/jugnu_icons.dart';
import '../shared/crisis_copy.dart';
// Hide the no-icon EmptyState from shared/widgets so the one from ui/components is used.
import '../shared/widgets.dart' hide EmptyState;
import 'conversations_repository.dart';
import 'eve_controller.dart' as ctrl;

/// /eve/conversations — conversation history list.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final copy = CrisisCopy.forContext(context);
    final conversations = ref.watch(conversationListProvider);

    return JugnuScaffold(
      appBar: JugnuAppBar(
        title: Text(l.eveNewConversation),
        onGetHelp: () => showCrisisSheet(context, copy: copy),
      ),
      body: conversations.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Jugnu.s20),
          child: SkeletonList(rows: 4),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(Jugnu.s20),
          child: ErrorState(
            onRetry: () => ref.invalidate(conversationListProvider),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(Jugnu.s20),
              child: EmptyState(
                icon: JugnuIcons.chat,
                title: l.eveNewConversation,
                body: l.eveGreetingSub,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: Jugnu.s20, vertical: Jugnu.s8),
            itemCount: list.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: Theme.of(context)
                  .extension<JugnuColors>()!
                  .hair,
            ),
            itemBuilder: (context, i) =>
                _ConversationTile(summary: list[i], ref: ref),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.summary, required this.ref});

  final ConversationSummary summary;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final dateLabel = _formatDate(summary.updatedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Jugnu.rNested),
        onTap: () async {
          final opened = await ref
              .read(ctrl.eveControllerProvider.notifier)
              .openConversation(summary.id);
          if (opened && context.mounted) context.pop();
        },
        onLongPress: () => _confirmDelete(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: Jugnu.s12, horizontal: Jugnu.s4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.title ?? dateLabel,
                      style: t.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel · ${summary.messageCount} messages',
                      style: t.bodyMedium?.copyWith(color: colors.ink2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(JugnuIcons.chevronRight, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content:
            const Text('This removes all messages. Memory notes stay.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(ctrl.eveControllerProvider.notifier)
          .deleteConversation(summary.id);
    }
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return 'Today ${DateFormat.Hm().format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('d MMM').format(dt);
  }
}
