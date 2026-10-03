import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'privacy_settings.dart';

enum AuthOutcome {
  success,

  /// Cancelled, not recognised, or locked out for a while. The lock stays.
  failed,

  /// The phone has no biometric, PIN, pattern or password set, so nothing can be checked.
  unavailable,
}

/// The phone's own lock: fingerprint or face, falling back to the PIN, pattern or password.
/// An interface so widget tests can answer without a device.
abstract interface class Authenticator {
  Future<AuthOutcome> authenticate(String reason);
}

class DeviceAuthenticator implements Authenticator {
  DeviceAuthenticator([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return AuthOutcome.unavailable;
      // biometricOnly false: the PIN always works, so a wet finger or a mask never shuts anyone
      // out. persistAcrossBackgrounding keeps the prompt alive if a call comes in.
      final ok = await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
      return ok ? AuthOutcome.success : AuthOutcome.failed;
    } on LocalAuthException catch (e) {
      return e.code == LocalAuthExceptionCode.noCredentialsSet ? AuthOutcome.unavailable : AuthOutcome.failed;
    } on PlatformException {
      return AuthOutcome.failed;
    } on MissingPluginException {
      return AuthOutcome.unavailable;
    }
  }
}

final authenticatorProvider = Provider<Authenticator>((_) => DeviceAuthenticator());

/// What time it is. Tests move it forward instead of waiting.
final lockClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

final _sinceStart = Stopwatch()..start();

/// Time since the app started, from a monotonic clock that changing the phone's date and time
/// does not move. Tests move it forward instead of waiting.
final lockElapsedProvider = Provider<Duration Function()>((_) => () => _sinceStart.elapsed);

/// Keeps the app's content out of screenshots and the recent-apps preview: FLAG_SECURE on
/// Android, a cover view on iOS while the app is inactive. Tests swap in a recorder.
final secureWindowProvider = Provider<Future<void> Function(bool secure)>((_) => _setSecureWindow);

const _privacyChannel = MethodChannel('therapylink/privacy');

Future<void> _setSecureWindow(bool secure) async {
  if (kIsWeb) return;
  try {
    await _privacyChannel.invokeMethod<void>('setSecure', {'secure': secure});
  } on MissingPluginException {
    // Desktop and tests: nothing to hide from.
  } on PlatformException catch (e) {
    debugPrint('could not change the secure window flag: ${e.code}');
  }
}

@immutable
class AppLockState {
  const AppLockState({this.locked = false, this.covered = false, this.busy = false, this.failed = false});

  /// The lock screen is up; only the phone's lock takes it down.
  final bool locked;

  /// The app is in the background with the lock on. Its content is hidden until it is back and
  /// the timeout has been checked, so nothing flashes before the lock screen does.
  final bool covered;

  /// The phone's prompt is showing.
  final bool busy;

  /// The last attempt didn't unlock.
  final bool failed;

  AppLockState copyWith({bool? locked, bool? covered, bool? busy, bool? failed}) => AppLockState(
    locked: locked ?? this.locked,
    covered: covered ?? this.covered,
    busy: busy ?? this.busy,
    failed: failed ?? this.failed,
  );
}

/// Locks on open and on coming back after [timeout] in the background, when the person has turned
/// the lock on. Crisis help is never behind it: the lock screen carries its own way to it.
class AppLockController extends Notifier<AppLockState> {
  static const timeout = Duration(seconds: 60);

  DateTime? _backgroundAt;
  Duration? _backgroundElapsed;

  bool get _enabled => ref.read(privacySettingsProvider).appLock;

  @override
  AppLockState build() {
    // Turning the lock off from Settings (only reachable unlocked) drops any cover with it.
    ref.listen(privacySettingsProvider.select((s) => s.appLock), (_, on) {
      if (!on) state = const AppLockState();
    });
    return AppLockState(locked: _enabled);
  }

  void onBackground() {
    // The phone's own prompt sends the app to the background on some devices; that is not
    // leaving the app.
    if (!_enabled || state.busy) return;
    _backgroundAt ??= ref.read(lockClockProvider)();
    _backgroundElapsed ??= ref.read(lockElapsedProvider)();
    state = state.copyWith(covered: true);
  }

  void onResume() {
    if (state.busy) return;
    final since = _backgroundAt;
    final sinceElapsed = _backgroundElapsed;
    _backgroundAt = null;
    _backgroundElapsed = null;
    if (!_enabled) {
      state = const AppLockState();
      return;
    }
    final away = since != null && sinceElapsed != null && _awayTooLong(since, sinceElapsed);
    state = state.copyWith(covered: false, locked: state.locked || away, failed: away ? false : null);
  }

  /// Two clocks, because neither is enough alone. The wall clock keeps counting while the phone
  /// sleeps but can be set back in Settings to skip the lock; the monotonic one can't be set, but
  /// on Android it pauses in deep sleep. Either one reaching the timeout locks, and so does the
  /// wall clock going backwards by more than a network time correction would move it, which
  /// happens when someone set it back.
  bool _awayTooLong(DateTime since, Duration sinceElapsed) {
    final wall = ref.read(lockClockProvider)().difference(since);
    final monotonic = ref.read(lockElapsedProvider)() - sinceElapsed;
    return wall < -_clockSlack || wall >= timeout || monotonic >= timeout;
  }

  static const _clockSlack = Duration(seconds: 5);

  /// Asks the phone. If it has no lock at all any more there is nothing to check against, so the
  /// app opens and the setting goes off rather than shutting the person out of their own data.
  Future<void> unlock(String reason) async {
    if (state.busy) return;
    if (await _ask(reason)) state = const AppLockState();
  }

  /// Asks the phone before something the lock guards (leaving the quick-exit screen) without the
  /// lock screen being up. True when it may go ahead: the lock is off, the phone said yes, or the
  /// phone has no lock any more.
  Future<bool> confirm(String reason) async {
    if (!_enabled) return true;
    if (state.busy) return false;
    return _ask(reason);
  }

  Future<bool> _ask(String reason) async {
    state = state.copyWith(busy: true, failed: false);
    final outcome = await ref.read(authenticatorProvider).authenticate(reason);
    switch (outcome) {
      case AuthOutcome.success:
        state = state.copyWith(busy: false);
        return true;
      case AuthOutcome.failed:
        state = state.copyWith(busy: false, failed: true);
        return false;
      case AuthOutcome.unavailable:
        state = const AppLockState();
        await ref.read(privacySettingsProvider.notifier).setAppLock(false);
        return true;
    }
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
