/// /welcome — first screen new users see.
///
/// Always rendered in Eve's night (forced dark) regardless of the device theme.
/// Shows: language picker, "Someone to talk to, day or night.", the three
/// honest facts, Continue CTA, and a "Have an account? Sign in" link.
/// The Get help button is reachable before any account exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/settings/settings.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/jugnu_app_bar.dart';
import '../../ui/jugnu_icons.dart';
import '../../ui/presence/presence.dart';
// GetHelpButton from crisis_sheet is a plain IconButton; we use the styled
// pill from jugnu_app_bar.dart instead, so hide the crisis_sheet version.
import '../shared/crisis_sheet.dart' hide GetHelpButton;

// Dark overlay gradient matching the reference design.
// transparent 48% → night@55% at 66% → solid night at 92%.
const _kOverlay = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: [0.48, 0.66, 0.92, 1.0],
  colors: [
    Color(0x001D1E2C),
    Color(0x8C1D1E2C),
    Color(0xFF1D1E2C),
    Color(0xFF1D1E2C),
  ],
);

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  // 0 = English, 1 = Roman Urdu, 2 = Urdu script (phase 2 — shown disabled)
  int _langIndex = 0;

  void _continue() {
    // Persist the language choice and proceed to consent.
    final notifier = ref.read(settingsProvider.notifier);
    if (_langIndex == 1) {
      notifier.setLocale(const Locale('ur'));
    } else {
      notifier.setLocale(const Locale('en'));
    }
    context.go('/consent');
  }

  void _signIn() {
    // Jump straight to sign-in for returning users; mark as onboarded
    // so the redirect doesn't loop back to /welcome on next launch.
    ref.read(settingsProvider.notifier).setOnboarded(true);
    context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    // Force dark — Eve lives in her own night in both OS themes.
    return Theme(
      data: buildTheme(Brightness.dark),
      child: _WelcomeBody(
        langIndex: _langIndex,
        onLangSelect: (i) => setState(() => _langIndex = i),
        onContinue: _continue,
        onSignIn: _signIn,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — stateless; state is held by _WelcomeScreenState.
// ---------------------------------------------------------------------------

class _WelcomeBody extends StatelessWidget {
  const _WelcomeBody({
    required this.langIndex,
    required this.onLangSelect,
    required this.onContinue,
    required this.onSignIn,
  });

  final int langIndex;
  final ValueChanged<int> onLangSelect;
  final VoidCallback onContinue;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Jugnu.night,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Eve hero: full-bleed, stays above the fold ─────────────────
          Positioned.fill(child: EveHero()),

          // ── Dark gradient: fades from transparent to solid night ────────
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _kOverlay),
            ),
          ),

          // ── Foreground content ──────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top bar: brand mark + get-help pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Jugnu.s20, Jugnu.s8, Jugnu.s16, 0),
                  child: Row(
                    children: [
                      _BrandMark(),
                      const Spacer(),
                      GetHelpButton(
                        onPressed: () => showCrisisSheet(context),
                      ),
                    ],
                  ),
                ),

                // Spacer pushes main copy into Eve's clear lower 40%.
                const Spacer(),

                // Main body: language picker, title, facts
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Jugnu.s20),
                  child: _MainCopy(
                    langIndex: langIndex,
                    onLangSelect: onLangSelect,
                    l: l,
                  ),
                ),

                // Footer: CTA + sign-in link
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Jugnu.s20, 14, Jugnu.s20, Jugnu.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrimaryButton(
                        label: l.continueLabel,
                        showArrow: true,
                        onPressed: onContinue,
                      ),
                      const SizedBox(height: Jugnu.s8),
                      _HaveAccountRow(onSignIn: onSignIn, l: l),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand mark: small plum orb + "TherapyLink" in Unbounded 400 13sp
// ---------------------------------------------------------------------------

class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eve orb: plum circle with cropped eve.png
        ClipOval(
          child: SizedBox.square(
            dimension: 22,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Jugnu.plum),
                Image.asset(
                  EveAssets.poster,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.06),
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'TherapyLink',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFamily: 'Unbounded',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.01 * 13,
                color: Jugnu.ink,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Language picker pill
// ---------------------------------------------------------------------------

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    required this.selected,
    required this.onSelect,
  });

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return Semantics(
      label: 'Language',
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.hair, width: 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LangOption(
                label: 'English',
                index: 0,
                selected: selected,
                onSelect: onSelect,
                textStyle: Theme.of(context).textTheme.labelMedium,
              ),
              _LangOption(
                label: 'Roman Urdu',
                index: 1,
                selected: selected,
                onSelect: onSelect,
                textStyle: Theme.of(context).textTheme.labelMedium,
              ),
              // Urdu script — phase 2: shown disabled with "jald" tooltip.
              Semantics(
                label: 'Urdu script — coming soon',
                button: true,
                enabled: false,
                child: Tooltip(
                  message: 'jald',
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: Jugnu.minTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text(
                      'اردو',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontFamily: 'NotoNastaliqUrdu',
                            fontSize: 15,
                            color: colors.ink3.withValues(alpha: 0.5),
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.textStyle,
  });

  final String label;
  final int index;
  final int selected;
  final ValueChanged<int> onSelect;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final active = index == selected;
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: () => onSelect(index),
        child: AnimatedContainer(
          duration: Jugnu.motionPress,
          constraints:
              const BoxConstraints(minHeight: Jugnu.minTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active ? colors.raised : Colors.transparent,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: colors.hairStrong,
                      blurRadius: 0,
                      spreadRadius: 0,
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: textStyle?.copyWith(
              color: active ? Jugnu.ink : colors.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main copy: language picker + title + facts
// ---------------------------------------------------------------------------

class _MainCopy extends StatelessWidget {
  const _MainCopy({
    required this.langIndex,
    required this.onLangSelect,
    required this.l,
  });

  final int langIndex;
  final ValueChanged<int> onLangSelect;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LanguagePicker(selected: langIndex, onSelect: onLangSelect),
        const SizedBox(height: Jugnu.s16),

        // Title: Unbounded 300, 26sp, -0.02em
        Text(
          'Someone to talk to, day or night.',
          style: t.displaySmall?.copyWith(
            fontSize: 26,
            height: 1.18,
            letterSpacing: 26 * -0.02,
            color: Jugnu.ink,
          ),
        ),
        const SizedBox(height: Jugnu.s16),

        // Three honest facts
        const _Facts(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Facts list
// ---------------------------------------------------------------------------

class _Facts extends StatelessWidget {
  const _Facts();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;

    const facts = [
      (JugnuIcons.info, 'Eve is an AI companion,', ' not a therapist.'),
      (
        JugnuIcons.translate,
        'English and Roman Urdu',
        ' — mixed is fine. She understands both.'
      ),
      (
        JugnuIcons.phoneLock,
        'Chats are saved on this phone only.',
        " Eve's replies come from our server."
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, bold, rest) in facts) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon at ink colour, slightly below baseline (margin-top 1)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 20, color: Jugnu.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'AtkinsonHyperlegibleNext',
                      fontSize: 15,
                      height: 1.45,
                      color: colors.ink2,
                    ),
                    children: [
                      TextSpan(
                        text: bold,
                        style: TextStyle(
                          color: Jugnu.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: rest),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (facts.last != (icon, bold, rest)) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// "Have an account? Sign in" row
// ---------------------------------------------------------------------------

class _HaveAccountRow extends StatelessWidget {
  const _HaveAccountRow({required this.onSignIn, required this.l});

  final VoidCallback onSignIn;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return GestureDetector(
      onTap: onSignIn,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: l.haveAccount,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: Jugnu.minTarget),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: 'AtkinsonHyperlegibleNext',
                fontSize: 14,
                height: 1,
                color: colors.ink2,
              ),
              children: [
                const TextSpan(text: 'Have an account? '),
                TextSpan(
                  text: 'Sign in',
                  style: TextStyle(
                    color: Jugnu.ink,
                    decoration: TextDecoration.underline,
                    decorationColor: Jugnu.ink,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
