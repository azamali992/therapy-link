// Crisis sheet works with no network, no Firebase auth, and no SharedPreferences.
// These are the minimum conditions the sheet must meet: someone in crisis should never
// hit a crash or a missing-provider error before they can see a helpline number.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/features/shared/crisis_copy.dart';
import 'package:therapylink/features/shared/crisis_sheet.dart';
import 'package:therapylink/features/shared/widgets.dart';
import 'package:therapylink/l10n/app_localizations.dart';

/// Pumps without SharedPreferences or auth — replicates the before-sign-in state.
Widget _bare(Widget home) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  setUp(() {
    helplineDialer = (_) async => true;
  });

  testWidgets('the sheet opens before sign-in and with no providers', (tester) async {
    await tester.pumpWidget(_bare(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showCrisisSheet(context),
          child: const Text('help'),
        ),
      ),
    )));

    await tester.tap(find.text('help'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(CrisisCopy.en.title(CrisisKind.suicide)), findsOneWidget);
    expect(find.textContaining('0311'), findsWidgets);
  });

  testWidgets('the sheet opens from the GetHelpButton without any auth providers', (tester) async {
    await tester.pumpWidget(_bare(const Screen(title: 'Welcome', child: Text('body'))));

    await tester.tap(find.byTooltip(CrisisCopy.en.helpNow));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(CrisisCopy.en.keepTalking), findsOneWidget);
  });

  testWidgets('all four crisis kinds open without error', (tester) async {
    for (final kind in CrisisKind.values) {
      await tester.pumpWidget(_bare(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showCrisisSheet(context, kind: kind),
            child: const Text('open'),
          ),
        ),
      )));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget, reason: 'kind=$kind');
      expect(find.text(CrisisCopy.en.title(kind)), findsOneWidget, reason: 'kind=$kind');

      // Dismiss before the next iteration.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Roman Urdu copy is shown when crisis text is in Roman Urdu', (tester) async {
    await tester.pumpWidget(_bare(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showCrisisSheet(
            context,
            copy: CrisisCopy.forText('mujhe zinda nahi rehna'),
          ),
          child: const Text('open'),
        ),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(CrisisCopy.romanUrdu.title(CrisisKind.suicide)), findsOneWidget);
    expect(find.text(CrisisCopy.romanUrdu.keepTalking), findsOneWidget);
  });

  testWidgets('call button is present and tappable in the sheet', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_bare(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showCrisisSheet(context, copy: CrisisCopy.en),
          child: const Text('open'),
        ),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sheet uses FilledButton.icon with label "Call Umang · 0311 7786264".
    // It must be findable and tappable.
    expect(find.textContaining('Call Umang'), findsOneWidget);
    await tester.tap(find.textContaining('Call Umang'));
    await tester.pump();
    // helplineDialer returns true, so no dialog should appear.
    expect(find.byType(AlertDialog), findsNothing);
  });
}
