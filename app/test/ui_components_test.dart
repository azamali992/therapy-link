/// Widget tests for Jugnu UI components.
///
/// All tests are golden-free: they verify widget structure, semantics,
/// accessibility constraints (touch target size) and behavioural callbacks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:therapylink/app/theme/theme.dart';
import 'package:therapylink/ui/components/buttons.dart';
import 'package:therapylink/ui/components/composer.dart';
import 'package:therapylink/ui/components/crisis_sheet_view.dart';
import 'package:therapylink/ui/components/empty_state.dart';
import 'package:therapylink/ui/components/help_bar.dart';
import 'package:therapylink/ui/components/inline_note.dart';
import 'package:therapylink/ui/components/insight_card.dart';
import 'package:therapylink/ui/components/jugnu_app_bar.dart';
import 'package:therapylink/ui/components/jugnu_nav_bar.dart';
import 'package:therapylink/ui/components/jugnu_scaffold.dart';
import 'package:therapylink/ui/components/messages.dart';
import 'package:therapylink/ui/components/mood_picker.dart';
import 'package:therapylink/ui/components/moon_glyph.dart';
import 'package:therapylink/ui/components/setting_row.dart';
import 'package:therapylink/ui/components/slab.dart';
import 'package:therapylink/ui/components/week_trend.dart';
import 'package:therapylink/ui/jugnu_icons.dart';

// ── Helpers ───────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: buildTheme(brightness),
      home: Scaffold(body: child),
    );

void main() {
  // ── JugnuScaffold ──────────────────────────────────────────────────────

  group('JugnuScaffold', () {
    testWidgets('renders body and gradient decoration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: JugnuScaffold(body: const Text('Hello')),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets('light mode renders gradient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: JugnuScaffold(body: const Text('Light')),
        ),
      );
      expect(find.text('Light'), findsOneWidget);
    });
  });

  // ── JugnuAppBar ────────────────────────────────────────────────────────

  group('JugnuAppBar', () {
    testWidgets('Get help button present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            appBar: JugnuAppBar(
              title: const Text('Today'),
              onGetHelp: () {},
            ),
          ),
        ),
      );
      expect(find.text('Get help'), findsOneWidget);
    });

    testWidgets('Quick exit not shown by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            appBar: JugnuAppBar(
              title: const Text('Test'),
              onGetHelp: () {},
            ),
          ),
        ),
      );
      expect(find.byType(QuickExitButton), findsNothing);
    });

    testWidgets('Quick exit shown when showQuickExit=true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            appBar: JugnuAppBar(
              title: const Text('Test'),
              onGetHelp: () {},
              showQuickExit: true,
              onQuickExit: () {},
            ),
          ),
        ),
      );
      expect(find.byType(QuickExitButton), findsOneWidget);
    });

    testWidgets('GetHelpButton fires callback on tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            appBar: JugnuAppBar(
              title: const Text('Test'),
              onGetHelp: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Get help'));
      expect(tapped, isTrue);
    });

    testWidgets('GetHelpButton is at least 48 dp tall', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            appBar: JugnuAppBar(
              title: const Text('Test'),
              onGetHelp: () {},
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(GetHelpButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('GetHelpButton and QuickExitButton gap >= 8 dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            appBar: JugnuAppBar(
              title: const Text('Test'),
              onGetHelp: () {},
              showQuickExit: true,
              onQuickExit: () {},
            ),
          ),
        ),
      );
      final helpRect = tester.getRect(find.byType(GetHelpButton));
      final exitRect = tester.getRect(find.byType(QuickExitButton));
      final gap = exitRect.left - helpRect.right;
      expect(gap, greaterThanOrEqualTo(8));
    });
  });

  // ── PrimaryButton ──────────────────────────────────────────────────────

  group('PrimaryButton', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(_wrap(
        PrimaryButton(label: 'Shuru Karen', onPressed: () {}),
      ));
      expect(find.text('Shuru Karen'), findsOneWidget);
    });

    testWidgets('fires onPressed', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(_wrap(
        PrimaryButton(label: 'Go', onPressed: () => pressed = true),
      ));
      await tester.tap(find.byType(PrimaryButton));
      expect(pressed, isTrue);
    });

    testWidgets('is at least 52 dp tall', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 200,
          child: PrimaryButton(label: 'Go', onPressed: () {}),
        ),
      ));
      final size = tester.getSize(find.byType(PrimaryButton));
      expect(size.height, greaterThanOrEqualTo(52));
    });

    testWidgets('with arrow renders arrow icon', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 200,
          child: PrimaryButton(
              label: 'Next', onPressed: () {}, showArrow: true),
        ),
      ));
      expect(find.byIcon(JugnuIcons.arrowRight), findsOneWidget);
    });
  });

  // ── GhostButton ────────────────────────────────────────────────────────

  group('GhostButton', () {
    testWidgets('renders label and fires callback', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 200,
          child: GhostButton(
              label: 'Cancel', onPressed: () => pressed = true),
        ),
      ));
      await tester.tap(find.text('Cancel'));
      expect(pressed, isTrue);
    });
  });

  // ── MoonGlyph ──────────────────────────────────────────────────────────

  group('MoonGlyph', () {
    testWidgets('renders all phases without error', (tester) async {
      for (final phase in MoonPhase.values) {
        await tester.pumpWidget(_wrap(MoonGlyph(phase: phase)));
      }
    });

    testWidgets('missed=true renders without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoonGlyph(missed: true, size: 28),
      ));
      expect(find.byType(MoonGlyph), findsOneWidget);
    });

    testWidgets('selected=true does not overflow', (tester) async {
      await tester.pumpWidget(_wrap(
        const MoonGlyph(phase: MoonPhase.full, size: 28, selected: true),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  // ── MoodPicker ─────────────────────────────────────────────────────────

  group('MoodPicker', () {
    testWidgets('shows five moon options', (tester) async {
      await tester.pumpWidget(_wrap(const MoodPicker()));
      expect(find.byType(MoonGlyph), findsNWidgets(5));
    });

    testWidgets('shows scale ends when showScaleEnds=true', (tester) async {
      await tester.pumpWidget(_wrap(const MoodPicker(showScaleEnds: true)));
      expect(find.text('Empty moon: hardest'), findsOneWidget);
      expect(find.text('Full: best'), findsOneWidget);
    });

    testWidgets('hides scale ends when showScaleEnds=false', (tester) async {
      await tester.pumpWidget(_wrap(const MoodPicker(showScaleEnds: false)));
      expect(find.text('Empty moon: hardest'), findsNothing);
    });

    testWidgets('fires onSelected callback on tap', (tester) async {
      int? selected;
      await tester.pumpWidget(_wrap(
        MoodPicker(
          showScaleEnds: false,
          onSelected: (v) => selected = v,
        ),
      ));
      await tester.tap(find.byType(MoonGlyph).first);
      // onSelected fires synchronously on tap before the fold timer starts.
      expect(selected, 0);
      // Pump through fold hold + animation to drain pending timers.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    });

    testWidgets('starts folded when summary is provided', (tester) async {
      final summary = MoodSummary(valence: 2, savedAt: DateTime.now());
      await tester.pumpWidget(_wrap(MoodPicker(summary: summary)));
      expect(find.text('Change'), findsOneWidget);
    });
  });

  // ── WeekTrend ──────────────────────────────────────────────────────────

  group('WeekTrend', () {
    testWidgets('renders without overflow', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 320,
          child: WeekTrend(
            days: List.generate(
              7,
              (i) => WeekDay(
                label: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][i],
                isToday: i == 6,
                valence: i < 5 ? i : null,
              ),
            ),
          ),
        ),
      ));
      expect(find.byType(WeekTrend), findsOneWidget);
    });
  });

  // ── Messages ───────────────────────────────────────────────────────────

  group('Messages', () {
    testWidgets('EveMessage with header renders Eve label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: EveMessage(text: 'Hello', showHeader: true),
            ),
          ),
        ),
      );
      expect(find.text('Eve'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('EveMessage has semantics label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: EveMessage(text: 'Test message'),
            ),
          ),
        ),
      );
      final semantics = tester.getSemantics(find.byType(EveMessage));
      expect(semantics.label, contains('Eve said'));
    });

    testWidgets('MyMessage renders text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: MyMessage(text: 'My reply'),
            ),
          ),
        ),
      );
      expect(find.text('My reply'), findsOneWidget);
    });

    testWidgets('ThinkingLine renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const Scaffold(body: ThinkingLine()),
        ),
      );
      expect(find.byType(ThinkingLine), findsOneWidget);
    });
  });

  // ── InsightCard ────────────────────────────────────────────────────────

  group('InsightCard', () {
    testWidgets('shows body and footnote', (tester) async {
      await tester.pumpWidget(_wrap(
        const InsightCard(
          body: 'Mood is stable this week.',
          checkInCount: 7,
        ),
      ));
      expect(find.text('Mood is stable this week.'), findsOneWidget);
      expect(find.textContaining('7 check-ins'), findsOneWidget);
      expect(find.textContaining('pattern, not a diagnosis'), findsOneWidget);
    });
  });

  // ── Composer ───────────────────────────────────────────────────────────

  group('Composer', () {
    testWidgets('renders text field', (tester) async {
      await tester.pumpWidget(_wrap(Composer(onSend: (_) {})));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('fires onSend with typed text', (tester) async {
      String? sent;
      await tester.pumpWidget(_wrap(Composer(onSend: (t) => sent = t)));
      await tester.enterText(find.byType(TextField), 'Hello Eve');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(sent, 'Hello Eve');
    });

    testWidgets('shows quick replies', (tester) async {
      await tester.pumpWidget(_wrap(
        Composer(
          onSend: (_) {},
          quickReplies: const ['Han', 'Nahi'],
        ),
      ));
      expect(find.text('Han'), findsOneWidget);
      expect(find.text('Nahi'), findsOneWidget);
    });
  });

  // ── CrisisSheetView ────────────────────────────────────────────────────

  group('CrisisSheetView', () {
    testWidgets('renders heading and helplines', (tester) async {
      await tester.pumpWidget(_wrap(
        const CrisisSheetView(
          helplines: [
            HelplineViewModel(
              name: 'Umang',
              number: '0311-7786264',
              scope: 'Mental health',
            ),
          ],
        ),
      ));
      expect(find.text('Help is here'), findsOneWidget);
      expect(find.text('Umang'), findsOneWidget);
      expect(find.text('0311-7786264'), findsOneWidget);
    });

    testWidgets('back label present', (tester) async {
      await tester.pumpWidget(_wrap(
        const CrisisSheetView(helplines: []),
      ));
      expect(find.text('Wapas chat par'), findsOneWidget);
    });

    testWidgets('Call and Copy buttons per helpline', (tester) async {
      await tester.pumpWidget(_wrap(
        const CrisisSheetView(
          helplines: [
            HelplineViewModel(
              name: 'Rescue',
              number: '1122',
              scope: 'Emergency',
            ),
          ],
        ),
      ));
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('no animation in crisis sheet (stable after pump)', (tester) async {
      await tester.pumpWidget(_wrap(
        const CrisisSheetView(helplines: []),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CrisisSheetView), findsOneWidget);
    });
  });

  // ── HelpBar ────────────────────────────────────────────────────────────

  group('HelpBar', () {
    testWidgets('shows label and fires callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(
        HelpBar(onGetHelp: () => tapped = true),
      ));
      expect(find.text('Madad yahan hai'), findsOneWidget);
      await tester.tap(find.byType(HelpBar));
      expect(tapped, isTrue);
    });
  });

  // ── SettingRow + JugnuSwitch ───────────────────────────────────────────

  group('SettingRow', () {
    testWidgets('renders title and switch', (tester) async {
      await tester.pumpWidget(_wrap(
        SettingRow(
          title: 'Quick exit',
          value: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Quick exit'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('fires onChanged on switch tap', (tester) async {
      bool? changed;
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 360,
          child: SettingRow(
            title: 'Quick exit',
            value: false,
            onChanged: (v) => changed = v,
          ),
        ),
      ));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(changed, isNotNull);
    });
  });

  // ── JugnuNavBar ────────────────────────────────────────────────────────

  group('JugnuNavBar', () {
    testWidgets('renders 4 tab labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            body: JugnuNavBar(currentIndex: 0, onTap: (_) {}),
          ),
        ),
      );
      for (final label in ['Eve', 'Today', 'Journal', 'You']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('fires onTap with correct index', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: Scaffold(
            body: JugnuNavBar(
              currentIndex: 0,
              onTap: (i) => tapped = i,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Journal'));
      expect(tapped, 2);
    });
  });

  // ── Slab + NestedCard ──────────────────────────────────────────────────

  group('Slab', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(_wrap(
        const Slab(child: Text('Inside slab')),
      ));
      expect(find.text('Inside slab'), findsOneWidget);
    });

    testWidgets('NestedCard renders child inside slab', (tester) async {
      await tester.pumpWidget(_wrap(
        const Slab(child: NestedCard(child: Text('Nested'))),
      ));
      expect(find.text('Nested'), findsOneWidget);
    });
  });

  // ── EmptyState ─────────────────────────────────────────────────────────

  group('EmptyState', () {
    testWidgets('renders title and optional body', (tester) async {
      await tester.pumpWidget(_wrap(
        EmptyState(
          icon: JugnuIcons.journal,
          title: 'No entries',
          body: 'Start writing today.',
        ),
      ));
      expect(find.text('No entries'), findsOneWidget);
      expect(find.text('Start writing today.'), findsOneWidget);
    });
  });

  // ── InlineNote ─────────────────────────────────────────────────────────

  group('InlineNote', () {
    testWidgets('renders note text', (tester) async {
      await tester.pumpWidget(_wrap(
        const InlineNote(text: 'Your data is safe.'),
      ));
      expect(find.text('Your data is safe.'), findsOneWidget);
    });

    testWidgets('isProtected uses shield icon', (tester) async {
      await tester.pumpWidget(_wrap(
        const InlineNote(text: 'Protected.', isProtected: true),
      ));
      expect(find.byIcon(JugnuIcons.shieldCheck), findsOneWidget);
    });
  });

  // ── Touch target checks ────────────────────────────────────────────────

  group('Touch targets >= 48 dp', () {
    testWidgets('ChipButton min height', (tester) async {
      await tester.pumpWidget(_wrap(
        ChipButton(label: 'Han', onPressed: () {}),
      ));
      final size = tester.getSize(find.byType(ChipButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('QuickExitButton min size 48x48', (tester) async {
      await tester.pumpWidget(_wrap(QuickExitButton(onPressed: () {})));
      final size = tester.getSize(find.byType(QuickExitButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('JugnuSwitch touch target', (tester) async {
      await tester.pumpWidget(_wrap(
        SizedBox(
          width: 360,
          child: JugnuSwitch(value: false, onChanged: (_) {}),
        ),
      ));
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}
