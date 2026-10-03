import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/app/theme/theme.dart' show buildTheme;
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/l10n/app_localizations.dart';

/// Pumps [child] inside a localised Jugnu-themed MaterialApp with a ProviderScope backed by mock prefs.
///
/// The Jugnu theme extension ([JugnuColors]) is included so widgets that call
/// `Theme.of(context).extension<JugnuColors>()!` work correctly in tests.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget child, {
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(sp), ...overrides]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildTheme(brightness),
        home: child,
      ),
    ),
  );
  await tester.pump();
  return container;
}
