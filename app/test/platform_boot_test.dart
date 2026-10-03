// Tests that the app shell boots correctly: routes to /welcome and renders the
// screen with the "Get help now" button present before sign-in.
//
// Firebase is bypassed by overriding the auth stub provider so no real
// network call is made during the test run.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:therapylink/app/app.dart';
import 'package:therapylink/app/router.dart';

// ---------------------------------------------------------------------------
// Minimal Firebase stub — avoids requiring a real Firebase project in tests.
// The test overrides auth/consent providers so Firebase is never initialised.
// ---------------------------------------------------------------------------

/// Pumps [TherapyLinkApp] with stub overrides that keep the app at /welcome
/// (not consented, not signed in).
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Not consented → router sends the user to /welcome.
        consentedStubProvider.overrideWithValue(false),
        onboardedStubProvider.overrideWithValue(false),
        authStateStubProvider.overrideWith((_) => const AsyncValue.data(null)),
        isClinicianStubProvider.overrideWithValue(false),
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

      // GetHelpButton renders an IconButton with the getHelpNow tooltip.
      // We find it by tooltip text after l10n resolves.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              (w.tooltip?.toLowerCase().contains('help') ?? false),
        ),
        findsWidgets,
      );
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
