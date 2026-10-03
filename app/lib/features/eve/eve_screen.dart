import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/db/database.dart';
import '../../core/ml/guardian.dart';
import '../shared/crisis_copy.dart';
import '../shared/widgets.dart';
import 'crisis_mode.dart';
import 'eve_controller.dart';

/// /eve — AI companion chat screen.
class EveScreen extends ConsumerStatefulWidget {
  const EveScreen({super.key});

  @override
  ConsumerState<EveScreen> createState() => _EveScreenState();
}

class _EveScreenState extends ConsumerState<EveScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty || ref.read(eveControllerProvider).generating) return;
    _input.clear();
    ref.read(eveControllerProvider.notifier).send(text);
    _focus.requestFocus();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || _scroll.offset == 0) return;
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Open the crisis sheet whenever Eve flags a message.
    ref.listen(eveControllerProvider.select((s) => s.crisisPending), (_, pending) async {
      if (!pending) return;
      final s = ref.read(eveControllerProvider);
      ref.read(eveControllerProvider.notifier).crisisShown();
      await showCrisisSheet(context, kind: s.crisisKind, copy: CrisisCopy.of(s.crisisLanguage));
    });

    final messages = ref.watch(eveMessagesProvider);
    final state = ref.watch(eveControllerProvider);
    final crisis = ref.watch(crisisModeProvider);
    final copy = CrisisCopy.forContext(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabEve),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: l.eveNewConversation,
            onPressed: () => context.go('/eve/conversations'),
          ),
          const QuickExitButton(),
          const GetHelpButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Tokens.readingWidth),
                child: messages.when(
                  loading: () => const Padding(padding: EdgeInsets.all(Tokens.s20), child: SkeletonList(rows: 2)),
                  error: (_, _) => Padding(padding: const EdgeInsets.all(Tokens.s20), child: ErrorState(onRetry: () => ref.invalidate(eveMessagesProvider))),
                  data: (rows) => _MessageList(
                    controller: _scroll,
                    rows: rows,
                    partial: state.partial,
                    generating: state.generating,
                    onStarter: (text) {
                      ref.read(eveControllerProvider.notifier).send(text);
                      _scrollToEnd();
                    },
                  ),
                ),
              ),
            ),
          ),
          // Help bar stays up during a crisis session.
          if (crisis.active)
            _HelpBar(copy: copy, kind: crisis.kind),
          _Composer(
            controller: _input,
            focus: _focus,
            canSend: !state.generating,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.rows,
    required this.partial,
    required this.generating,
    required this.onStarter,
  });

  final ScrollController controller;
  final List<Message> rows;
  final String partial;
  final bool generating;
  final ValueChanged<String> onStarter;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (rows.isEmpty && !generating) {
      items.add(_Welcome(onStarter: onStarter));
    }

    for (final m in rows) {
      if (m.role == 'user') {
        items.add(_UserBubble(text: m.content));
      } else if (m.role == 'assistant') {
        items.add(_EveBubble(text: m.content));
      }
      // crisis and exercise roles are rendered by the controller into the sheet/card flow.
    }

    if (generating) {
      items.add(partial.isEmpty ? const _Typing() : _EveBubble(text: partial, streaming: true));
    }

    return ListView.separated(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Tokens.s20, Tokens.s16, Tokens.s20, Tokens.s16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: Tokens.s12),
      itemBuilder: (_, i) => items[items.length - 1 - i],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStarter});

  final ValueChanged<String> onStarter;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final starters = [l.eveStarterAnxious, l.eveStarterSleep, l.eveStarterVent, l.eveStarterCalm];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Tokens.s24),
        Text(l.eveGreeting, style: t.headlineSmall),
        const SizedBox(height: Tokens.s8),
        Text(l.eveGreetingSub, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: Tokens.s20),
        Wrap(
          spacing: Tokens.s8,
          runSpacing: Tokens.s8,
          children: [
            for (final s in starters) ActionChip(label: Text(s), onPressed: () => onStarter(s)),
          ],
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.14),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(Tokens.rCard),
              topRight: Radius.circular(Tokens.rCard),
              bottomLeft: Radius.circular(Tokens.rCard),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: SelectableText(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}

class _EveBubble extends StatelessWidget {
  const _EveBubble({required this.text, this.streaming = false});

  final String text;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(Tokens.rCard),
              bottomLeft: Radius.circular(Tokens.rCard),
              bottomRight: Radius.circular(Tokens.rCard),
            ),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: streaming ? Text(text, style: t.bodyLarge) : SelectableText(text, style: t.bodyLarge),
        ),
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: context.l10n.eveListening,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.s16, vertical: Tokens.s16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(Tokens.rCard),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Opacity(
                    opacity: still ? 0.6 : 0.3 + 0.7 * (1 - (((_c.value - i * 0.2) % 1.0) * 2 - 1).abs()),
                    child: Container(width: 7, height: 7, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                  ),
                  if (i < 2) const SizedBox(width: 5),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focus, required this.canSend, required this.onSend});

  final TextEditingController controller;
  final FocusNode focus;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: Theme.of(context).cardTheme.color,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.s16, Tokens.s8, Tokens.s8, Tokens.s16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Tokens.readingWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: canSend ? (_) => onSend() : null,
                      decoration: InputDecoration(hintText: l.eveComposerHint),
                    ),
                  ),
                  const SizedBox(width: Tokens.s8),
                  IconButton.filled(
                    onPressed: canSend ? onSend : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                    tooltip: l.eveSend,
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stays up for the duration of a crisis session: one tap to the helplines.
class _HelpBar extends StatelessWidget {
  const _HelpBar({required this.copy, required this.kind});

  final CrisisCopy copy;
  final CrisisKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Material(
      color: scheme.tertiary.withValues(alpha: 0.10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Tokens.readingWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Tokens.s20, Tokens.s8, Tokens.s8, Tokens.s8),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, color: scheme.tertiary, size: 20),
                const SizedBox(width: Tokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.helpBar, style: t.titleSmall),
                      Text(copy.helpBarBody, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => showCrisisSheet(context, kind: kind, copy: copy),
                  style: FilledButton.styleFrom(backgroundColor: scheme.tertiary, foregroundColor: scheme.surface, minimumSize: const Size(0, 44)),
                  child: Text(copy.helpNow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
