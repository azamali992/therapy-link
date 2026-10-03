// Assessment locale tests (model and API layer) and clinician patient view
// widget tests. Restored/adapted from v2 api_assessment_locale_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/core/api/api_client.dart';
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/clinician/patient_screen.dart';

import 'api_harness.dart';
import 'platform_harness.dart';

Map<String, dynamic> _assessment(String id,
        {String? locale, int score = 12, List<String>? flags}) =>
    {
      'id': id,
      'instrument': 'phq9',
      'score': score,
      'band': 'moderate',
      'flags': flags ?? <String>[],
      'taken_at': '2026-09-20T10:00:00Z',
      'locale': ?locale,
    };

void main() {
  group('assessment locale', () {
    test('submitAssessment sends the app language with the answers', () async {
      final dio = fakeDio((_) => reply(201, _assessment('a1', locale: 'ur')));
      final a = await ApiClient(dio, locale: () => 'ur')
          .submitAssessment(Instrument.phq9, List.filled(9, 0));
      final body = adapterOf(dio).requests.single.data as Map;
      expect(body['locale'], 'ur');
      expect(body['instrument'], 'phq9');
      expect(a.locale, 'ur');
      expect(a.unvalidatedTranslation, isTrue);
    });

    test('the provider takes the language chosen in settings', () async {
      SharedPreferences.setMockInitialValues({'locale': 'ur'});
      final prefs = await SharedPreferences.getInstance();
      final dio = fakeDio((_) => reply(201, _assessment('a1')));
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dioProvider.overrideWithValue(dio)
      ]);
      addTearDown(container.dispose);
      await container
          .read(apiClientProvider)
          .submitAssessment(Instrument.gad7, List.filled(7, 1));
      expect(
          (adapterOf(dio).requests.single.data as Map)['locale'], 'ur');

      await container
          .read(settingsProvider.notifier)
          .setLocale(const Locale('en'));
      await container
          .read(apiClientProvider)
          .submitAssessment(Instrument.gad7, List.filled(7, 1));
      expect(
          (adapterOf(dio).requests.last.data as Map)['locale'], 'en');
    });

    test('only en and ur reach the server', () {
      expect(apiLocale(const Locale('ur')), 'ur');
      expect(apiLocale(const Locale('en', 'GB')), 'en');
      expect(apiLocale(const Locale('fr')), 'en');
    });

    test('an older row with no locale is not marked as unvalidated translation',
        () {
      expect(Assessment.fromJson(_assessment('a1')).locale, isNull);
      expect(
          Assessment.fromJson(_assessment('a1')).unvalidatedTranslation,
          isFalse);
      expect(
          Assessment.fromJson(_assessment('a1', locale: 'en'))
              .unvalidatedTranslation,
          isFalse);
    });

    test('BDI-II is removed: only phq9 and gad7 exist as instruments', () {
      expect(Instrument.values.map((i) => i.name), ['phq9', 'gad7']);
    });
  });

  // ── Clinician patient view ────────────────────────────────────────────────

  group('clinician patient view', () {
    PatientOverview makeOverview({
      List<Map<String, dynamic>> assessments = const [],
      bool shareAssessments = true,
    }) =>
        PatientOverview.fromJson({
          'patient': {
            'uid': 'p1',
            'display_name': 'Ayesha',
            'role': 'patient',
            'locale': 'en',
            'clinician_verified': false,
          },
          'consent': {
            'id': 'l1',
            'patient_uid': 'p1',
            'clinician_uid': 'c1',
            'status': 'active',
            'share_assessments': shareAssessments,
            'share_mood_trend': false,
            'share_summaries': false,
            'share_journal': false,
          },
          'assessments': assessments,
        });

    Future<void> pump(WidgetTester tester, PatientOverview overview) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        const PatientScreen(uid: 'p1'),
        overrides: [
          patientOverviewProvider('p1').overrideWith((_) async => overview),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'marks a score taken in Roman Urdu, and only that one',
        (tester) async {
      final overview = makeOverview(assessments: [
        _assessment('a1', locale: 'ur', score: 14),
        _assessment('a2', locale: 'en', score: 9),
        _assessment('a3', score: 5),
      ]);
      await pump(tester, overview);

      // Score 14 (Roman Urdu) should be present.
      expect(find.text('14'), findsOneWidget);
      // The unvalidated translation notice should appear exactly once.
      expect(find.byType(UnvalidatedTranslationNotice), findsOneWidget);
      // It should be positioned near the score '14'.
      expect(
        tester.getCenter(find.byType(UnvalidatedTranslationNotice)).dy,
        closeTo(tester.getCenter(find.text('14')).dy, 40),
      );
    });

    testWidgets('no Roman Urdu score, no notice', (tester) async {
      final overview = makeOverview(assessments: [
        _assessment('a2', locale: 'en', score: 9),
      ]);
      await pump(tester, overview);

      expect(find.byType(UnvalidatedTranslationNotice), findsNothing);
    });

    testWidgets('shows the "pattern not a diagnosis" footnote',
        (tester) async {
      final overview = makeOverview(assessments: [
        _assessment('a1', locale: 'en', score: 10),
      ]);
      await pump(tester, overview);

      expect(
        find.textContaining('A pattern, not a diagnosis.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'shows no consent message when patient shares nothing',
        (tester) async {
      final overview = makeOverview(shareAssessments: false);
      await pump(tester, overview);

      expect(
          find.text("This patient hasn't shared anything yet."), findsOneWidget);
    });
  });
}
