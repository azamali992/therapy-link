// Golden-image review test for Journal, You, and Clinician screens.
//
// Renders every screen owned by the ui-journal-you area at 360x760 dp,
// devicePixelRatio 2, in both dark and light, with realistic sample data.
// PNGs land in docs/design/screens/journal-you/ relative to the repo root.
//
// Run with:
//   flutter test test/screens_journal_you_review_test.dart --update-goldens
//
// Then read each PNG and iterate until it matches the approved designs in
// docs/design/DESIGN.md and the HTML mockups.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/app/theme/theme.dart' show buildTheme;
import 'package:therapylink/core/api/me_provider.dart';
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/core/auth/auth_providers.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/clinician/caseload_screen.dart';
import 'package:therapylink/features/clinician/patient_screen.dart';
import 'package:therapylink/features/clinician/requests_screen.dart';
import 'package:therapylink/features/journal/journal_providers.dart';
import 'package:therapylink/features/journal/journal_screen.dart';
import 'package:therapylink/features/journal/journal_editor_screen.dart';
import 'package:therapylink/features/you/access_log_screen.dart';
import 'package:therapylink/features/you/care_screen.dart';
import 'package:therapylink/features/you/clinician_join_screen.dart';
import 'package:therapylink/features/you/memory_screen.dart';
import 'package:therapylink/features/you/settings_screen.dart';
import 'package:therapylink/features/you/you_screen.dart';
import 'package:therapylink/features/eve/memory.dart';
import 'package:therapylink/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _me = Me(
  uid: 'u1',
  email: 'aisha@example.com',
  displayName: 'Aisha Raza',
  role: Role.patient,
  locale: 'en',
  clinicianVerified: false,
);

final _clinicianMe = Me(
  uid: 'c1',
  displayName: 'Dr Sana Malik',
  email: 'sana@clinic.pk',
  role: Role.clinician,
  locale: 'en',
  clinicianVerified: true,
  inviteCode: 'SANA-2026',
);

final _clinicianMePending = Me(
  uid: 'c2',
  displayName: 'Dr Ali Khan',
  email: 'ali@clinic.pk',
  role: Role.clinician,
  locale: 'en',
  clinicianVerified: false,
  inviteCode: 'ALI-2026',
);

final _journals = [
  JournalEntry(
    id: 'j1',
    title: 'A good morning',
    body:
        'Went for a walk along the canal. The fog was thick but I felt '
        'lighter than I have in weeks.',
    mood: 1,
    createdAt: DateTime(2026, 10, 2),
    updatedAt: DateTime(2026, 10, 2),
  ),
  JournalEntry(
    id: 'j2',
    title: null,
    body: 'آج صبح بہت اچھا لگا۔ پارک میں گئی اور پھولوں کو دیکھا۔',
    mood: 2,
    createdAt: DateTime(2026, 9, 30),
    updatedAt: DateTime(2026, 9, 30),
  ),
  JournalEntry(
    id: 'j3',
    title: 'Hard day',
    body:
        'Nothing felt manageable today. Tried the breathing exercise and '
        'it helped a little.',
    mood: -1,
    createdAt: DateTime(2026, 9, 28),
    updatedAt: DateTime(2026, 9, 28),
  ),
];

final _memories = [
  Memory(
    id: 'm1',
    kind: 'goal',
    content: 'Wants to feel less anxious at work',
    createdAt: DateTime(2026, 9, 1),
  ),
  Memory(
    id: 'm2',
    kind: 'helped',
    content: 'Deep breathing helps when panic starts',
    createdAt: DateTime(2026, 8, 20),
  ),
  Memory(
    id: 'm3',
    kind: 'person',
    content: 'Sister Mariam is her main support',
    createdAt: DateTime(2026, 8, 10),
  ),
];

final _accessLog = [
  AccessLogEntry(
    clinicianUid: 'c1',
    clinicianName: 'Dr Sana Malik',
    action: 'overview',
    sections: const ['assessments', 'mood_trend'],
    at: DateTime(2026, 9, 28, 14, 30),
  ),
  AccessLogEntry(
    clinicianUid: 'c1',
    clinicianName: 'Dr Sana Malik',
    action: 'caseload',
    sections: const [],
    at: DateTime(2026, 9, 25, 9, 0),
  ),
];

final _activeCareLink = CareLink(
  id: 'lnk1',
  patientUid: 'u1',
  clinicianUid: 'c1',
  status: LinkStatus.active,
  shareAssessments: true,
  shareMoodTrend: false,
  shareSummaries: false,
  shareJournal: false,
  clinicianName: 'Dr Sana Malik',
  clinicianVerified: true,
);

final _requests = [
  LinkRequest(
    linkId: 'r1',
    patient: Me(
      uid: 'p1',
      displayName: 'Fatima Zahra',
      email: 'fatima@example.com',
      role: Role.patient,
      locale: 'en',
      clinicianVerified: false,
    ),
    requestedAt: DateTime(2026, 9, 29),
  ),
];

final _caseload = [
  CaseloadRow(
    patient: Me(
      uid: 'p1',
      displayName: 'Fatima Zahra',
      email: null,
      role: Role.patient,
      locale: 'en',
      clinicianVerified: false,
    ),
    sharesAssessments: true,
    latest: [
      Assessment(
        id: 'a1',
        instrument: Instrument.phq9,
        score: 14,
        band: 'moderate',
        flags: const ['worsened'],
        takenAt: DateTime(2026, 9, 20),
      ),
    ],
    attention: const ['worsened'],
  ),
  CaseloadRow(
    patient: Me(
      uid: 'p2',
      displayName: 'Bilal Ahmed',
      email: null,
      role: Role.patient,
      locale: 'en',
      clinicianVerified: false,
    ),
    sharesAssessments: true,
    latest: [
      Assessment(
        id: 'a2',
        instrument: Instrument.phq9,
        score: 5,
        band: 'mild',
        flags: const [],
        takenAt: DateTime(2026, 9, 18),
      ),
    ],
    attention: const [],
  ),
];

final _patientOverview = PatientOverview(
  patient: Me(
    uid: 'p1',
    displayName: 'Fatima Zahra',
    email: null,
    role: Role.patient,
    locale: 'en',
    clinicianVerified: false,
  ),
  consent: CareLink(
    id: 'lnk2',
    patientUid: 'p1',
    clinicianUid: 'c1',
    status: LinkStatus.active,
    shareAssessments: true,
    shareMoodTrend: false,
    shareSummaries: false,
    shareJournal: false,
    clinicianName: 'Dr Sana Malik',
    clinicianVerified: true,
  ),
  assessments: [
    Assessment(
      id: 'a1',
      instrument: Instrument.phq9,
      score: 14,
      band: 'moderate',
      flags: const ['worsened'],
      takenAt: DateTime(2026, 9, 20),
    ),
    Assessment(
      id: 'a2',
      instrument: Instrument.phq9,
      score: 18,
      band: 'moderately_severe',
      flags: const [],
      takenAt: DateTime(2026, 9, 6),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Loads the bundled app fonts + Material Icons into the test font registry
/// so icon glyphs and custom typefaces render correctly in golden images.
Future<void> _loadFonts() async {
  // Wraps a File read as a Future<ByteData> for FontLoader.addFont.
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

  // App fonts (variable-weight TTF, loaded from the package asset directory)
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
/// MaterialApp and saves a golden PNG to docs/design/screens/journal-you/.
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
      '../../docs/design/screens/journal-you/${name}_$suffix.png',
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final brightness in [Brightness.dark, Brightness.light]) {
    // ── Journal ─────────────────────────────────────────────────────────

    testWidgets('journal_list $brightness', (tester) async {
      await _pump(
        tester,
        'journal_list',
        const JournalScreen(),
        brightness: brightness,
        overrides: [journalProvider.overrideWithValue(AsyncData(_journals))],
      );
    });

    testWidgets('journal_editor $brightness', (tester) async {
      await _pump(
        tester,
        'journal_editor',
        const JournalEditorScreen(),
        brightness: brightness,
        overrides: [journalProvider.overrideWithValue(const AsyncData([]))],
      );
    });

    // ── You ──────────────────────────────────────────────────────────────

    testWidgets('you_hub $brightness', (tester) async {
      await _pump(
        tester,
        'you_hub',
        const YouScreen(),
        brightness: brightness,
        overrides: [
          meProvider.overrideWith((_) async => _me),
          authStateProvider.overrideWith((_) => Stream.value(null)),
        ],
      );
    });

    testWidgets('settings $brightness', (tester) async {
      await _pump(
        tester,
        'settings',
        const SettingsScreen(),
        brightness: brightness,
        overrides: [devControlsProvider.overrideWithValue(false)],
      );
    });

    testWidgets('memory $brightness', (tester) async {
      await _pump(
        tester,
        'memory',
        const MemoryScreen(),
        brightness: brightness,
        overrides: [
          memoriesProvider.overrideWith((_) => Stream.value(_memories)),
        ],
      );
    });

    testWidgets('access_log $brightness', (tester) async {
      await _pump(
        tester,
        'access_log',
        const AccessLogScreen(),
        brightness: brightness,
        overrides: [accessLogProvider.overrideWithValue(AsyncData(_accessLog))],
      );
    });

    testWidgets('care_team $brightness', (tester) async {
      await _pump(
        tester,
        'care_team',
        const CareScreen(),
        brightness: brightness,
        overrides: [
          careLinksProvider.overrideWithValue(AsyncData([_activeCareLink])),
        ],
      );
    });

    testWidgets('become_clinician $brightness', (tester) async {
      await _pump(
        tester,
        'become_clinician',
        const ClinicianJoinScreen(),
        brightness: brightness,
      );
    });

    // ── Clinician ─────────────────────────────────────────────────────────

    testWidgets('clinician_caseload $brightness', (tester) async {
      await _pump(
        tester,
        'clinician_caseload',
        const CaseloadScreen(),
        brightness: brightness,
        overrides: [
          meProvider.overrideWith((_) async => _clinicianMe),
          caseloadProvider.overrideWithValue(AsyncData(_caseload)),
        ],
      );
    });

    testWidgets('clinician_caseload_pending $brightness', (tester) async {
      await _pump(
        tester,
        'clinician_caseload_pending',
        const CaseloadScreen(),
        brightness: brightness,
        overrides: [
          meProvider.overrideWith((_) async => _clinicianMePending),
          caseloadProvider.overrideWithValue(const AsyncData([])),
        ],
      );
    });

    testWidgets('clinician_requests $brightness', (tester) async {
      await _pump(
        tester,
        'clinician_requests',
        const RequestsScreen(),
        brightness: brightness,
        overrides: [
          clinicianRequestsProvider.overrideWithValue(AsyncData(_requests)),
        ],
      );
    });

    testWidgets('clinician_patient $brightness', (tester) async {
      await _pump(
        tester,
        'clinician_patient',
        const PatientScreen(uid: 'p1'),
        brightness: brightness,
        overrides: [
          patientOverviewProvider('p1')
              .overrideWith((_) async => _patientOverview),
        ],
      );
    });
  }
}
