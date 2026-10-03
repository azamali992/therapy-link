import 'package:flutter/material.dart';

import '../shared/widgets.dart';

/// /you/settings — theme, language, text size, reduced motion, app lock.
///
/// TODO(core-team): wire all controls to settingsProvider (shared_preferences).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _themeValue = 'dark';
  String _langValue = 'en';
  bool _appLock = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.youSettings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(l.settingsTheme),
          Card(
            child: RadioGroup<String>(
              groupValue: _themeValue,
              onChanged: (v) {
                if (v != null) setState(() => _themeValue = v);
                // TODO(core-team): update settings.themeMode.
              },
              child: Column(
                children: [
                  for (final (value, label) in [
                    ('system', l.settingsThemeSystem),
                    ('light', l.settingsThemeLight),
                    ('dark', l.settingsThemeDark),
                  ])
                    RadioListTile<String>(
                      title: Text(label),
                      value: value,
                    ),
                ],
              ),
            ),
          ),
          SectionTitle(l.settingsLanguage),
          Card(
            child: RadioGroup<String>(
              groupValue: _langValue,
              onChanged: (v) {
                if (v != null) setState(() => _langValue = v);
                // TODO(core-team): update settings.locale.
              },
              child: Column(
                children: [
                  for (final (value, label) in [
                    ('en', l.welcomeEnglish),
                    ('ur', l.welcomeRomanUrdu),
                  ])
                    RadioListTile<String>(
                      title: Text(label),
                      value: value,
                    ),
                ],
              ),
            ),
          ),
          SectionTitle(l.settingsPrivacy),
          Card(
            child: SwitchListTile(
              title: Text(l.appLockTitle),
              subtitle: Text(l.appLockBody),
              value: _appLock,
              onChanged: (v) {
                setState(() => _appLock = v);
                // TODO(core-team): wire to local_auth + FLAG_SECURE channel.
              },
            ),
          ),
          SectionTitle(l.quickExitTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.quickExitBody,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
