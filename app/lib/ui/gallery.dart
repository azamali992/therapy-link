import 'package:flutter/material.dart';

import '../app/theme/theme.dart';
import '../app/theme/tokens.dart';
import 'components/buttons.dart';
import 'components/composer.dart';
import 'components/crisis_sheet_view.dart';
import 'components/empty_state.dart';
import 'components/help_bar.dart';
import 'components/inline_note.dart';
import 'components/insight_card.dart';
import 'components/jugnu_app_bar.dart';
import 'components/jugnu_nav_bar.dart';
import 'components/jugnu_scaffold.dart';
import 'components/messages.dart';
import 'components/mood_picker.dart';
import 'components/moon_glyph.dart';
import 'components/setting_row.dart';
import 'components/slab.dart';
import 'components/week_trend.dart';
import 'jugnu_icons.dart';

/// Debug gallery that shows every Jugnu component in dark and light modes.
/// Accessible at the `/gallery` route (registered in router.dart by the
/// platform engineer; this widget is production-safe but flagged for
/// debug builds via kDebugMode if desired).
class UiGallery extends StatefulWidget {
  const UiGallery({super.key});

  @override
  State<UiGallery> createState() => _UiGalleryState();
}

class _UiGalleryState extends State<UiGallery> {
  bool _darkMode = true;
  int _navIndex = 0;
  bool _switchOn = true;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(_darkMode ? Brightness.dark : Brightness.light),
      child: _GalleryBody(
        darkMode: _darkMode,
        onToggleDark: (v) => setState(() => _darkMode = v),
        navIndex: _navIndex,
        onNavTap: (i) => setState(() => _navIndex = i),
        switchOn: _switchOn,
        onSwitchChanged: (v) => setState(() => _switchOn = v),
      ),
    );
  }
}

class _GalleryBody extends StatelessWidget {
  const _GalleryBody({
    required this.darkMode,
    required this.onToggleDark,
    required this.navIndex,
    required this.onNavTap,
    required this.switchOn,
    required this.onSwitchChanged,
  });

  final bool darkMode;
  final ValueChanged<bool> onToggleDark;
  final int navIndex;
  final ValueChanged<int> onNavTap;
  final bool switchOn;
  final ValueChanged<bool> onSwitchChanged;

  @override
  Widget build(BuildContext context) {
    return JugnuScaffold(
      appBar: JugnuAppBar(
        title: const Text('Jugnu Gallery'),
        onGetHelp: () {},
        showQuickExit: true,
        onQuickExit: () {},
      ),
      bottomNavigationBar: JugnuNavBar(
        currentIndex: navIndex,
        onTap: onNavTap,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: Jugnu.screenGutter, vertical: Jugnu.s16),
        children: [
          // ── Mode toggle ─────────────────────────────────────────────
          _Section(
            title: 'Mode',
            child: Row(
              children: [
                const Text('Dark'),
                const SizedBox(width: Jugnu.s8),
                Switch(value: darkMode, onChanged: onToggleDark),
              ],
            ),
          ),

          // ── Type scale ──────────────────────────────────────────────
          _Section(
            title: 'Type scale',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('displaySmall 28 Unbounded 300',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: Jugnu.s8),
                Text('titleLarge 20 Unbounded 400',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: Jugnu.s8),
                Text('headlineSmall 22 Atkinson 700',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: Jugnu.s8),
                Text('titleMedium 16 Atkinson 700',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: Jugnu.s8),
                Text('bodyLarge 16 Atkinson 400',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: Jugnu.s8),
                Text('bodyMedium 14 Atkinson 400',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: Jugnu.s8),
                Text('labelLarge 16 Atkinson 700',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: Jugnu.s8),
                Text('labelMedium 14 Atkinson 600',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: Jugnu.s8),
                Text('labelSmall 13 Mono 500',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: Jugnu.s8),
                Text('26 Mono 600 — 0311-7786264',
                    style: jugnuNumberLarge(
                        Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: Jugnu.s8),
                Text('urduBody — یہ چیٹ صرف اس فون پر',
                    style: jugnuUrduBody(
                        Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ),

          // ── Buttons ─────────────────────────────────────────────────
          _Section(
            title: 'Buttons',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                    label: 'Shuru Karen', onPressed: () {}),
                const SizedBox(height: Jugnu.s8),
                PrimaryButton(
                    label: 'Aage', onPressed: () {}, showArrow: true),
                const SizedBox(height: Jugnu.s8),
                GhostButton(label: 'Baad mein', onPressed: () {}),
                const SizedBox(height: Jugnu.s8),
                Row(children: [
                  ChipButton(label: 'Han', onPressed: () {}),
                  const SizedBox(width: Jugnu.s8),
                  ChipButton(
                      label: 'Nahi', onPressed: () {}, selected: true),
                  const SizedBox(width: Jugnu.s8),
                  ChipButton(label: 'Shayad', onPressed: () {}),
                ]),
                const SizedBox(height: Jugnu.s8),
                Row(children: [
                  GetHelpButton(onPressed: () {}),
                  const SizedBox(width: 10),
                  QuickExitButton(onPressed: () {}),
                ]),
              ],
            ),
          ),

          // ── Moons ───────────────────────────────────────────────────
          _Section(
            title: 'Moon glyphs',
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: MoonPhase.values
                      .map((p) => MoonGlyph(phase: p, size: 28))
                      .toList(),
                ),
                const SizedBox(height: Jugnu.s8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MoonGlyph(phase: MoonPhase.full, size: 28, selected: true),
                    MoonGlyph(missed: true, size: 28),
                  ],
                ),
              ],
            ),
          ),

          // ── Mood picker ─────────────────────────────────────────────
          _Section(
            title: 'Mood picker',
            child: MoodPicker(
              showScaleEnds: true,
              onSelected: (_) {},
            ),
          ),

          // ── Week trend ──────────────────────────────────────────────
          _Section(
            title: 'Week trend',
            child: WeekTrend(
              days: const [
                WeekDay(label: 'Mon', isToday: false, valence: 2),
                WeekDay(label: 'Tue', isToday: false, valence: 3),
                WeekDay(label: 'Wed', isToday: false),
                WeekDay(label: 'Thu', isToday: false, valence: 1),
                WeekDay(label: 'Fri', isToday: false, valence: 4),
                WeekDay(label: 'Sat', isToday: false, valence: 3),
                WeekDay(label: 'Sun', isToday: true),
              ],
            ),
          ),

          // ── Insight card ────────────────────────────────────────────
          _Section(
            title: 'Insight card',
            child: InsightCard(
              body:
                  'Your mood is often higher in the mornings this week.',
              checkInCount: 14,
            ),
          ),

          // ── Messages ────────────────────────────────────────────────
          _Section(
            title: 'Messages',
            child: Column(
              children: [
                EveMessage(
                  text:
                      'Aaj kaisa feel kar rahe ho? Main sun rahi hoon.',
                  showHeader: true,
                ),
                const SizedBox(height: Jugnu.s12),
                const MyMessage(text: 'Theek nahi hun aaj.'),
                const SizedBox(height: Jugnu.s12),
                const ThinkingLine(),
              ],
            ),
          ),

          // ── Composer ────────────────────────────────────────────────
          _Section(
            title: 'Composer',
            child: Composer(
              onSend: (_) {},
              quickReplies: const ['Han', 'Nahi', 'Shayad'],
            ),
          ),

          // ── Inline note ─────────────────────────────────────────────
          _Section(
            title: 'Inline note',
            child: Column(
              children: [
                const InlineNote(
                  text:
                      'Yeh chat sirf is phone par save hai. Eve ke jawab hamare server se aate hain.',
                ),
                const SizedBox(height: Jugnu.s8),
                const InlineNote(
                  text: 'Yeh data sirf is phone par saved hai.',
                  isProtected: true,
                ),
              ],
            ),
          ),

          // ── Slab + nested card ───────────────────────────────────────
          _Section(
            title: 'Slab + nested card',
            child: Slab(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Slab title',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Jugnu.s8),
                  const NestedCard(
                    child: Text('Nested card content'),
                  ),
                ],
              ),
            ),
          ),

          // ── Help bar ─────────────────────────────────────────────────
          _Section(
            title: 'Help bar',
            child: HelpBar(onGetHelp: () {}),
          ),

          // ── Crisis sheet ─────────────────────────────────────────────
          _Section(
            title: 'Crisis sheet (preview)',
            child: CrisisSheetView(
              helplines: const [
                HelplineViewModel(
                  name: 'Umang',
                  number: '0311-7786264',
                  scope: 'Mental health support',
                ),
                HelplineViewModel(
                  name: 'Rescue',
                  number: '1122',
                  scope: 'Emergency services',
                ),
              ],
            ),
          ),

          // ── Settings ─────────────────────────────────────────────────
          _Section(
            title: 'Settings',
            child: Column(
              children: [
                SettingRow(
                  title: 'Quick exit',
                  subtitle: 'Show a fast-close button on every screen',
                  value: switchOn,
                  onChanged: onSwitchChanged,
                  icon: JugnuIcons.eyeSlash,
                ),
                const SizedBox(height: Jugnu.s8),
                const Slab(child: StorageRow()),
              ],
            ),
          ),

          // ── Empty state ───────────────────────────────────────────────
          _Section(
            title: 'Empty state',
            child: EmptyState(
              icon: JugnuIcons.journal,
              title: 'Koi entries nahi',
              body: 'Apni pehli entry likhne ke liye tap karen.',
              action: PrimaryButton(
                  label: 'Likhna shuru karen', onPressed: () {}),
            ),
          ),

          const SizedBox(height: Jugnu.s48),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<JugnuColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.ink2,
                  letterSpacing: 0.08,
                )),
        const SizedBox(height: Jugnu.s8),
        child,
        const SizedBox(height: Jugnu.s32),
        Divider(color: colors.hair),
        const SizedBox(height: Jugnu.s24),
      ],
    );
  }
}
