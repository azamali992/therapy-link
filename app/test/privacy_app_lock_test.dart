import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/security/app_lock.dart';
import 'package:therapylink/core/security/privacy_settings.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/shared/widgets.dart';
import 'package:therapylink/features/you/settings_screen.dart';

import 'privacy_harness.dart';

const _page = Screen(title: 'Journal', child: Text('private words'));

void main() {
  late PrivacyFakes fakes;
  setUp(() {
    fakes = PrivacyFakes();
    helplineDialer = (_) async => true;
  });

  Finder lockScreen() => find.text('Locked');
  Finder content() => find.text('private words');

  testWidgets('off by default: never locks, however long the app was away', (tester) async {
    await pumpGated(tester, _page, fakes: fakes);
    expect(content(), findsOneWidget);
    await sendToBackground(tester);
    fakes.now = fakes.now.add(const Duration(hours: 3));
    await bringBack(tester);
    expect(lockScreen(), findsNothing);
    expect(content(), findsOneWidget);
    expect(fakes.secureCalls, [false]);
  });

  testWidgets('on: the app opens locked, with nothing from inside showing', (tester) async {
    await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
    expect(lockScreen(), findsOneWidget);
    expect(content(), findsNothing);
    expect(find.text('Journal'), findsNothing);
    // The recent-apps preview is hidden from the start.
    expect(fakes.secureCalls, [true]);
  });

  testWidgets('unlocking with the phone lock shows the app where it was', (tester) async {
    await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(fakes.auth.calls, 1);
    expect(lockScreen(), findsNothing);
    expect(content(), findsOneWidget);
  });

  testWidgets('a failed unlock stays locked and says so', (tester) async {
    fakes.auth.next = AuthOutcome.failed;
    await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(lockScreen(), findsOneWidget);
    expect(find.text("That didn't unlock. Try again."), findsOneWidget);
    expect(content(), findsNothing);

    fakes.auth.next = AuthOutcome.success;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(content(), findsOneWidget);
  });

  testWidgets('locks again on coming back after a minute away, not before', (tester) async {
    final container = await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    await sendToBackground(tester);
    expect(container.read(appLockProvider).covered, isTrue);
    fakes.now = fakes.now.add(const Duration(seconds: 30));
    await bringBack(tester);
    expect(lockScreen(), findsNothing);
    expect(content(), findsOneWidget);

    await sendToBackground(tester);
    fakes.now = fakes.now.add(AppLockController.timeout);
    await bringBack(tester);
    expect(lockScreen(), findsOneWidget);
    expect(content(), findsNothing);
  });

  group("setting the phone's clock back does not skip the lock", () {
    Future<void> awayAndBack(WidgetTester tester, {required Duration wall, required Duration monotonic}) async {
      await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      await sendToBackground(tester);
      fakes.now = fakes.now.add(wall);
      fakes.elapsed += monotonic;
      await bringBack(tester);
    }

    testWidgets('the time set earlier than when the app left locks at once', (tester) async {
      await awayAndBack(tester, wall: const Duration(hours: -1), monotonic: const Duration(seconds: 10));
      expect(lockScreen(), findsOneWidget);
      expect(content(), findsNothing);
    });

    testWidgets('a minute gone by the monotonic clock locks, whatever the wall clock says', (tester) async {
      await awayAndBack(tester, wall: const Duration(seconds: 2), monotonic: const Duration(minutes: 5));
      expect(lockScreen(), findsOneWidget);
    });

    testWidgets('a network time correction of a second or two does not lock', (tester) async {
      await awayAndBack(tester, wall: const Duration(seconds: -2), monotonic: const Duration(seconds: 10));
      expect(lockScreen(), findsNothing);
      expect(content(), findsOneWidget);
    });
  });

  testWidgets('help opens from the lock screen without unlocking', (tester) async {
    await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
    await tester.tap(find.text('Get help now'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('Umang'), findsWidgets);
    expect(fakes.auth.calls, 0);
    expect(content(), findsNothing);

    // Closing it leaves the lock where it was.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(lockScreen(), findsOneWidget);
  });

  testWidgets('a phone with no screen lock opens the app and turns the setting off', (tester) async {
    fakes.auth.next = AuthOutcome.unavailable;
    final container = await pumpGated(tester, _page, fakes: fakes, prefs: {'appLock': true});
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(content(), findsOneWidget);
    expect(container.read(privacySettingsProvider).appLock, isFalse);
    expect(container.read(sharedPreferencesProvider).getBool('appLock'), isFalse);
    expect(fakes.secureCalls.last, isFalse);
  });

  group('Settings', () {
    Future<ProviderContainer> settings(WidgetTester tester, {Map<String, Object> prefs = const {}}) =>
        pumpGated(tester, const SettingsScreen(), fakes: fakes, prefs: prefs, overrides: [devControlsProvider.overrideWithValue(false)]);

    testWidgets('app lock is off, and turning it on asks the phone first', (tester) async {
      final container = await settings(tester);
      final tile = find.widgetWithText(SwitchListTile, 'App lock');
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(find.textContaining('Get help now still works'), findsOneWidget);

      fakes.auth.next = AuthOutcome.failed;
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(fakes.auth.calls, 1);
      expect(container.read(privacySettingsProvider).appLock, isFalse);

      fakes.auth.next = AuthOutcome.success;
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(container.read(privacySettingsProvider).appLock, isTrue);
      expect(container.read(sharedPreferencesProvider).getBool('appLock'), isTrue);
      expect(fakes.secureCalls.last, isTrue);
      // Turned on from inside the app: it doesn't lock the person out there and then.
      expect(find.text('Locked'), findsNothing);
    });

    testWidgets('a phone without a screen lock is told to set one', (tester) async {
      fakes.auth.next = AuthOutcome.unavailable;
      final container = await settings(tester);
      await tester.tap(find.widgetWithText(SwitchListTile, 'App lock'));
      await tester.pumpAndSettle();
      expect(find.text('Set a screen lock on your phone first, then turn this on.'), findsOneWidget);
      expect(container.read(privacySettingsProvider).appLock, isFalse);
    });

    testWidgets('turning it off needs no unlock', (tester) async {
      final container = await settings(tester, prefs: {'appLock': true});
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      fakes.auth.calls = 0;
      await tester.tap(find.widgetWithText(SwitchListTile, 'App lock'));
      await tester.pumpAndSettle();
      expect(fakes.auth.calls, 0);
      expect(container.read(privacySettingsProvider).appLock, isFalse);
    });
  });
}
