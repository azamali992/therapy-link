import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

/// Whether developer-only controls exist: cloud mode and the Guardian model download. Cloud mode
/// sends conversations to a server with no DPA or retention policy yet, and the Guardian download
/// is an unpinned, unverified file, so release builds have neither. Overridden in tests.
final devControlsProvider = Provider<bool>((_) => !kReleaseMode);

enum EveRuntime { onDevice, cloud }

/// Bump when the consent screen's text changes in substance; everyone is asked again.
const kConsentVersion = '2026-09-1';

@immutable
class Settings {
  const Settings({
    this.locale,
    this.textScale = 1.0,
    this.reduceMotion = false,
    this.themeMode = ThemeMode.system,
    this.eveRuntime = EveRuntime.onDevice,
    this.onboarded = false,
    this.conversationId = 'default',
    this.memoryEnabled = true,
    this.consentVersion,
    this.consentAcceptedAt,
  });

  final Locale? locale;
  final double textScale;
  final bool reduceMotion;
  final ThemeMode themeMode;
  final EveRuntime eveRuntime;
  final bool onboarded;

  /// Which Eve conversation is open. Older ones stay in the database.
  final String conversationId;

  /// Whether Eve keeps notes between conversations. Off means nothing is written or read.
  final bool memoryEnabled;

  /// The consent text version accepted on this phone, and when. Null until the first-run screen.
  final String? consentVersion;
  final DateTime? consentAcceptedAt;

  /// Whether the current consent text has been accepted. A new version asks again.
  bool get consented => consentVersion == kConsentVersion;

  Settings copyWith({
    Locale? locale,
    bool clearLocale = false,
    double? textScale,
    bool? reduceMotion,
    ThemeMode? themeMode,
    EveRuntime? eveRuntime,
    bool? onboarded,
    String? conversationId,
    bool? memoryEnabled,
    String? consentVersion,
    DateTime? consentAcceptedAt,
  }) => Settings(
    locale: clearLocale ? null : (locale ?? this.locale),
    textScale: textScale ?? this.textScale,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    themeMode: themeMode ?? this.themeMode,
    eveRuntime: eveRuntime ?? this.eveRuntime,
    onboarded: onboarded ?? this.onboarded,
    conversationId: conversationId ?? this.conversationId,
    memoryEnabled: memoryEnabled ?? this.memoryEnabled,
    consentVersion: consentVersion ?? this.consentVersion,
    consentAcceptedAt: consentAcceptedAt ?? this.consentAcceptedAt,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _kLocale = 'locale';
  static const _kTextScale = 'textScale';
  static const _kReduceMotion = 'reduceMotion';
  static const _kThemeMode = 'themeMode';
  static const _kEveRuntime = 'eveRuntime';
  static const _kOnboarded = 'onboarded';
  static const _kConversation = 'conversationId';
  static const _kMemory = 'memoryEnabled';
  static const _kConsentVersion = 'consentVersion';
  static const _kConsentAt = 'consentAcceptedAt';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Settings build() {
    final p = _prefs;
    final localeCode = p.getString(_kLocale);
    return Settings(
      locale: localeCode == null ? null : Locale(localeCode),
      textScale: p.getDouble(_kTextScale) ?? 1.0,
      reduceMotion: p.getBool(_kReduceMotion) ?? false,
      themeMode: ThemeMode.values[p.getInt(_kThemeMode) ?? ThemeMode.system.index],
      // A cloud choice saved by a debug build never carries into a release one.
      eveRuntime: ref.read(devControlsProvider) ? EveRuntime.values[p.getInt(_kEveRuntime) ?? 0] : EveRuntime.onDevice,
      onboarded: p.getBool(_kOnboarded) ?? false,
      conversationId: p.getString(_kConversation) ?? 'default',
      memoryEnabled: p.getBool(_kMemory) ?? true,
      consentVersion: p.getString(_kConsentVersion),
      consentAcceptedAt: DateTime.tryParse(p.getString(_kConsentAt) ?? ''),
    );
  }

  Future<void> setLocale(Locale? locale) async {
    state = state.copyWith(locale: locale, clearLocale: locale == null);
    if (locale == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, locale.languageCode);
    }
  }

  Future<void> setTextScale(double v) async {
    state = state.copyWith(textScale: v);
    await _prefs.setDouble(_kTextScale, v);
  }

  Future<void> setReduceMotion(bool v) async {
    state = state.copyWith(reduceMotion: v);
    await _prefs.setBool(_kReduceMotion, v);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    await _prefs.setInt(_kThemeMode, m.index);
  }

  Future<void> setEveRuntime(EveRuntime r) async {
    if (r == EveRuntime.cloud && !ref.read(devControlsProvider)) return;
    state = state.copyWith(eveRuntime: r);
    await _prefs.setInt(_kEveRuntime, r.index);
  }

  Future<void> setConversationId(String id) async {
    state = state.copyWith(conversationId: id);
    await _prefs.setString(_kConversation, id);
  }

  Future<void> setMemoryEnabled(bool v) async {
    state = state.copyWith(memoryEnabled: v);
    await _prefs.setBool(_kMemory, v);
  }

  Future<void> acceptConsent({DateTime? at}) async {
    final when = at ?? DateTime.now();
    state = state.copyWith(consentVersion: kConsentVersion, consentAcceptedAt: when);
    await _prefs.setString(_kConsentVersion, kConsentVersion);
    await _prefs.setString(_kConsentAt, when.toUtc().toIso8601String());
  }

  /// Opens a fresh Eve thread after the old ones were deleted. The memory choice stays: deleting
  /// chats is not a reason to switch memory back on.
  Future<void> forgetConversation() async {
    state = state.copyWith(conversationId: 'default');
    await _prefs.remove(_kConversation);
  }

  /// Forgets what belonged to the person who just left: which conversation was open, their memory
  /// choice and their consent. Consent is a person's, not the phone's, so whoever signs in next is
  /// asked again rather than inheriting it (and having it sent to the server as theirs). Device
  /// preferences (language, text size, theme) stay.
  Future<void> clearPersonal() async {
    state = Settings(
      locale: state.locale,
      textScale: state.textScale,
      reduceMotion: state.reduceMotion,
      themeMode: state.themeMode,
      eveRuntime: state.eveRuntime,
      onboarded: state.onboarded,
    );
    await _prefs.remove(_kConversation);
    await _prefs.remove(_kMemory);
    await _prefs.remove(_kConsentVersion);
    await _prefs.remove(_kConsentAt);
  }

  Future<void> setOnboarded(bool v) async {
    state = state.copyWith(onboarded: v);
    await _prefs.setBool(_kOnboarded, v);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
