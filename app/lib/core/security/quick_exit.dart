import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock.dart';
import 'privacy_settings.dart';

/// Leaves the app. Android closes it to the home screen; iOS doesn't let an app close itself, so
/// there the neutral screen is where it stops. Tests swap in a recorder.
final quickExitPlatformProvider = Provider<Future<void> Function()>((_) => _leaveApp);

Future<void> _leaveApp() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await SystemNavigator.pop();
}

/// True while the neutral screen is up after a quick exit. The app frame listens: it covers
/// everything at once and sends navigation back to the start underneath.
class QuickExitController extends Notifier<bool> {
  /// Set when the exit happened with the app lock on: the way back in is then the phone's lock,
  /// not one tap on Continue, or whoever the exit was for could just walk back in.
  bool _needsUnlock = false;

  @override
  bool build() {
    // Unlocking from the lock screen (after the app was away too long) already asked the phone.
    ref.listen(appLockProvider.select((s) => s.locked), (was, locked) {
      if (was == true && !locked) _needsUnlock = false;
    });
    return false;
  }

  Future<void> exit() async {
    _needsUnlock = ref.read(privacySettingsProvider).appLock;
    state = true;
    // The recent-apps preview is taken as the app leaves. With the lock off FLAG_SECURE is off, so
    // turn it on for the way out, and let the neutral screen reach the screen before leaving.
    await ref.read(secureWindowProvider)(true);
    await _nextFrame();
    await ref.read(quickExitPlatformProvider)();
  }

  /// Continue on the neutral screen. With the app lock on this asks the phone first; if the phone
  /// says no, the neutral screen stays.
  Future<void> dismiss(String reason) async {
    if (!state) return;
    if (_needsUnlock && !await ref.read(appLockProvider.notifier).confirm(reason)) return;
    _needsUnlock = false;
    state = false;
    await ref.read(secureWindowProvider)(ref.read(privacySettingsProvider).appLock);
  }
}

/// Waits for the frame that paints the neutral screen. Bounded, so an exit never hangs on a frame
/// that will not come.
Future<void> _nextFrame() async {
  final binding = WidgetsBinding.instance;
  await binding.endOfFrame.timeout(const Duration(milliseconds: 500), onTimeout: () {});
}

final quickExitProvider = NotifierProvider<QuickExitController, bool>(QuickExitController.new);
