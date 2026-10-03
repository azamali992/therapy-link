import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/l10n/app_localizations.dart';

/// Pumps [child] inside a localised MaterialApp and a ProviderScope backed by mock prefs.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget child, {
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
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
        home: child,
      ),
    ),
  );
  await tester.pump();
  return container;
}
