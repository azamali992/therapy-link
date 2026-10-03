// Re-export the real implementations so screens only need to import widgets.dart.
export 'crisis_sheet.dart' show GetHelpButton, showCrisisSheet, CrisisCard, callHelpline, copyHelpline, helplineDialer;
export 'quick_exit_button.dart' show QuickExitButton;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import 'crisis_sheet.dart';
import 'quick_exit_button.dart';

/// Convenience accessor — avoids importing AppLocalizations on every screen.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

// ---------------------------------------------------------------------------
// Screen — standard page frame
// ---------------------------------------------------------------------------

/// Standard page scaffold: title, optional back, reading-width constraint.
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
  final List<Widget>? actions;
  final Widget? fab;
  final bool scroll;
  final bool padding;
  final bool help;
  final bool quickExit;

  @override
  Widget build(BuildContext context) {
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Tokens.readingWidth),
        child: Padding(
          padding: padding
              ? const EdgeInsets.fromLTRB(Tokens.s20, Tokens.s8, Tokens.s20, Tokens.s48)
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
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
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
      padding: const EdgeInsets.symmetric(vertical: Tokens.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.titleLarge),
          const SizedBox(height: Tokens.s8),
          Text(body, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: Tokens.s20), action!],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.errorGeneric),
          const SizedBox(height: Tokens.s16),
          OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 6});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Tokens.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Skeleton(width: 180), SizedBox(height: Tokens.s8), Skeleton(height: 12, width: 260)],
            ),
          ),
      ],
    );
  }
}

/// A tappable row with the same shape everywhere: leading glyph, title, subtitle, chevron.
class RowTile extends StatelessWidget {
  const RowTile({super.key, required this.title, this.subtitle, this.leading, this.onTap, this.trailing});

  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tokens.rSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Tokens.s16, horizontal: Tokens.s4),
          child: Row(
            children: [
              if (leading != null) ...[Icon(leading, color: scheme.primary), const SizedBox(width: Tokens.s16)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              trailing ?? (onTap != null ? Icon(Icons.chevron_right, color: scheme.onSurfaceVariant) : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

String moodLabel(BuildContext context, int valence) => switch (valence) {
  -2 => context.l10n.moodVeryLow,
  -1 => context.l10n.moodLow,
  0 => context.l10n.moodOkay,
  1 => context.l10n.moodGood,
  _ => context.l10n.moodGreat,
};

/// Five labelled targets. Colour never carries the meaning alone.
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.onPick, this.selected});

  final ValueChanged<int> onPick;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var v = -2; v <= 2; v++)
          Expanded(
            child: Semantics(
              button: true,
              selected: selected == v,
              label: moodLabel(context, v),
              child: InkWell(
                onTap: () => onPick(v),
                borderRadius: BorderRadius.circular(Tokens.rSmall),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: context.motion(Tokens.fast),
                        width: selected == v ? 40 : 32,
                        height: selected == v ? 40 : 32,
                        decoration: BoxDecoration(
                          color: Tokens.valenceColor(v),
                          shape: BoxShape.circle,
                          border: selected == v ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) : null,
                        ),
                      ),
                      const SizedBox(height: Tokens.s8),
                      Text(moodLabel(context, v), style: t.labelMedium, textAlign: TextAlign.center, maxLines: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String bandLabel(BuildContext context, String band) => switch (band) {
  'minimal' => context.l10n.bandMinimal,
  'mild' => context.l10n.bandMild,
  'moderate' => context.l10n.bandModerate,
  'moderately_severe' => context.l10n.bandModeratelySevere,
  _ => context.l10n.bandSevere,
};

/// [Instrument.bdi2] does not exist in v3 (licensed instrument); phq9 and gad7 only.
String instrumentTitle(BuildContext context, Instrument i) => switch (i) {
  Instrument.phq9 => context.l10n.assessmentPhq9,
  Instrument.gad7 => context.l10n.assessmentGad7,
};
