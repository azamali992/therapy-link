import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/quick_exit.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/jugnu_scaffold.dart';
import '../../ui/jugnu_icons.dart';
import 'widgets.dart';

/// Shown over everything while the app lock is on. Neutral: no app name, nothing from inside.
/// Help is always reachable and opens without unlocking — someone in crisis must never meet a
/// lock screen first.
class LockScreen extends ConsumerWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final lock = ref.watch(appLockProvider);

    return JugnuScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Get help is always at the top — no app identity, help only.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Jugnu.s20, Jugnu.s8, Jugnu.s16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GetHelpButton(),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Jugnu.s24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Lock glyph.
                        Icon(
                          JugnuIcons.lock,
                          size: 40,
                          color: colors.protectedState,
                        ),
                        const SizedBox(height: Jugnu.s20),
                        Text(
                          l.lockTitle,
                          style: t.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Jugnu.s8),
                        Text(
                          l.lockBody,
                          style: t.bodyMedium?.copyWith(color: colors.ink2),
                          textAlign: TextAlign.center,
                        ),
                        if (lock.failed) ...[
                          const SizedBox(height: Jugnu.s12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              l.lockFailed,
                              style: t.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: Jugnu.s24),
                        // Primary unlock button.
                        PrimaryButton(
                          label: l.lockUnlock,
                          onPressed: lock.busy
                              ? () {}
                              : () => ref
                                    .read(appLockProvider.notifier)
                                    .unlock(l.lockReason),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    return JugnuScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Always show Get help, nothing else identifiable.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Jugnu.s20, Jugnu.s8, Jugnu.s16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GetHelpButton(),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Jugnu.s24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.quickExitNeutral,
                        style: t.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Jugnu.s16),
                      GhostButton(
                        label: context.l10n.continueLabel,
                        onPressed: () => ref
                            .read(quickExitProvider.notifier)
                            .dismiss(context.l10n.lockReason),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
