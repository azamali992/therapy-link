import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/core/security/app_lock.dart';
import 'package:therapylink/core/security/quick_exit.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/shared/privacy_gate.dart';
import 'package:therapylink/l10n/app_localizations.dart';

/// Answers the lock with whatever the test sets, and counts how often it was asked.
class FakeAuthenticator implements Authenticator {
  AuthOutcome next = AuthOutcome.success;
  int calls = 0;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    calls++;
    return next;
  }
}

/// Everything the privacy features reach outside Flutter, replaced by recorders.
class PrivacyFakes {
  final auth = FakeAuthenticator();
  DateTime now = DateTime(2026, 9, 25, 10);

  /// The monotonic clock, which changing the phone's time does not move.
  Duration elapsed = Duration.zero;
  final secureCalls = <bool>[];
  int exits = 0;

  /// Runs as the app leaves on a quick exit, to look at what was on screen at that moment.
  void Function()? onExit;
  int resets = 0;

  List<Override> get overrides => [
    authenticatorProvider.overrideWithValue(auth),
    lockClockProvider.overrideWithValue(() => now),
    lockElapsedProvider.overrideWithValue(() => elapsed),
    secureWindowProvider.overrideWithValue((on) async => secureCalls.add(on)),
    quickExitPlatformProvider.overrideWithValue(() async {
      exits++;
      onExit?.call();
    }),
  ];
}

/// Pumps [home] the way the app does: inside the privacy gate, from MaterialApp.builder.
Future<ProviderContainer> pumpGated(
  WidgetTester tester,
  Widget home, {
  required PrivacyFakes fakes,
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(sp), ...fakes.overrides, ...overrides]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => PrivacyGate(onQuickExit: () => fakes.resets++, child: child!),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Walks the app through the states a phone reports when it goes to the background.
Future<void> sendToBackground(WidgetTester tester) async {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

Future<void> bringBack(WidgetTester tester) async {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pumpAndSettle();
}
