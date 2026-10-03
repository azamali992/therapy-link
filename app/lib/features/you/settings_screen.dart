import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/privacy_settings.dart';
import '../../core/settings/settings.dart';
import '../../ui/components/setting_row.dart';
import '../../ui/components/slab.dart';
import '../shared/guardian_status.dart';
import '../shared/widgets.dart';
import 'account_actions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Cloud mode sends conversations off the phone, so switching to it asks first.
  Future<void> _setRuntime(
      BuildContext context, WidgetRef ref, EveRuntime r) async {
    if (r == EveRuntime.cloud) {
      final l = context.l10n;
      final ok = await confirmDestructive(
          context,
          title: l.cloudConfirmTitle,
          body: l.cloudConfirmBody,
          action: l.cloudConfirmAction);
      if (!ok) return;
    }
    await ref.read(settingsProvider.notifier).setEveRuntime(r);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final dev = ref.watch(devControlsProvider);

    return Screen(
      title: l.youSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Language ───────────────────────────────────────────────────
          SectionTitle(l.settingsLanguage),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'system', label: Text(l.settingsLanguageSystem)),
              ButtonSegment(value: 'en', label: Text(l.welcomeEnglish)),
              ButtonSegment(value: 'ur', label: Text(l.welcomeRomanUrdu)),
            ],
            selected: {s.locale?.languageCode ?? 'system'},
            onSelectionChanged: (v) => n.setLocale(
                v.first == 'system' ? null : Locale(v.first)),
          ),

          // ── Text size ──────────────────────────────────────────────────
          SectionTitle(l.settingsTextSize),
          Row(
            children: [
              Semantics(
                label: l.settingsTextSmaller,
                excludeSemantics: true,
                child: Text('A', style: t.bodySmall),
              ),
              Expanded(
                child: Slider(
                  value: s.textScale,
                  min: 0.85,
                  max: 1.6,
                  divisions: 5,
                  label: '${(s.textScale * 100).round()}%',
                  onChanged: n.setTextScale,
                ),
              ),
              Semantics(
                label: l.settingsTextLarger,
                excludeSemantics: true,
                child: Text('A', style: t.titleLarge),
              ),
            ],
          ),

          // ── Reduce motion ──────────────────────────────────────────────
          SettingRow(
            title: l.settingsReduceMotion,
            value: s.reduceMotion,
            onChanged: n.setReduceMotion,
          ),

          // ── Theme ──────────────────────────────────────────────────────
          SectionTitle(l.settingsTheme),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                  value: ThemeMode.system, label: Text(l.settingsThemeSystem)),
              ButtonSegment(
                  value: ThemeMode.light, label: Text(l.settingsThemeLight)),
              ButtonSegment(
                  value: ThemeMode.dark, label: Text(l.settingsThemeDark)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => n.setThemeMode(v.first),
          ),

          // ── Where things are kept ─────────────────────────────────────
          SectionTitle(l.youDataTitle),
          Slab(
            padding: const EdgeInsets.all(Tokens.s16),
            child: StorageRow(),
          ),

          // ── Privacy ────────────────────────────────────────────────────
          SectionTitle(l.settingsPrivacy),
          // Device lock is not meaningful in the browser build.
          if (!kIsWeb) const _AppLockTile(),
          const _QuickExitTile(),

          // ── Eve model (dev controls only) ──────────────────────────────
          SectionTitle(l.settingsModel),
          if (dev) ...[
            SegmentedButton<EveRuntime>(
              segments: [
                ButtonSegment(
                    value: EveRuntime.onDevice,
                    icon: const Icon(Icons.phone_android_rounded),
                    label: Text(l.settingsModelOnDevice)),
                ButtonSegment(
                    value: EveRuntime.cloud,
                    icon: const Icon(Icons.cloud_outlined),
                    label: Text(l.settingsModelCloud)),
              ],
              selected: {s.eveRuntime},
              onSelectionChanged: (v) => _setRuntime(context, ref, v.first),
            ),
            const SizedBox(height: Tokens.s8),
          ],
          Text(
            s.eveRuntime == EveRuntime.onDevice
                ? l.evePrivacy
                : l.evePrivacyCloud,
            style:
                t.bodySmall?.copyWith(color: colors.ink2),
          ),

          // ── Safety check ───────────────────────────────────────────────
          // Shown in every build: in a release build Eve waits for this model, so where its
          // download stands is something the person should be able to see.
          SectionTitle(l.guardianTitle),
          const GuardianStatusPanel(),
        ],
      ),
    );
  }
}

class _AppLockTile extends ConsumerWidget {
  const _AppLockTile();

  Future<void> _set(BuildContext context, WidgetRef ref, bool on) async {
    final settings = ref.read(privacySettingsProvider.notifier);
    if (!on) return settings.setAppLock(false);
    final l = context.l10n;
    final outcome =
        await ref.read(authenticatorProvider).authenticate(l.lockReason);
    if (outcome == AuthOutcome.success) return settings.setAppLock(true);
    if (outcome == AuthOutcome.unavailable && context.mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(l.appLockUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SettingRow(
      title: l.appLockTitle,
      subtitle: l.appLockBody,
      value: ref.watch(privacySettingsProvider.select((s) => s.appLock)),
      onChanged: (v) => _set(context, ref, v),
      icon: Icons.lock_outline,
    );
  }
}

class _QuickExitTile extends ConsumerWidget {
  const _QuickExitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SettingRow(
      title: l.quickExitTitle,
      subtitle: l.quickExitBody,
      value: ref.watch(privacySettingsProvider.select((s) => s.quickExit)),
      onChanged: ref.read(privacySettingsProvider.notifier).setQuickExit,
      icon: Icons.visibility_off_outlined,
    );
  }
}
