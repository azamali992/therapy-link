import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/settings.dart';

/// Protection against someone else picking up or looking at the phone. These belong to the phone,
/// not to an account, so sign-out leaves them as they are.
@immutable
class PrivacySettings {
  const PrivacySettings({this.appLock = false, this.quickExit = true});

  /// Ask for the phone's biometric or PIN on open and after a minute away. Off until chosen: a lock
  /// someone didn't ask for is a way to be shut out of their own support.
  final bool appLock;

  /// Show the quick-exit button on every page. On by default, so it is already there the first
  /// time it is needed.
  final bool quickExit;

  PrivacySettings copyWith({bool? appLock, bool? quickExit}) =>
      PrivacySettings(appLock: appLock ?? this.appLock, quickExit: quickExit ?? this.quickExit);
}

class PrivacySettingsNotifier extends Notifier<PrivacySettings> {
  static const _kAppLock = 'appLock';
  static const _kQuickExit = 'quickExit';

  /// Null where no prefs were provided (some widget tests); the defaults then hold in memory.
  SharedPreferences? get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  PrivacySettings build() {
    final p = _prefs;
    return PrivacySettings(appLock: p?.getBool(_kAppLock) ?? false, quickExit: p?.getBool(_kQuickExit) ?? true);
  }

  Future<void> setAppLock(bool v) async {
    state = state.copyWith(appLock: v);
    await _prefs?.setBool(_kAppLock, v);
  }

  Future<void> setQuickExit(bool v) async {
    state = state.copyWith(quickExit: v);
    await _prefs?.setBool(_kQuickExit, v);
  }
}

final privacySettingsProvider = NotifierProvider<PrivacySettingsNotifier, PrivacySettings>(PrivacySettingsNotifier.new);
