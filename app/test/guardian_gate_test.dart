// The release gate on Eve's chat, and the safety-model status people see while it downloads.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/app/theme/theme.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/core/ml/onnx_guardian.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/eve/eve_controller.dart' as ctrl;
import 'package:therapylink/features/eve/eve_screen.dart';
import 'package:therapylink/features/shared/guardian_status.dart';
import 'package:therapylink/l10n/app_localizations.dart';
import 'package:therapylink/ui/components/composer.dart';

class _Manager extends GuardianModelManager {
  _Manager(this._status);

  final GuardianStatus _status;
  final downloads = <bool>[];

  @override
  GuardianStatus build() => _status;

  @override
  bool get available => true;

  @override
  Future<void> download({bool allowMetered = false}) async => downloads.add(allowMetered);
}

Future<_Manager> _pump(WidgetTester tester, Widget home, GuardianStatus status, {required bool release}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final manager = _Manager(status);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      devControlsProvider.overrideWithValue(!release),
      guardianModelManagerProvider.overrideWith(() => manager),
      guardianProvider.overrideWithValue(HeuristicGuardian()),
      ctrl.eveMessagesProvider.overrideWith((ref) => Stream.value(const <Message>[])),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pump();
  return manager;
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group("Eve's chat in a release build waits for the trained safety check", () {
    testWidgets('not installed: the composer gives way to the notice and the download status', (tester) async {
      await _pump(tester, const EveScreen(), const GuardianDownloading(40), release: true);

      expect(find.text(en.eveSafetyNotReadyTitle), findsOneWidget);
      expect(find.text(en.guardianDownloading(40)), findsOneWidget);
      expect(find.byType(Composer), findsNothing);
    });

    testWidgets('a failed model pauses chat too', (tester) async {
      await _pump(tester, const EveScreen(), const GuardianFailed('canary failed'), release: true);
      expect(find.text(en.eveSafetyNotReadyTitle), findsOneWidget);
      expect(find.byType(Composer), findsNothing);
    });

    testWidgets('ready: the composer is back', (tester) async {
      await _pump(tester, const EveScreen(), const GuardianReady(), release: true);
      expect(find.text(en.eveSafetyNotReadyTitle), findsNothing);
      expect(find.byType(Composer), findsOneWidget);
    });

    testWidgets('a debug build keeps chat open on the keyword check', (tester) async {
      await _pump(tester, const EveScreen(), const GuardianHeuristic(), release: false);
      expect(find.byType(Composer), findsOneWidget);
    });
  });

  group('the status panel', () {
    Widget panel() => const Scaffold(body: GuardianStatusPanel());

    testWidgets('on mobile data it says the size and offers mobile data', (tester) async {
      final m = await _pump(tester, panel(), const GuardianWaitingForWifi(287093575), release: true);

      expect(find.text(en.guardianWaitingForWifi(288)), findsOneWidget);
      await tester.tap(find.text(en.guardianDownloadOnData));
      expect(m.downloads, [true]);
    });

    testWidgets('no space says how much to free and offers to try again', (tester) async {
      final m = await _pump(tester, panel(), const GuardianNoSpace(350000000), release: true);

      expect(find.text(en.guardianNoSpace(350)), findsOneWidget);
      await tester.tap(find.text(en.guardianDownload));
      expect(m.downloads, [false]);
    });

    testWidgets('downloading shows progress and that the keyword check runs meanwhile', (tester) async {
      await _pump(tester, panel(), const GuardianDownloading(12), release: true);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(en.guardianMeanwhile), findsOneWidget);
    });
  });
}
