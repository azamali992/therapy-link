import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ml/onnx_guardian.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/privacy_settings.dart';
import '../../core/settings/settings.dart';
import '../shared/widgets.dart';
import 'account_actions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Cloud mode sends conversations off the phone, so switching to it asks first.
  Future<void> _setRuntime(BuildContext context, WidgetRef ref, EveRuntime r) async {
    if (r == EveRuntime.cloud) {
      final l = context.l10n;
      final ok = await confirmDestructive(context, title: l.cloudConfirmTitle, body: l.cloudConfirmBody, action: l.cloudConfirmAction);
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
    final dev = ref.watch(devControlsProvider);

    return Screen(
      title: l.youSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(l.settingsLanguage),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'system', label: Text(l.settingsLanguageSystem)),
              ButtonSegment(value: 'en', label: Text(l.welcomeEnglish)),
              ButtonSegment(value: 'ur', label: Text(l.welcomeRomanUrdu)),
            ],
            selected: {s.locale?.languageCode ?? 'system'},
            onSelectionChanged: (v) => n.setLocale(v.first == 'system' ? null : Locale(v.first)),
          ),
          SectionTitle(l.settingsTextSize),
          Row(
            children: [
              Semantics(label: l.settingsTextSmaller, excludeSemantics: true, child: Text('A', style: t.bodySmall)),
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
              Semantics(label: l.settingsTextLarger, excludeSemantics: true, child: Text('A', style: t.titleLarge)),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.settingsReduceMotion),
            value: s.reduceMotion,
            onChanged: n.setReduceMotion,
          ),
          SectionTitle(l.settingsTheme),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l.settingsThemeSystem)),
              ButtonSegment(value: ThemeMode.light, label: Text(l.settingsThemeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.settingsThemeDark)),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => n.setThemeMode(v.first),
          ),
          SectionTitle(l.settingsPrivacy),
          // The browser build is the clinician console: nothing kept locally, no device lock to ask.
          if (!kIsWeb) const _AppLockTile(),
          const _QuickExitTile(),
          SectionTitle(l.settingsModel),
          if (dev) ...[
            SegmentedButton<EveRuntime>(
              segments: [
                ButtonSegment(value: EveRuntime.onDevice, icon: const Icon(Icons.phone_android_rounded), label: Text(l.settingsModelOnDevice)),
                ButtonSegment(value: EveRuntime.cloud, icon: const Icon(Icons.cloud_outlined), label: Text(l.settingsModelCloud)),
              ],
              selected: {s.eveRuntime},
              onSelectionChanged: (v) => _setRuntime(context, ref, v.first),
            ),
            const SizedBox(height: Tokens.s8),
          ],
          Text(s.eveRuntime == EveRuntime.onDevice ? l.evePrivacy : l.evePrivacyCloud, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (dev) ...[
            SectionTitle(l.guardianTitle),
            const _GuardianRow(),
          ],
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
    final outcome = await ref.read(authenticatorProvider).authenticate(l.lockReason);
    if (outcome == AuthOutcome.success) return settings.setAppLock(true);
    if (outcome == AuthOutcome.unavailable && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l.appLockUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(l.appLockTitle),
      subtitle: Text(l.appLockBody),
      value: ref.watch(privacySettingsProvider.select((s) => s.appLock)),
      onChanged: (v) => _set(context, ref, v),
    );
  }
}

class _QuickExitTile extends ConsumerWidget {
  const _QuickExitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(l.quickExitTitle),
      subtitle: Text(l.quickExitBody),
      value: ref.watch(privacySettingsProvider.select((s) => s.quickExit)),
      onChanged: ref.read(privacySettingsProvider.notifier).setQuickExit,
    );
  }
}

class _GuardianRow extends ConsumerWidget {
  const _GuardianRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(guardianModelManagerProvider);
    final manager = ref.read(guardianModelManagerProvider.notifier);

    final body = switch (status) {
      GuardianReady() => l.guardianReady,
      GuardianDownloading(:final percent) => l.guardianDownloading(percent),
      GuardianFailed() => l.guardianFailed,
      _ => l.guardianHeuristic,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(body, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        if (status is GuardianDownloading) ...[
          const SizedBox(height: Tokens.s8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: status.percent / 100, minHeight: 6)),
        ],
        if (status is! GuardianReady && status is! GuardianDownloading) ...[
          const SizedBox(height: Tokens.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: manager.available ? manager.download : null,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.shield_outlined),
              label: Text(manager.available ? l.guardianDownload : l.guardianUnavailable),
            ),
          ),
        ],
      ],
    );
  }
}
