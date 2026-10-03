// Review golden test for Eve-related screens.
//
// Renders EveScreen, ConversationsScreen, LockScreen, and NeutralScreen at
// 360×760 logical px (devicePixelRatio 2) in dark and light themes.
// Run with `flutter test --update-goldens` to create/refresh the PNGs.
// The PNGs land in docs/design/screens/eve/ relative to the project root.
//
// Golden file paths are relative to the test file's location:
//   app/test/ → ../../docs/design/screens/eve/
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/app/theme/theme.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/eve/conversations_repository.dart';
import 'package:therapylink/features/eve/conversations_screen.dart';
import 'package:therapylink/features/eve/eve_controller.dart' as ctrl;
import 'package:therapylink/features/eve/eve_screen.dart';
import 'package:therapylink/features/shared/lock_screen.dart';
import 'package:therapylink/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _t0 = DateTime(2026, 10, 3, 14, 0);

/// A small realistic conversation.
final _sampleMessages = <Message>[
  Message(
    id: 'm1',
    conversationId: 'default',
    role: 'user',
    content: 'Aaj mujhe bohat tension ho rahi hai exam ki wajah se.',
    flagged: false,
    createdAt: _t0,
  ),
  Message(
    id: 'm2',
    conversationId: 'default',
    role: 'assistant',
    content: 'Exams ke waqt yeh feeling bilkul samajh mein aati hai. Kya aap mujhe bata sakte hain — is waqt sabse zyada kya pareshan kar raha hai?',
    flagged: false,
    createdAt: _t0.add(const Duration(seconds: 10)),
  ),
  Message(
    id: 'm3',
    conversationId: 'default',
    role: 'user',
    content: 'Mujhe dar hai ke main pass nahi hounga.',
    flagged: false,
    createdAt: _t0.add(const Duration(minutes: 1)),
  ),
];

/// A small list of past conversations.
final _sampleConversations = <ConversationSummary>[
  ConversationSummary(
    id: 'conv1',
    title: 'Exam ki tension',
    createdAt: DateTime(2026, 10, 3, 14),
    updatedAt: DateTime(2026, 10, 3, 14, 10),
    messageCount: 6,
  ),
  ConversationSummary(
    id: 'conv2',
    title: null, // shows date label
    createdAt: DateTime(2026, 10, 2, 9),
    updatedAt: DateTime(2026, 10, 2, 9, 30),
    messageCount: 12,
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Load Unbounded and AtkinsonHyperlegibleNext from the bundled assets so
/// golden PNGs render with the actual Jugnu typefaces.
Future<void> _loadFonts() async {
  final unbounded = FontLoader('Unbounded')
    ..addFont(rootBundle.load('assets/fonts/Unbounded/Unbounded[wght].ttf'));
  await unbounded.load();

  final atkinson = FontLoader('AtkinsonHyperlegibleNext')
    ..addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext/AtkinsonHyperlegibleNext[wght].ttf'));
  await atkinson.load();
}

/// Standard provider overrides for all Eve-screen golden tests.
List<Override> _baseOverrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
];

/// Provider overrides specific to EveScreen.
List<Override> _eveOverrides(SharedPreferences prefs) => [
  ..._baseOverrides(prefs),
  ctrl.eveMessagesProvider.overrideWith((ref) => Stream.value(_sampleMessages)),
];

/// Provider overrides specific to ConversationsScreen.
List<Override> _conversationsOverrides(SharedPreferences prefs) => [
  ..._baseOverrides(prefs),
  conversationListProvider.overrideWith((ref) => Stream.value(_sampleConversations)),
];

/// Builds the root widget: ProviderScope + MaterialApp with the Jugnu theme.
Widget _buildApp({
  required Widget screen,
  required Brightness brightness,
  required List<Override> overrides,
}) =>
    UncontrolledProviderScope(
      container: ProviderContainer(overrides: overrides),
      child: MaterialApp(
        theme: buildTheme(brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
        debugShowCheckedModeBanner: false,
      ),
    );

/// Pumps a screen at 360×760 logical px @ devicePixelRatio 2, then compares
/// the golden at [goldenPath] (relative to this file's location).
Future<void> _pumpAndCompare(
  WidgetTester tester, {
  required Widget screen,
  required Brightness brightness,
  required List<Override> overrides,
  required String goldenPath,
}) async {
  tester.view.physicalSize = const Size(720, 1520); // 360 × 760 @ DPR 2
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_buildApp(
    screen: screen,
    brightness: brightness,
    overrides: overrides,
  ));
  // Pump to settle async providers.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(goldenPath),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_loadFonts);

  for (final brightness in [Brightness.dark, Brightness.light]) {
    final theme = brightness == Brightness.dark ? 'dark' : 'light';

    group('$theme theme', () {
      late SharedPreferences prefs;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      });

      testWidgets('EveScreen — idle with conversation', (tester) async {
        await _pumpAndCompare(
          tester,
          screen: const EveScreen(),
          brightness: brightness,
          overrides: _eveOverrides(prefs),
          goldenPath: '../../docs/design/screens/eve/eve_screen_$theme.png',
        );
      });

      testWidgets('ConversationsScreen — two past conversations', (tester) async {
        await _pumpAndCompare(
          tester,
          screen: const ConversationsScreen(),
          brightness: brightness,
          overrides: _conversationsOverrides(prefs),
          goldenPath: '../../docs/design/screens/eve/conversations_screen_$theme.png',
        );
      });

      testWidgets('LockScreen — unlocked state', (tester) async {
        await _pumpAndCompare(
          tester,
          screen: const LockScreen(),
          brightness: brightness,
          overrides: _baseOverrides(prefs),
          goldenPath: '../../docs/design/screens/eve/lock_screen_$theme.png',
        );
      });

      testWidgets('NeutralScreen — quick exit landing', (tester) async {
        await _pumpAndCompare(
          tester,
          screen: const NeutralScreen(),
          brightness: brightness,
          overrides: _baseOverrides(prefs),
          goldenPath: '../../docs/design/screens/eve/neutral_screen_$theme.png',
        );
      });
    });
  }
}
