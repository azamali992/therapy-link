// Tests that the app shell boots correctly: routes to /welcome and renders the
// screen with the "Get help now" button present before sign-in.
//
// Firebase is bypassed by overriding authStateProvider directly so
// FirebaseAuth.instance is never called during the test run.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:therapylink/app/app.dart';
import 'package:therapylink/core/auth/auth_providers.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/ui/components/jugnu_app_bar.dart' as ui;

/// Pumps [TherapyLinkApp] with real provider overrides that keep the app at
/// /welcome (empty prefs → not consented, not onboarded; auth stream → null).
Future<void> pumpApp(WidgetTester tester) async {
  // Provide empty SharedPreferences so settingsProvider can boot.
  // Defaults: onboarded=false, consentVersion=null → consented=false.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Real settings backed by empty prefs: not onboarded, not consented.
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Not signed in — bypasses FirebaseAuth entirely.
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const TherapyLinkApp(),
    ),
  );
  // Allow the router to settle and Google Fonts to skip network fetches.
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

void main() {
  group('platform boot', () {
    testWidgets('app routes to /welcome on first launch', (tester) async {
      await pumpApp(tester);

      // The welcome screen title ('TherapyLink') should be visible in the AppBar.
      expect(find.text('TherapyLink'), findsWidgets);
    });

    testWidgets('Get help button is present on the welcome screen', (tester) async {
      await pumpApp(tester);

      // The Jugnu GetHelpButton is a labelled pill, reachable before sign-in.
      final help = find.byType(ui.GetHelpButton);
      expect(help, findsOneWidget);

      // Tapping it must open the crisis sheet with a real helpline number.
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.textContaining('1122'), findsWidgets);
    });

    testWidgets('welcome screen copy is rendered', (tester) async {
      await pumpApp(tester);

      // "Someone to talk to" — first line of the welcome body copy.
      expect(
        find.textContaining('talk', findRichText: true),
        findsWidgets,
      );
    });
  });
}
