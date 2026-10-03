import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/quick_exit.dart';
import 'crisis_copy.dart';
import 'widgets.dart';

/// Shown over everything while the app lock is on. Neutral: no app name, nothing from inside.
/// Help is on it too and opens without unlocking; someone in crisis must never meet a lock first.
class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lock = ref.watch(appLockProvider);
    final copy = CrisisCopy.forContext(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Tokens.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 40, color: scheme.primary),
                  const SizedBox(height: Tokens.s20),
                  Text(l.lockTitle, style: t.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: Tokens.s8),
                  Text(l.lockBody, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                  if (lock.failed) ...[
                    const SizedBox(height: Tokens.s12),
                    Semantics(
                      liveRegion: true,
                      child: Text(l.lockFailed, style: t.bodyMedium?.copyWith(color: scheme.error), textAlign: TextAlign.center),
                    ),
                  ],
                  const SizedBox(height: Tokens.s24),
                  FilledButton.icon(
                    onPressed: lock.busy ? null : () => ref.read(appLockProvider.notifier).unlock(l.lockReason),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(l.lockUnlock),
                  ),
                  const SizedBox(height: Tokens.s12),
                  OutlinedButton.icon(
                    onPressed: () => showCrisisSheet(context, copy: copy),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: scheme.tertiary,
                      side: BorderSide(color: scheme.tertiary),
                    ),
                    icon: const Icon(Icons.support_rounded),
                    label: Text(copy.helpNow),
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

/// Where a quick exit lands: nothing on it says what the app is.
class NeutralScreen extends ConsumerWidget {
  const NeutralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, actions: const [GetHelpButton()]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.quickExitNeutral, style: t.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: Tokens.s16),
              TextButton(onPressed: () => ref.read(quickExitProvider.notifier).dismiss(context.l10n.lockReason), child: Text(context.l10n.continueLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
