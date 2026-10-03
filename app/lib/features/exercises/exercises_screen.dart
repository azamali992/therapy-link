import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/security/privacy_settings.dart';
import '../../core/security/quick_exit.dart';
import '../../ui/components/jugnu_app_bar.dart' as jab;
import '../../ui/components/jugnu_scaffold.dart';
import '../../ui/components/slab.dart';
import '../../ui/presence/breath_clock.dart';
import '../../ui/presence/breath_flower.dart';
import '../shared/widgets.dart' show showCrisisSheet, L10nX;

/// /today/exercises/:id -- exercise list, box breathing, and text-led sessions.
///
/// Route [id] values:
///   'list' or null → exercise list
///   'box'          → BreathFlower box-breathing screen
///   'sigh'         → text-led reset-breath screen
///   '478' / 'calming' → text-led 4-7-8 screen
class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    return switch (id) {
      'box' => const _BoxBreathingScreen(),
      'sigh' => _TextLedScreen(id: 'sigh'),
      '478' || 'calming' => _TextLedScreen(id: '478'),
      _ => const _ExerciseListScreen(),
    };
  }
}

// ---------------------------------------------------------------------------
// Exercise list
// ---------------------------------------------------------------------------

class _ExerciseListScreen extends StatelessWidget {
  const _ExerciseListScreen();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;

    final exercises = [
      (id: 'sigh', title: l.exerciseSigh, sub: l.exerciseSighSub),
      (id: 'box', title: l.exerciseBox, sub: l.exerciseBoxSub),
      (id: '478', title: l.exerciseCalming, sub: l.exerciseCalmingSub),
    ];

    return JugnuScaffold(
      appBar: jab.JugnuAppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => context.go('/today'),
        ),
        title: Text(l.exercisesTitle, style: t.titleMedium),
        onGetHelp: () => showCrisisSheet(context),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Jugnu.readingWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  Jugnu.s20, Jugnu.s8, Jugnu.s20, Jugnu.s48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.exercisesSub,
                      style: t.bodyMedium?.copyWith(color: colors.ink2)),
                  const SizedBox(height: Jugnu.s16),
                  for (final ex in exercises) ...[
                    Slab(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Jugnu.slabPadding, vertical: 14),
                      child: GestureDetector(
                        onTap: () =>
                            context.go('/today/exercises/${ex.id}'),
                        child: Semantics(
                          button: true,
                          label: ex.title,
                          child: Container(
                            constraints: const BoxConstraints(
                                minHeight: Jugnu.minTarget),
                            child: Row(
                              children: [
                                const Icon(Icons.air_rounded, size: 22),
                                const SizedBox(width: Jugnu.s12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(ex.title, style: t.bodyLarge),
                                      Text(ex.sub,
                                          style: t.bodyMedium?.copyWith(
                                              color: colors.ink2)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: colors.ink3, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Jugnu.s12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Box-breathing screen — BreathFlower + phase UI
// ---------------------------------------------------------------------------

class _BoxBreathingScreen extends ConsumerStatefulWidget {
  const _BoxBreathingScreen();

  @override
  ConsumerState<_BoxBreathingScreen> createState() =>
      _BoxBreathingScreenState();
}

class _BoxBreathingScreenState extends ConsumerState<_BoxBreathingScreen> {
  final _flowerKey = GlobalKey<BreathFlowerState>();
  StreamSubscription<BreathClockTick>? _sub;
  // Initialise to phase 0 so "Breathe in" is shown before the first clock tick.
  BreathClockTick _tick = const BreathClockTick(phaseIndex: 0, secondsLeft: 4);
  bool _paused = false;

  // The four step-pill labels shown beneath the flower.
  static const _pillLabels = ['In 4', 'Hold 4', 'Out 4', 'Hold 4'];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onClock(Stream<BreathClockTick> stream) {
    _sub?.cancel();
    _sub = stream.listen((tick) {
      if (mounted) setState(() => _tick = tick);
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _flowerKey.currentState?.pause();
    } else {
      _flowerKey.currentState?.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final showQuickExit =
        ref.watch(privacySettingsProvider.select((s) => s.quickExit));

    final phaseLabel = _tick.phaseLabel;
    final secondsLeft = _tick.secondsLeft;
    final activePhase = _tick.phaseIndex;

    return JugnuScaffold(
      appBar: jab.JugnuAppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => context.go('/today'),
        ),
        title: Text(l.exerciseBox, style: t.titleMedium),
        onGetHelp: () => showCrisisSheet(context),
        showQuickExit: showQuickExit,
        onQuickExit: showQuickExit
            ? () => ref.read(quickExitProvider.notifier).exit()
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Flower — centred in the available space.
            Expanded(
              child: Center(
                child: BreathFlower(
                  key: _flowerKey,
                  size: 288,
                  onClock: _onClock,
                ),
              ),
            ),

            // Phase word (display weight 300, ~30sp via displaySmall).
            Text(
              phaseLabel,
              style: t.displaySmall?.copyWith(
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: Jugnu.s8),

            // Countdown number — mono, 15sp, ink2.
            Text(
              '$secondsLeft',
              style: t.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.ink2,
              ),
            ),
            const SizedBox(height: Jugnu.s16),

            // Step pills — 4 chips, active = raised with eve-colour border.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pillLabels.length; i++) ...[
                  _StepPill(
                    label: _pillLabels[i],
                    active: i == activePhase,
                    colors: colors,
                    scheme: scheme,
                  ),
                  if (i < _pillLabels.length - 1)
                    const SizedBox(width: Jugnu.s8),
                ],
              ],
            ),
            const SizedBox(height: Jugnu.s24),

            // Pause / Resume — ghost text button, never a crisis control.
            TextButton(
              onPressed: _togglePause,
              child: Text(_paused ? l.breathResume : l.breathPause),
            ),
            const SizedBox(height: Jugnu.s12),

            // Stop note — static, never animated.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Jugnu.s32),
              child: Text(
                l.breathStop,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: colors.ink2),
              ),
            ),
            const SizedBox(height: Jugnu.s32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step pill chip
// ---------------------------------------------------------------------------

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.label,
    required this.active,
    required this.colors,
    required this.scheme,
  });

  final String label;
  final bool active;
  final JugnuColors colors;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? colors.raised : colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? colors.eve : colors.hair,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: t.labelMedium?.copyWith(
          color: active ? scheme.onSurface : colors.ink2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text-led exercise screen (sigh / 4-7-8)
// ---------------------------------------------------------------------------

class _TextLedScreen extends StatelessWidget {
  const _TextLedScreen({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;

    final title = id == 'sigh' ? l.exerciseSigh : l.exerciseCalming;
    final sub = id == 'sigh' ? l.exerciseSighSub : l.exerciseCalmingSub;

    // Step instructions per exercise type.
    final steps = id == 'sigh'
        ? [
            l.breathIn,
            l.breathIn,
            l.breathOut,
          ]
        : [
            // 4-7-8
            l.breathIn,
            l.breathHold,
            l.breathOut,
          ];

    return JugnuScaffold(
      appBar: jab.JugnuAppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => context.go('/today'),
        ),
        title: Text(title, style: t.titleMedium),
        onGetHelp: () => showCrisisSheet(context),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Jugnu.readingWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  Jugnu.s20, Jugnu.s24, Jugnu.s20, Jugnu.s48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub,
                      style: t.bodyMedium?.copyWith(color: colors.ink2)),
                  const SizedBox(height: Jugnu.s24),
                  for (var i = 0; i < steps.length; i++) ...[
                    Slab(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.raised,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: t.labelLarge,
                            ),
                          ),
                          const SizedBox(width: Jugnu.s12),
                          Text(steps[i], style: t.bodyLarge),
                        ],
                      ),
                    ),
                    const SizedBox(height: Jugnu.s8),
                  ],
                  const SizedBox(height: Jugnu.s16),
                  Text(
                    l.breathStop,
                    style: t.bodyMedium?.copyWith(color: colors.ink2),
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
