/// Golden-file review tests for the onboarding area.
///
/// Renders each screen at 360×760 logical px (devicePixelRatio 2) in dark and
/// light themes and saves PNGs for visual review.
///
/// Run with `--update-goldens` once to generate / regenerate the baseline:
///   flutter test test/screens_onboarding_review_test.dart --update-goldens
///
/// The PNGs land in docs/design/screens/onboarding/ (two levels above app/).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:therapylink/app/theme/theme.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/auth/sign_in_screen.dart';
import 'package:therapylink/features/onboarding/consent_screen.dart';
import 'package:therapylink/features/onboarding/welcome_screen.dart';
import 'package:therapylink/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Load all Jugnu bundled fonts so text renders correctly in goldens.
Future<void> _loadFonts() async {
  final fontSpecs = <String, List<String>>{
    'Unbounded': ['assets/fonts/Unbounded/Unbounded[wght].ttf'],
    'AtkinsonHyperlegibleNext': [
      'assets/fonts/AtkinsonHyperlegibleNext/AtkinsonHyperlegibleNext[wght].ttf',
    ],
    'AtkinsonHyperlegibleMono': [
      'assets/fonts/AtkinsonHyperlegibleMono/AtkinsonHyperlegibleMono[wght].ttf',
    ],
    'NotoNastaliqUrdu': [
      'assets/fonts/NotoNastaliqUrdu/NotoNastaliqUrdu[wght].ttf',
    ],
  };

  for (final entry in fontSpecs.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(
        File(path).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  }
}

/// Wraps [child] in the full test harness: ProviderScope with fake prefs,
/// MaterialApp with the given [brightness], fixed 360×760 viewport.
Widget _harness(
  Widget child, {
  Brightness brightness = Brightness.dark,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWith(
        (ref) => throw UnimplementedError('not used in preview'),
      ),
    ],
    child: MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 760),
        devicePixelRatio: 2,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}

/// Renders [widget] at 360×760 dp @ 2x and saves a golden PNG.
Future<void> _golden(
  WidgetTester tester,
  Widget widget,
  String name, {
  Brightness brightness = Brightness.dark,
}) async {
  await tester.pumpWidget(_harness(widget, brightness: brightness));

  // Pump a few frames: EveHero tries to init a video which fails in tests;
  // the image.asset fallback is shown after the first postFrameCallback.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../docs/design/screens/onboarding/$name.png',
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  group('Onboarding screen goldens', () {
    testWidgets('welcome dark', (tester) async {
      tester.view.physicalSize = const Size(720, 1520); // 360×760 @ 2x
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _golden(
        tester,
        const WelcomeScreen(),
        'welcome_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('welcome light (still Eve night)', (tester) async {
      tester.view.physicalSize = const Size(720, 1520);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Welcome screen forces dark regardless of brightness arg; this test
      // confirms that forcing is in place even when the host theme is light.
      await _golden(
        tester,
        const WelcomeScreen(),
        'welcome_light',
        brightness: Brightness.light,
      );
    });

    testWidgets('consent dark', (tester) async {
      tester.view.physicalSize = const Size(720, 1520);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _golden(
        tester,
        const ConsentScreen(),
        'consent_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('consent light', (tester) async {
      tester.view.physicalSize = const Size(720, 1520);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _golden(
        tester,
        const ConsentScreen(),
        'consent_light',
        brightness: Brightness.light,
      );
    });

    testWidgets('sign_in dark', (tester) async {
      tester.view.physicalSize = const Size(720, 1520);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _golden(
        tester,
        const SignInScreen(),
        'sign_in_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('sign_in light', (tester) async {
      tester.view.physicalSize = const Size(720, 1520);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _golden(
        tester,
        const SignInScreen(),
        'sign_in_light',
        brightness: Brightness.light,
      );
    });
  });
}
