import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:therapylink/core/api/api_client.dart';
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/core/ml/onnx_guardian.dart';
import 'package:therapylink/features/journal/journal_editor_screen.dart';
import 'package:therapylink/features/shared/crisis_copy.dart';
import 'package:therapylink/features/shared/crisis_sheet.dart';
import 'package:therapylink/l10n/app_localizations.dart';

class _Api extends ApiClient {
  _Api({this.offline = false}) : super(Dio());

  /// Every save fails, as it does with no connection.
  final bool offline;
  final saved = <String>[];

  @override
  Future<List<JournalEntry>> journal() async => const [];

  @override
  Future<JournalEntry> createJournal({String? title, required String body, int? mood}) async {
    if (offline) throw DioException(requestOptions: RequestOptions(path: '/journal'), type: DioExceptionType.connectionError);
    saved.add(body);
    return JournalEntry(id: 'j', title: title, body: body, mood: mood, createdAt: DateTime(2026), updatedAt: DateTime(2026));
  }
}

Future<_Api> _pump(WidgetTester tester, {bool offline = false}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = _Api(offline: offline);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('journal list'))),
      GoRoute(path: '/new', builder: (_, _) => const JournalEditorScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        guardianProvider.overrideWithValue(HeuristicGuardian()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Open the editor on top of the list, so saving has somewhere to pop back to.
  router.push('/new');
  await tester.pumpAndSettle();
  return api;
}

Future<void> _write(WidgetTester tester, String body) async {
  final l = AppLocalizations.of(tester.element(find.byType(JournalEditorScreen)));
  await tester.enterText(find.widgetWithText(TextField, l.journalBodyHint), body);
  await tester.tap(find.text(l.journalSave));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    helplineDialer = (_) async => true;
  });

  testWidgets('an entry that shows risk is saved, then met with help in its own language', (tester) async {
    final api = await _pump(tester);

    await _write(tester, 'aaj bohat bura din tha. mujhe zinda nahi rehna');

    expect(api.saved, hasLength(1));
    expect(find.text(CrisisCopy.romanUrdu.title(CrisisKind.suicide)), findsOneWidget);
    await tester.tap(find.text(CrisisCopy.romanUrdu.keepTalking));
    await tester.pumpAndSettle();
    expect(find.text('journal list'), findsOneWidget);
  });

  testWidgets('an ordinary entry saves and closes with no interruption', (tester) async {
    final api = await _pump(tester);

    await _write(tester, 'Went for a walk with my sister. Felt calmer after.');

    expect(api.saved, hasLength(1));
    expect(find.text(CrisisCopy.en.keepTalking), findsNothing);
    expect(find.text('journal list'), findsOneWidget);
  });

  testWidgets('an entry that shows risk still gets help when the save fails, and stays to be saved again', (tester) async {
    final api = await _pump(tester, offline: true);

    await _write(tester, 'I want to end my life');

    expect(api.saved, isEmpty);
    expect(find.text(CrisisCopy.en.title(CrisisKind.suicide)), findsOneWidget);
    await tester.tap(find.text(CrisisCopy.en.keepTalking));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(JournalEditorScreen)));
    expect(find.text(l.errorGeneric), findsOneWidget);
    expect(find.text('I want to end my life'), findsOneWidget);
  });
}
