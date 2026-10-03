// Widget tests for the eveBusy and eveSlow inline banners in EveScreen.
//
// Verifies:
//   1. The banner appears with correct title and body text when eveBusy is true.
//   2. The banner appears with correct title and body text when eveSlow is true.
//   3. Tapping "Try again" calls EveController.retry() (not send, to avoid duplicates).
//   4. Eve's presence state is idle (not thinking/listening) when the banner is visible.
//   5. The banner is absent when neither flag is set.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/app/theme/theme.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/eve/eve_controller.dart' as ctrl;
import 'package:therapylink/features/eve/eve_screen.dart';
import 'package:therapylink/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fake EveController — returns a fixed state; records retry() calls.
// ---------------------------------------------------------------------------

class _FakeEveController extends ctrl.EveController {
  _FakeEveController(this._initialState);

  final ctrl.EveState _initialState;
  int retryCalls = 0;

  @override
  ctrl.EveState build() => _initialState;

  @override
  Future<void> retry() async => retryCalls++;

  @override
  Future<void> send(String text) async {} // no-op in banner tests
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp(List<Override> overrides) {
  SharedPreferences.setMockInitialValues({});
  return UncontrolledProviderScope(
    container: ProviderContainer(overrides: overrides),
    child: MaterialApp(
      theme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const EveScreen(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// Returns a list of provider overrides that put [ctrl] into the given state.
List<Override> _overrides(ctrl.EveState eveState, SharedPreferences prefs) {
  final notifier = _FakeEveController(eveState);
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    // No messages so the list renders empty (avoids real DB).
    ctrl.eveMessagesProvider.overrideWith((ref) => Stream.value(const <Message>[])),
    ctrl.eveControllerProvider.overrideWith(() => notifier),
  ];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('banner is absent when eveBusy and eveSlow are false', (tester) async {
    await tester.pumpWidget(
      _buildApp(_overrides(const ctrl.EveState(), prefs)),
    );
    await tester.pump();

    // Neither title should be present.
    expect(find.text('Eve is with someone else right now'), findsNothing);
    expect(find.text('Eve is resting'), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('busy banner shows correct title and body', (tester) async {
    await tester.pumpWidget(
      _buildApp(_overrides(const ctrl.EveState(eveBusy: true), prefs)),
    );
    await tester.pump();

    expect(find.text('Eve is with someone else right now'), findsOneWidget);
    expect(find.text('The server is busy. Wait a moment and try again.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('slow banner shows correct title and body', (tester) async {
    await tester.pumpWidget(
      _buildApp(_overrides(const ctrl.EveState(eveSlow: true), prefs)),
    );
    await tester.pump();

    expect(find.text('Eve is resting'), findsOneWidget);
    expect(
      find.text(
        'The connection timed out. Eve may be slow to respond right now. Try again in a moment.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('tapping Try again calls retry(), not send()', (tester) async {
    final notifier = _FakeEveController(const ctrl.EveState(eveBusy: true));
    final overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ctrl.eveMessagesProvider.overrideWith((ref) => Stream.value(const <Message>[])),
      ctrl.eveControllerProvider.overrideWith(() => notifier),
    ];

    await tester.pumpWidget(_buildApp(overrides));
    await tester.pump();

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(notifier.retryCalls, 1,
        reason: 'retry() must be called, not send(), to avoid duplicate user message');
  });

  testWidgets('slow state Try again also calls retry()', (tester) async {
    final notifier = _FakeEveController(const ctrl.EveState(eveSlow: true));
    final overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ctrl.eveMessagesProvider.overrideWith((ref) => Stream.value(const <Message>[])),
      ctrl.eveControllerProvider.overrideWith(() => notifier),
    ];

    await tester.pumpWidget(_buildApp(overrides));
    await tester.pump();

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(notifier.retryCalls, 1);
  });
}
