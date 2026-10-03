import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/app/theme/theme.dart' show buildTheme;
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/features/shared/crisis_copy.dart';
import 'package:therapylink/features/shared/widgets.dart';
import 'package:therapylink/l10n/app_localizations.dart';

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    theme: buildTheme(Brightness.dark),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  late List<Uri> dialled;
  setUp(() {
    dialled = [];
    helplineDialer = (uri) async {
      dialled.add(uri);
      return true;
    };
  });

  testWidgets('the card carries the numbers, with call and copy actions', (tester) async {
    await tester.pumpWidget(_app(Scaffold(body: CrisisCard(kind: CrisisKind.suicide, copy: CrisisCopy.romanUrdu))));

    expect(find.text(CrisisCopy.romanUrdu.title(CrisisKind.suicide)), findsOneWidget);
    expect(find.text('0311 7786264'), findsOneWidget);
    expect(find.text('1122'), findsOneWidget);
    // No human has verified these yet, and debug builds say so.
    expect(find.text('unverified'), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel(CrisisCopy.romanUrdu.call('Umang')));
    await tester.pump();
    expect(dialled.single, Uri(scheme: 'tel', path: '03117786264'));
  });

  testWidgets('copy puts the number on the clipboard', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(_app(Scaffold(body: CrisisCard(kind: CrisisKind.child, copy: CrisisCopy.en))));

    await tester.tap(find.byTooltip(CrisisCopy.en.copyNumber).first);
    await tester.pump();

    expect(clipboard, '1098');
    expect(find.text(CrisisCopy.en.numberCopied), findsOneWidget);
  });

  testWidgets('when the phone cannot call, the number is shown large with Copy', (tester) async {
    helplineDialer = (uri) async => false;
    await tester.pumpWidget(_app(Scaffold(body: CrisisCard(kind: CrisisKind.suicide, copy: CrisisCopy.en))));

    await tester.tap(find.bySemanticsLabel(CrisisCopy.en.call('Umang')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(CrisisCopy.en.callFailed), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('0311 7786264')), findsOneWidget);
    expect(find.text(CrisisCopy.en.copyNumber), findsOneWidget);
  });

  testWidgets('every standard page has Get help now, and it opens the sheet', (tester) async {
    await tester.pumpWidget(_app(const Screen(title: 'Journal', child: Text('body'))));

    // GetHelpButton is a pill widget — find by type.
    await tester.tap(find.byType(GetHelpButton));
    await tester.pumpAndSettle();

    expect(find.text(CrisisCopy.en.title(CrisisKind.suicide)), findsOneWidget);
    expect(find.textContaining('0311 7786264'), findsOneWidget);
  });

  testWidgets('a page can leave the action off', (tester) async {
    await tester.pumpWidget(_app(const Screen(title: 'Caseload', help: false, child: Text('body'))));
    expect(find.byType(GetHelpButton), findsNothing);
  });

  testWidgets('the sheet fits the danger: a child gets Madadgaar first', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showCrisisSheet(context, kind: CrisisKind.child, copy: CrisisCopy.en),
          child: const Text('open'),
        ),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final madadgaar = tester.getTopLeft(find.textContaining('1098'));
    final rescue = tester.getTopLeft(find.textContaining('1122'));
    expect(madadgaar.dy, lessThan(rescue.dy));
    expect(find.textContaining('0311'), findsNothing);

    // CrisisSheetView renders a separate "Call" pill button per helpline.
    // Madadgaar is first in the sheet, so find.text('Call').first is its button.
    await tester.tap(find.text('Call').first);
    await tester.pump();
    expect(dialled.single.path, '1098');
  });

  testWidgets('calling with no arguments opens the default suicide help sheet', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => showCrisisSheet(context), child: const Text('open')),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(CrisisCopy.en.keepTalking), findsOneWidget);
    expect(find.text(CrisisCopy.en.title(CrisisKind.suicide)), findsOneWidget);
  });
}
