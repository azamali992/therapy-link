import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/security/app_lock.dart';
import 'package:therapylink/core/security/privacy_settings.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/shared/widgets.dart';
import 'package:therapylink/features/you/settings_screen.dart';
import 'package:therapylink/l10n/app_localizations.dart';

import 'privacy_harness.dart';

const _page = Screen(title: 'Journal', child: Text('private words'));

void main() {
  late PrivacyFakes fakes;
  setUp(() {
    fakes = PrivacyFakes();
    helplineDialer = (_) async => true;
  });

  Finder quickExit() => find.byTooltip('Quick exit');

  testWidgets('every standard page carries it, on by default', (tester) async {
    await pumpGated(tester, _page, fakes: fakes);
    expect(quickExit(), findsOneWidget);
    expect(find.byTooltip('Get help now'), findsOneWidget);
  });

  testWidgets('one tap hides everything behind a neutral screen, resets navigation and leaves', (tester) async {
    await pumpGated(tester, _page, fakes: fakes);
    await tester.tap(quickExit());
    await tester.pump();

    expect(find.text('private words'), findsNothing);
    expect(find.text('Journal'), findsNothing);
    expect(find.text('Nothing open right now.'), findsOneWidget);
    expect(fakes.resets, 1);
    expect(fakes.exits, 1);
  });

  testWidgets('help is still one tap away on the neutral screen', (tester) async {
    await pumpGated(tester, _page, fakes: fakes);
    await tester.tap(quickExit());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Get help now'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('Continue goes back into the app', (tester) async {
    await pumpGated(tester, _page, fakes: fakes);
    await tester.tap(quickExit());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('private words'), findsOneWidget);
    // The lock is off, so nothing to ask.
    expect(fakes.auth.calls, 0);
  });

  testWidgets('the neutral screen is painted, and the preview hidden, before the app leaves', (tester) async {
    var neutralShown = false;
    var pageShown = true;
    bool? secure;
    fakes.onExit = () {
      neutralShown = find.text('Nothing open right now.').evaluate().isNotEmpty;
      pageShown = find.text('private words').evaluate().isNotEmpty;
      secure = fakes.secureCalls.last;
    };
    await pumpGated(tester, _page, fakes: fakes);
    await tester.tap(quickExit());
    await tester.pumpAndSettle();
    expect(fakes.exits, 1);
    expect(neutralShown, isTrue);
    expect(pageShown, isFalse);
    // FLAG_SECURE is on for the way out even with the app lock off...
    expect(secure, isTrue);

    // ...and back to the setting once the person is in again.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(fakes.secureCalls.last, isFalse);
  });

  group('with the app lock on, Continue', () {
    Future<void> exitUnlocked(WidgetTester tester) async {
      await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      await tester.tap(quickExit());
      await tester.pumpAndSettle();
      fakes.auth.calls = 0;
    }

    testWidgets('asks the phone before going back in', (tester) async {
      await exitUnlocked(tester);
      fakes.auth.next = AuthOutcome.failed;
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(fakes.auth.calls, 1);
      expect(find.text('Nothing open right now.'), findsOneWidget);
      expect(find.text('private words'), findsNothing);

      fakes.auth.next = AuthOutcome.success;
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(fakes.auth.calls, 2);
      expect(find.text('private words'), findsOneWidget);
      expect(fakes.secureCalls.last, isTrue);
    });

    testWidgets('also asks when back within the minute', (tester) async {
      await exitUnlocked(tester);
      await sendToBackground(tester);
      fakes.now = fakes.now.add(const Duration(seconds: 20));
      await bringBack(tester);
      fakes.auth.next = AuthOutcome.failed;
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('private words'), findsNothing);
    });

    testWidgets('does not ask twice right after the lock screen did', (tester) async {
      await exitUnlocked(tester);
      await sendToBackground(tester);
      fakes.now = fakes.now.add(const Duration(minutes: 5));
      await bringBack(tester);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(fakes.auth.calls, 1);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(fakes.auth.calls, 1);
      expect(find.text('private words'), findsOneWidget);
    });
  });

  testWidgets('with the app lock on, coming back after a quick exit asks to unlock first', (tester) async {
    await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    await tester.tap(quickExit());
    await tester.pumpAndSettle();

    await sendToBackground(tester);
    fakes.now = fakes.now.add(const Duration(minutes: 5));
    await bringBack(tester);
    expect(find.text('Locked'), findsOneWidget);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    // Still the neutral screen, not the page that was open.
    expect(find.text('Nothing open right now.'), findsOneWidget);
    expect(find.text('private words'), findsNothing);
  });

  testWidgets('turned off in Settings, the button goes from every page', (tester) async {
    final container = await pumpGated(
      tester,
      const SettingsScreen(),
      fakes: fakes,
      overrides: [devControlsProvider.overrideWithValue(false)],
    );
    expect(find.textContaining('someone might be looking at your screen'), findsOneWidget);
    expect(quickExit(), findsOneWidget);

    await tester.tap(find.ancestor(
      of: find.text('Quick exit'),
      matching: find.byType(InkWell),
    ).first);
    await tester.pumpAndSettle();
    expect(container.read(privacySettingsProvider).quickExit, isFalse);
    expect(container.read(sharedPreferencesProvider).getBool('quickExit'), isFalse);
    expect(quickExit(), findsNothing);
  });

  testWidgets('the button stands alone for app bars outside Screen', (tester) async {
    await pumpGated(
      tester,
      Scaffold(appBar: AppBar(actions: const [QuickExitButton()])),
      fakes: fakes,
      prefs: {'quickExit': false},
    );
    expect(quickExit(), findsNothing);
  });

  testWidgets('works without saved prefs, as in screens pumped on their own', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _page,
        ),
      ),
    );
    expect(quickExit(), findsOneWidget);
  });
}
