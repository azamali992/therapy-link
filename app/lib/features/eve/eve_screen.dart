import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/db/database.dart';
import '../../core/security/privacy_settings.dart';
import '../../core/security/quick_exit.dart';
import '../../ui/components/composer.dart';
import '../../ui/components/help_bar.dart';
import '../../ui/components/inline_note.dart';
import '../../ui/components/jugnu_scaffold.dart';
import '../../ui/components/messages.dart';
import '../../ui/jugnu_icons.dart';
// Import the presence barrel — EveState (enum) is in presence_assets.dart.
// The controller also has a class called EveState; alias the controller import
// to avoid ambiguity.
import '../../ui/presence/presence.dart';
import '../../core/ml/guardian.dart' show CrisisKind;
import '../shared/crisis_copy.dart';
import '../shared/helplines.dart';
import '../shared/widgets.dart';
import 'crisis_mode.dart';
import 'eve_controller.dart' as ctrl;
// Alias jugnu_app_bar components to differentiate from the shared wrappers.
import '../../ui/components/jugnu_app_bar.dart' as jab;
import '../../app/theme/theme.dart' show jugnuNumberLarge;

/// /eve — AI companion chat screen.
class EveScreen extends ConsumerStatefulWidget {
  const EveScreen({super.key});

  @override
  ConsumerState<EveScreen> createState() => _EveScreenState();
}

class _EveScreenState extends ConsumerState<EveScreen> {
  final _scroll = ScrollController();
  bool _hasText = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    ref.read(ctrl.eveControllerProvider.notifier).send(text);
    setState(() => _hasText = false);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Open the crisis sheet whenever Eve flags a message.
    ref.listen(ctrl.eveControllerProvider.select((s) => s.crisisPending), (_, pending) async {
      if (!pending) return;
      final s = ref.read(ctrl.eveControllerProvider);
      ref.read(ctrl.eveControllerProvider.notifier).crisisShown();
      await showCrisisSheet(context, kind: s.crisisKind, copy: CrisisCopy.of(s.crisisLanguage));
    });

    // Keep Eve's 3D presence frozen at idle during crisis mode.
    ref.listen(crisisModeProvider.select((s) => s.active), (_, active) {
      ref.read(evePresenceCrisisHoldProvider.notifier).hold(active);
    });

    final messages = ref.watch(ctrl.eveMessagesProvider);
    final state = ref.watch(ctrl.eveControllerProvider);
    final crisis = ref.watch(crisisModeProvider);
    final copy = CrisisCopy.forContext(context);
    final showQuickExit = ref.watch(privacySettingsProvider.select((s) => s.quickExit));

    // EvePresence animation state (enum from presence_assets.dart).
    // Hold idle when the server is busy or slow — animated states during an
    // error would be misleading (Eve isn't actually thinking or listening).
    final presenceState = (state.eveBusy || state.eveSlow)
        ? EvePresenceState.idle
        : state.generating
            ? EvePresenceState.thinking
            : (_hasText ? EvePresenceState.listening : EvePresenceState.idle);

    // Status line copy (Roman Urdu, third-person).
    final statusLine = state.generating
        ? 'soch rahi hai…'
        : (_hasText ? 'sun rahi hai' : 'yahan hai');

    return JugnuScaffold(
      appBar: _EveChatAppBar(
        presenceState: presenceState,
        statusLine: statusLine,
        showQuickExit: showQuickExit,
        onGetHelp: () => showCrisisSheet(context, copy: copy),
        onQuickExit: showQuickExit
            ? () => ref.read(quickExitProvider.notifier).exit()
            : null,
        onConversations: () => context.go('/eve/conversations'),
      ),
      body: Column(
        children: [
          // Storage notice: honest inline copy — chat stays on this phone,
          // replies come from the server and are not retained there.
          Padding(
            padding: const EdgeInsets.fromLTRB(Jugnu.s16, Jugnu.s8, Jugnu.s16, 0),
            child: InlineNote(
              text: context.l10n.evePrivacyInline,
              isProtected: false,
            ),
          ),

          // Message thread.
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Jugnu.readingWidth),
                child: messages.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(Jugnu.s20),
                    child: SkeletonList(rows: 2),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.all(Jugnu.s20),
                    child: ErrorState(
                      onRetry: () => ref.invalidate(ctrl.eveMessagesProvider),
                    ),
                  ),
                  data: (rows) => _MessageList(
                    controller: _scroll,
                    rows: rows,
                    partial: state.partial,
                    generating: state.generating,
                    onStarter: (text) {
                      ref.read(ctrl.eveControllerProvider.notifier).send(text);
                      _scrollToEnd();
                    },
                  ),
                ),
              ),
            ),
          ),

          // Persistent help bar during a crisis session.
          if (crisis.active)
            HelpBar(
              label: copy.helpBar,
              onGetHelp: () =>
                  showCrisisSheet(context, kind: crisis.kind, copy: copy),
            ),

          // Calm inline notice when the server is busy or slow.
          // No animation, no red. Help is still reachable via the app bar.
          if (state.eveBusy || state.eveSlow)
            Padding(
              padding: const EdgeInsets.fromLTRB(Jugnu.s16, Jugnu.s8, Jugnu.s16, 0),
              child: _EveStatusBanner(
                title: state.eveBusy
                    ? context.l10n.eveBusyTitle
                    : context.l10n.eveSlowTitle,
                body: state.eveBusy
                    ? context.l10n.eveBusyBody
                    : context.l10n.eveSlowBody,
                onRetry: () =>
                    ref.read(ctrl.eveControllerProvider.notifier).retry(),
                retryLabel: context.l10n.eveTryAgain,
              ),
            ),

          // Composer with grounding quick-replies when relevant.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Jugnu.readingWidth),
            child: Composer(
              onSend: _send,
              enabled: !state.generating,
              hint: context.l10n.eveComposerHint,
              quickReplies: _quickReplies(state, context),
              onQuickReply: (chip) {
                ref.read(ctrl.eveControllerProvider.notifier).send(chip);
                setState(() => _hasText = false);
                _scrollToEnd();
              },
              onChanged: (text) {
                final has = text.trim().isNotEmpty;
                if (has != _hasText) setState(() => _hasText = has);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> _quickReplies(ctrl.EveState state, BuildContext context) {
    if (state.suggestGrounding) {
      return ['Saans ki exercise', 'Bas baat karni hai'];
    }
    if (state.suggestBreak) {
      return ['Theek hai', 'Aur baat karni hai'];
    }
    return const [];
  }
}

// ---------------------------------------------------------------------------
// Custom Eve chat app bar
// ---------------------------------------------------------------------------

/// Eve chat app bar: 52 dp presence bubble + name/live status + Madad + optional quick-exit.
class _EveChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _EveChatAppBar({
    required this.presenceState,
    required this.statusLine,
    required this.showQuickExit,
    required this.onGetHelp,
    required this.onConversations,
    this.onQuickExit,
  });

  final EvePresenceState presenceState;
  final String statusLine;
  final bool showQuickExit;
  final VoidCallback onGetHelp;
  final VoidCallback? onQuickExit;
  final VoidCallback onConversations;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        // Reduced left padding (8 instead of 14) so the name/status column
        // has enough room to show fully at 360 dp without truncation.
        padding: const EdgeInsets.fromLTRB(8, 2, 0, 8),
        child: Row(
          children: [
            // Eve presence 52 dp. No halo on the small chatHeader size.
            EvePresence(
              state: presenceState,
              size: EvePresentSize.chatHeader,
              showHalo: false,
            ),
            const SizedBox(width: 6),
            // Name + live status.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Eve',
                    style: textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      statusLine,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.evePresence,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Conversations history button.
        Semantics(
          button: true,
          label: 'Conversations',
          child: SizedBox(
            width: Jugnu.minTarget,
            height: Jugnu.minTarget,
            child: IconButton(
              icon: const Icon(JugnuIcons.journal, size: 22),
              color: colors.ink2,
              onPressed: onConversations,
              tooltip: 'Conversations',
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        // Madad (Get help) pill — always visible.
        jab.GetHelpButton(
          label: 'Madad',
          onPressed: onGetHelp,
        ),
        if (showQuickExit && onQuickExit != null) ...[
          const SizedBox(width: 10),
          jab.QuickExitButton(onPressed: onQuickExit!),
        ],
        const SizedBox(width: Jugnu.s16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Message list
// ---------------------------------------------------------------------------

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

    bool lastWasEve = false;
    for (final m in rows) {
      if (m.role == 'user') {
        items.add(MyMessage(text: m.content));
        lastWasEve = false;
      } else if (m.role == 'assistant') {
        items.add(EveMessage(text: m.content, showHeader: !lastWasEve));
        lastWasEve = true;
      } else if (m.role == ctrl.crisisRole) {
        final parsed = ctrl.parseCrisis(m.content);
        items.add(
          _InChatCrisisCard(kind: parsed.kind, language: parsed.language),
        );
        lastWasEve = true;
      }
      // exercise role rendered elsewhere
    }

    if (generating) {
      if (partial.isEmpty) {
        items.add(const ThinkingLine());
      } else {
        items.add(EveMessage(text: partial, showHeader: !lastWasEve));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Jugnu.s20, Jugnu.s16, Jugnu.s20, Jugnu.s16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) => items[items.length - 1 - i],
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome / empty state
// ---------------------------------------------------------------------------

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStarter});

  final ValueChanged<String> onStarter;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final l = context.l10n;
    final starters = [
      l.eveStarterAnxious,
      l.eveStarterSleep,
      l.eveStarterVent,
      l.eveStarterCalm,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Jugnu.s24),
        Text(l.eveGreeting, style: t.headlineSmall),
        const SizedBox(height: Jugnu.s8),
        Text(l.eveGreetingSub, style: t.bodyMedium?.copyWith(color: colors.ink2)),
        const SizedBox(height: Jugnu.s20),
        Wrap(
          spacing: Jugnu.s8,
          runSpacing: Jugnu.s8,
          children: [
            for (final s in starters)
              _StarterChip(label: s, onTap: () => onStarter(s)),
          ],
        ),
      ],
    );
  }
}

class _StarterChip extends StatelessWidget {
  const _StarterChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Jugnu.minTarget),
        padding: const EdgeInsets.symmetric(
            horizontal: Jugnu.s16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.hairStrong, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Eve status banner (busy / slow server)
// ---------------------------------------------------------------------------

/// Calm inline notice shown above the composer when Eve's server is busy or
/// slow. Uses the `surface` / `ink2` tokens so it blends into the UI without
/// drawing attention. No red, no animation; help is still in the app bar.
class _EveStatusBanner extends StatelessWidget {
  const _EveStatusBanner({
    required this.title,
    required this.body,
    required this.onRetry,
    required this.retryLabel,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Jugnu.s16, 12, Jugnu.s12, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Jugnu.rNested),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: t.labelMedium?.copyWith(
              color: colors.ink2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: t.bodyMedium?.copyWith(color: colors.ink2),
          ),
          // "Try again" action — TextButton so it has a proper touch target
          // but stays low-key (no filled background, no outline).
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: colors.ink2,
                padding: const EdgeInsets.symmetric(
                    horizontal: Jugnu.s8, vertical: Jugnu.s4),
                minimumSize: const Size(Jugnu.minTarget, Jugnu.minTarget),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                retryLabel,
                style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// In-chat crisis card (help surface styling)
// ---------------------------------------------------------------------------

class _InChatCrisisCard extends StatelessWidget {
  const _InChatCrisisCard({required this.kind, required this.language});

  final CrisisKind kind;
  final CrisisLanguage language;

  @override
  Widget build(BuildContext context) {
    final copy = CrisisCopy.of(language);
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final t = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Jugnu.s16),
      decoration: BoxDecoration(
        color: colors.helpSurface,
        borderRadius: BorderRadius.circular(Jugnu.rSlab),
        border: Border.all(
            color: colors.onHelpSurface.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.title(kind),
            style: t.titleMedium?.copyWith(color: colors.onHelpSurface),
          ),
          const SizedBox(height: Jugnu.s8),
          Text(
            copy.body(kind),
            style: t.bodyMedium?.copyWith(color: colors.onHelpSurface),
          ),
          const SizedBox(height: Jugnu.s12),
          for (final line in helplinesFor(kind))
            _CrisisCardLine(
              line: line,
              copy: copy,
              helpSurface: colors.helpSurface,
              onHelpSurface: colors.onHelpSurface,
            ),
        ],
      ),
    );
  }
}

class _CrisisCardLine extends StatelessWidget {
  const _CrisisCardLine({
    required this.line,
    required this.copy,
    required this.helpSurface,
    required this.onHelpSurface,
  });

  final Helpline line;
  final CrisisCopy copy;
  final Color helpSurface;
  final Color onHelpSurface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Jugnu.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: onHelpSurface,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SelectableText(
                  line.display,
                  style: jugnuNumberLarge(onHelpSurface),
                ),
              ],
            ),
          ),
          SizedBox(
            width: Jugnu.minTarget,
            height: Jugnu.minTarget,
            child: IconButton(
              icon: Icon(JugnuIcons.copy, size: 18, color: onHelpSurface),
              tooltip: copy.copyNumber,
              onPressed: () => copyHelpline(context, line, copy),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: Jugnu.s4),
          GestureDetector(
            onTap: () => callHelpline(context, line, copy),
            child: Semantics(
              button: true,
              label: copy.call(line.name),
              child: Container(
                width: Jugnu.minTarget,
                height: Jugnu.minTarget,
                decoration: BoxDecoration(
                  color: onHelpSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(JugnuIcons.phone, size: 18, color: helpSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
