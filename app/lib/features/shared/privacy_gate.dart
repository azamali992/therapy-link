import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database_notice.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/privacy_settings.dart';
import '../../core/security/quick_exit.dart';
import 'lock_screen.dart';
import 'widgets.dart';

/// Wraps every route (from MaterialApp.builder) and decides what may be seen: the app, the lock
/// screen, the neutral screen after a quick exit, or a plain cover while the app is in the
/// background with the lock on.
class PrivacyGate extends ConsumerStatefulWidget {
  const PrivacyGate({super.key, required this.child, this.onQuickExit});

  final Widget child;

  /// Sends navigation back to the start, under the neutral screen.
  final VoidCallback? onQuickExit;

  @override
  ConsumerState<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends ConsumerState<PrivacyGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(secureWindowProvider)(ref.read(privacySettingsProvider).appLock);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        lock.onBackground();
      case AppLifecycleState.resumed:
        lock.onResume();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  bool _wasObscured = false;

  ScaffoldMessengerState? get _messenger => mounted ? ScaffoldMessenger.maybeOf(context) : null;

  void _showNotice(DatabaseNotice notice) {
    final l = context.l10n;
    final text = switch (notice) {
      DatabaseNotice.migrationFailed => l.dbMigrationFailed,
      DatabaseNotice.unreadable => l.dbUnreadable,
      DatabaseNotice.openFailed => l.dbOpenFailed,
    };
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 12),
        action: SnackBarAction(label: MaterialLocalizations.of(context).okButtonLabel, onPressed: messenger.hideCurrentSnackBar),
      ),
    );
    ref.read(databaseNoticeProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(privacySettingsProvider.select((s) => s.appLock), (_, on) => ref.read(secureWindowProvider)(on));
    ref.listen(quickExitProvider, (was, hidden) {
      if (hidden && was != true) widget.onQuickExit?.call();
    });
    final lock = ref.watch(appLockProvider);
    final hidden = ref.watch(quickExitProvider);
    final obscured = lock.locked || lock.covered || hidden;

    final notice = ref.watch(databaseNoticeProvider);
    if (obscured != _wasObscured) {
      final nowObscured = obscured;
      _wasObscured = obscured;
      if (nowObscured) WidgetsBinding.instance.addPostFrameCallback((_) => _messenger?.clearSnackBars());
    }
    if (notice != null && !obscured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _wasObscured || ref.read(databaseNoticeProvider) != notice) return;
        _showNotice(notice);
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: obscured, child: ExcludeFocus(excluding: obscured, child: TickerMode(enabled: !obscured, child: widget.child))),
        if (lock.locked)
          const _OwnNavigator(key: ValueKey('lock'), child: LockScreen())
        else if (hidden)
          const _OwnNavigator(key: ValueKey('neutral'), child: NeutralScreen())
        else if (lock.covered)
          ColoredBox(color: Theme.of(context).colorScheme.surface),
      ],
    );
  }
}

/// A navigator for a screen shown outside the app's router, so sheets and dialogs have somewhere
/// to open. It has its own ScaffoldMessenger too.
class _OwnNavigator extends StatelessWidget {
  const _OwnNavigator({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: HeroControllerScope.none(
        child: Navigator(
          pages: [MaterialPage<void>(child: child)],
          onDidRemovePage: (_) {},
        ),
      ),
    );
  }
}
