import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Convenience accessor — avoids importing AppLocalizations on every screen.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

// ---------------------------------------------------------------------------
// Get help button
// ---------------------------------------------------------------------------

/// "Get help now" action reachable from every screen, including before sign-in.
///
/// Tapping opens the crisis help sheet. The actual sheet content (helpline
/// numbers, crisis logic) is wired by the core team.
/// TODO(core-team): replace the stub [_showHelpSheet] with the real crisis
/// sheet implementation from lib/features/shared/crisis_sheet.dart.
class GetHelpButton extends StatelessWidget {
  const GetHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.getHelpNow,
      icon: const Icon(Icons.health_and_safety_outlined),
      color: Theme.of(context).colorScheme.tertiary,
      onPressed: () => _showHelpSheet(context),
    );
  }
}

/// TODO(core-team): replace with the real crisis sheet.
void _showHelpSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        Tokens.s24,
        Tokens.s8,
        Tokens.s24,
        Tokens.s24 + MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.getHelpNow,
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          const SizedBox(height: Tokens.s12),
          // TODO(core-team): replace with data-driven helpline list.
          Text(
            'Umang · 0311 7786264\n'
            'Madadgaar · 1098\n'
            'Emergency · 1122',
            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(ctx).colorScheme.tertiary,
                ),
          ),
          const SizedBox(height: Tokens.s16),
          FilledButton.icon(
            icon: const Icon(Icons.call_outlined),
            label: Text(context.l10n.crisisCallEmergency),
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.tertiary,
              foregroundColor: Theme.of(ctx).colorScheme.onTertiary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Quick exit button
// ---------------------------------------------------------------------------

/// One-tap "panic close" visible in every AppBar. When activated it navigates
/// to a neutral screen (e.g. home feed / clock) via the platform channel.
///
/// TODO(core-team): wire [onQuickExit] through a provider so the router can
/// handle navigation and the privacy service can clear the recents preview.
/// For now the button shows a snackbar to confirm the intent.
class QuickExitButton extends StatelessWidget {
  const QuickExitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.quickExitTitle,
      icon: const Icon(Icons.exit_to_app_rounded),
      onPressed: () => _quickExit(context),
    );
  }
}

/// TODO(core-team): implement real quick-exit: navigate to '/', clear the
/// Flutter recents preview, and optionally open a neutral system app.
void _quickExit(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(context.l10n.quickExitNeutral),
      duration: const Duration(seconds: 2),
    ),
  );
}

// ---------------------------------------------------------------------------
// Screen — standard page frame
// ---------------------------------------------------------------------------

/// Standard page scaffold: title, optional back, reading-width constraint.
///
/// Every screen carries "Get help now" and "Quick exit" in the AppBar by
/// default so help is never more than one tap away, even before sign-in. Pass
/// [help] = false or [quickExit] = false only for screens where the control
/// would be confusing (e.g. the crisis sheet itself).
class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.fab,
    this.scroll = true,
    this.padding = true,
    this.help = true,
    this.quickExit = true,
  });

  final String title;
  final Widget child;

  /// Extra AppBar actions placed to the left of the standard safety controls.
  final List<Widget>? actions;
  final Widget? fab;

  /// Wrap [child] in a [SingleChildScrollView] (default true).
  final bool scroll;

  /// Apply standard reading-width padding (default true).
  final bool padding;

  /// Show the [GetHelpButton] in the AppBar (default true).
  final bool help;

  /// Show the [QuickExitButton] in the AppBar (default true).
  final bool quickExit;

  @override
  Widget build(BuildContext context) {
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Tokens.readingWidth),
        child: Padding(
          padding: padding
              ? const EdgeInsets.fromLTRB(
                  Tokens.s20, Tokens.s8, Tokens.s20, Tokens.s48)
              : EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          if (quickExit) const QuickExitButton(),
          if (help) const GetHelpButton(),
        ],
      ),
      body: scroll ? SingleChildScrollView(child: body) : body,
      floatingActionButton: fab,
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable small widgets
// ---------------------------------------------------------------------------

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.s24, bottom: Tokens.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: t.titleMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: Tokens.s8),
          Text(body,
              style: t.bodyMedium,
              textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: Tokens.s24),
            action!,
          ],
        ],
      ),
    );
  }
}
