// Golden-image review test for Today, Assessment and Exercises screens.
//
// Renders every screen owned by the ui-today area at 360x760 dp,
// devicePixelRatio 2, in both dark and light, with realistic sample data.
// PNGs land in docs/design/screens/today/ relative to the repo root.
//
// Run with:
//   flutter test test/screens_today_review_test.dart --update-goldens
//
// Then read each PNG and iterate until it matches the approved designs.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/app/theme/theme.dart' show buildTheme;
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/features/exercises/exercises_screen.dart';
import 'package:therapylink/features/today/assessment_screen.dart';
import 'package:therapylink/features/today/insights.dart';
import 'package:therapylink/features/today/today_providers.dart';
import 'package:therapylink/features/today/today_screen.dart';
import 'package:therapylink/l10n/app_localizations.dart';
import 'package:therapylink/ui/components/week_trend.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

/// Seven days ending today (Saturday). Day 3 (Wednesday) was missed.
final _sampleWeek = [
  const WeekDay(label: 'S', isToday: false, valence: 3),
  const WeekDay(label: 'M', isToday: false, valence: 2),
  const WeekDay(label: 'T', isToday: false, valence: 4),
  const WeekDay(label: 'W', isToday: false, valence: null), // missed
  const WeekDay(label: 'T', isToday: false, valence: 1),
  const WeekDay(label: 'F', isToday: false, valence: 2),
  const WeekDay(label: 'S', isToday: true, valence: 3),
];

/// Insight with enough data — time-of-day pattern.
const _sampleInsight = MoodInsight(
  InsightKind.timeOfDay,
  worseLabel: 'evening',
  betterLabel: 'morning',
  delta: 1.2,
  samples: 18,
);

/// A past PHQ-9 assessment.
final _sampleAssessments = [
  Assessment(
    id: 'a1',
    instrument: Instrument.phq9,
    score: 11,
    band: 'moderate',
    flags: const [],
    takenAt: DateTime(2026, 9, 20),
  ),
];

/// PHQ-9 result with a delta.
final _phq9Result = Assessment(
  id: 'a2',
  instrument: Instrument.phq9,
  score: 8,
  band: 'mild',
  flags: const [],
  takenAt: DateTime(2026, 10, 3),
  delta: -3,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Loads the bundled app fonts + Material Icons into the test font registry
/// so icon glyphs and custom typefaces render correctly in golden images.
Future<void> _loadFonts() async {
  Future<ByteData> readBytes(String path) async {
    final data = await File(path).readAsBytes();
    return data.buffer.asByteData();
  }

  // Material Icons (absolute path from Flutter SDK cache)
  final iconFont = FontLoader('MaterialIcons')
    ..addFont(
      readBytes(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ),
    );
  await iconFont.load();

  // App fonts
  final appDir = Directory.current.path; // flutter test runs from app/
  for (final entry in {
    'AtkinsonHyperlegibleNext': [
      '$appDir/assets/fonts/AtkinsonHyperlegibleNext/AtkinsonHyperlegibleNext[wght].ttf',
    ],
    'AtkinsonHyperlegibleMono': [
      '$appDir/assets/fonts/AtkinsonHyperlegibleMono/AtkinsonHyperlegibleMono[wght].ttf',
    ],
    'NotoNastaliqUrdu': [
      '$appDir/assets/fonts/NotoNastaliqUrdu/NotoNastaliqUrdu[wght].ttf',
    ],
    'Unbounded': ['$appDir/assets/fonts/Unbounded/Unbounded[wght].ttf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(readBytes(path));
    }
    await loader.load();
  }
}

/// Renders [widget] at 360x760 dp (devicePixelRatio 2) inside a Jugnu-themed
/// MaterialApp and saves a golden PNG to docs/design/screens/today/.
Future<void> _pump(
  WidgetTester tester,
  String name,
  Widget widget, {
  required Brightness brightness,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(360 * 2, 760 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(brightness),
        home: widget,
      ),
    ),
  );
  await tester.pumpAndSettle();

  final suffix = brightness == Brightness.dark ? 'dark' : 'light';
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../docs/design/screens/today/${name}_$suffix.png',
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final brightness in [Brightness.dark, Brightness.light]) {
    // ── Today screen ────────────────────────────────────────────────────────

    testWidgets('today_full $brightness', (tester) async {
      await _pump(
        tester,
        'today_full',
        const TodayScreen(),
        brightness: brightness,
        overrides: [
          // Use null so the picker starts unfolded and avoids DateTime.now()
          // timestamp in the fold summary (keeps the golden stable).
          todayMoodProvider.overrideWithValue(const AsyncData<int?>(null)),
          moodCheckInCountProvider.overrideWithValue(const AsyncData(18)),
          weekTrendProvider.overrideWithValue(AsyncData(_sampleWeek)),
          moodInsightProvider.overrideWithValue(
              const AsyncData(_sampleInsight)),
          // No prior assessments — avoids "N days ago" text changing daily.
          assessmentsProvider
              .overrideWithValue(const AsyncData<List<Assessment>>([])),
        ],
      );
    });

    // ── Assessment question ──────────────────────────────────────────────────

    testWidgets('assessment_question $brightness', (tester) async {
      await _pump(
        tester,
        'assessment_question',
        const AssessmentScreen(instrument: Instrument.phq9),
        brightness: brightness,
        overrides: [
          assessmentsProvider.overrideWithValue(const AsyncData([])),
        ],
      );
    });

    // ── Assessment result ────────────────────────────────────────────────────

    testWidgets('assessment_result $brightness', (tester) async {
      await _pump(
        tester,
        'assessment_result',
        AssessmentResultView(
          instrument: Instrument.phq9,
          result: _phq9Result,
          showQuickExit: false,
        ),
        brightness: brightness,
        overrides: [],
      );
    });

    // ── Exercises list ───────────────────────────────────────────────────────

    testWidgets('exercises_list $brightness', (tester) async {
      await _pump(
        tester,
        'exercises_list',
        const ExercisesScreen(id: 'list'),
        brightness: brightness,
      );
    });

    // ── Box breathing ────────────────────────────────────────────────────────

    testWidgets('exercises_breathing $brightness', (tester) async {
      await _pump(
        tester,
        'exercises_breathing',
        const ExercisesScreen(id: 'box'),
        brightness: brightness,
      );
    });
  }
}

