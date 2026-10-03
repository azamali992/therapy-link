import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/app/theme/theme.dart' show buildTheme;
import 'package:therapylink/core/api/api_client.dart';
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/assessments/assessment_outbox.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/features/today/assessment_screen.dart';
import 'package:therapylink/features/shared/crisis_copy.dart';
import 'package:therapylink/features/shared/crisis_sheet.dart';
import 'package:therapylink/l10n/app_localizations.dart';

/// The server is unreachable: every submission fails and the answer is queued.
class _OfflineApi extends ApiClient {
  _OfflineApi() : super(Dio());

  int submissions = 0;

  @override
  Future<Assessment> submitAssessment(Instrument instrument, List<int> answers) async {
    submissions++;
    throw DioException(requestOptions: RequestOptions(path: '/assessments'), type: DioExceptionType.connectionError);
  }
}

class _OnlineApi extends ApiClient {
  _OnlineApi() : super(Dio());

  @override
  Future<Assessment> submitAssessment(Instrument instrument, List<int> answers) async =>
      Assessment(id: 'a', instrument: instrument, score: 1, band: 'minimal', flags: const ['suicidal_ideation_item'], takenAt: DateTime(2026));
}

/// Pumps the assessment screen inside a minimal GoRouter so context.go('/today') works.
Future<SharedPreferences> _pump(WidgetTester tester, ApiClient api) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/today/assess/phq9',
    routes: [
      GoRoute(path: '/today', builder: (_, _) => const Scaffold(body: Text('today'))),
      GoRoute(
        path: '/today/assess/phq9',
        builder: (_, _) => const AssessmentScreen(instrument: Instrument.phq9),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

/// Answers all nine PHQ-9 items with [itemNine] for item 9 (0=Not at all, 1=Several days).
Future<void> _answer(WidgetTester tester, int itemNine) async {
  final l = AppLocalizations.of(tester.element(find.byType(AssessmentScreen)));
  final options = [l.optNotAtAll, l.optSeveralDays, l.optMoreThanHalf, l.optNearlyEveryDay];
  for (var i = 0; i < 9; i++) {
    await tester.tap(find.text(i == 8 ? options[itemNine] : options[0]));
    await tester.pumpAndSettle();
    await tester.tap(find.text(i == 8 ? l.assessmentFinish : l.assessmentNext));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() {
    helplineDialer = (_) async => true;
  });

  test('item 9 above "not at all" is flagged on PHQ-9 only', () {
    expect(itemNineFlagged(Instrument.phq9, [0, 0, 0, 0, 0, 0, 0, 0, 1]), isTrue);
    expect(itemNineFlagged(Instrument.gad7, [0, 0, 0, 0, 0, 0, 1]), isFalse);
    expect(itemNineFlagged(Instrument.phq9, [0, 0, 0, 0, 0, 0, 0, 0, 0]), isFalse);
  });

  testWidgets('a positive item 9 shows help on the phone even when the server cannot be reached', (tester) async {
    final api = _OfflineApi();
    final prefs = await _pump(tester, api);

    await _answer(tester, 1);

    // One submission attempt was made.
    expect(api.submissions, 1);
    // The crisis sheet appeared on the phone, without waiting for the server.
    expect(find.text(CrisisCopy.en.title(CrisisKind.suicide)), findsOneWidget);
    await tester.tap(find.text(CrisisCopy.en.keepTalking));
    await tester.pumpAndSettle();

    // Offline: navigated back to /today.
    expect(find.text('today'), findsOneWidget);

    // The answers are kept to send later.
    expect(AssessmentOutbox(prefs).pending.single.answers, [0, 0, 0, 0, 0, 0, 0, 0, 1]);
  });

  testWidgets('no flag on item 9, no sheet', (tester) async {
    await _pump(tester, _OfflineApi());
    await _answer(tester, 0);
    expect(find.text(CrisisCopy.en.keepTalking), findsNothing);
    // Offline with no flag: navigated back to /today with the outbox entry.
    expect(find.text('today'), findsOneWidget);
  });

  test('the outbox sends what is queued once the server is back', () async {
    SharedPreferences.setMockInitialValues({});
    final outbox = AssessmentOutbox(await SharedPreferences.getInstance());
    await outbox.add(Instrument.phq9, [0, 0, 0, 0, 0, 0, 0, 0, 1]);

    expect(await outbox.flush(_OfflineApi()), 0);
    expect(outbox.pending, hasLength(1));
    expect(await outbox.flush(_OnlineApi()), 1);
    expect(outbox.pending, isEmpty);
  });
}
