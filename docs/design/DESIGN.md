# TherapyLink v3 design system: Jugnu (جگنو)

**Design Read:** mobile mental-health companion (product UI, Flutter) for Pakistani adults 18 to 35 who open it at low moments, mostly at night on mid-range Android, with a nocturnal, light-as-meaning language built on the legacy palette, leaning toward native Flutter ThemeData + Filament/model-viewer 3D + Phosphor icons.

**Dials:** DESIGN_VARIANCE 7 (presentation page) / 4 (in-app) · MOTION_INTENSITY 5 · VISUAL_DENSITY 4

The concept page with all seven screens is `index.html` in this folder. This file is the spec engineering builds from.

## 1. Thesis

A firefly in a dark room. The app stays as dark as 2 a.m. and spends light only where it means something.

- The ground is the legacy night `#1D1E2C` to aubergine `#34063F` ramp. Nothing on it glows.
- **Eve is the one living light.** Her Blender bud (a closed flower of light) is the only thing that emits light or haze.
- **Help is the one bright page.** The crisis sheet is paper `#F5F0FB` with legacy navy `#001F54`. In a dark app it cannot be missed, and it never needs red.
- Each legacy colour gets exactly one job (section 2) and keeps it on every screen.

Why it is ours: Wysa has a penguin, Headspace has orange daytime blobs, Calm has lake photos, Finch has a pet and streaks, Woebot has a robot and white bubbles. None of them is dark-native, none uses a faceless 3D presence, none shows mood as moon phases. Against the rejected round: no cream ground, no serif display, no amber or terracotta, no tidy card stacks. Eve's replies sit unboxed on the ground.

## 2. Colour

### Roles (locked, do not mix)

| Role | Dark | Light | Used for | Never used for |
|---|---|---|---|---|
| ground | `#1D1E2C` to `#34063F`, 180deg | `#F7F4FB` to `#EFE6F5` | full-screen background | cards on top of cards |
| surface | white 6% over ground | `#FFFFFF` | slabs, composer, inline notes | |
| raised | white 10% over ground | `#FFFFFF` | user bubble, selected option, tab marker | |
| hairline | white 12% / 22% (strong) | plum `#34063F` 12% / 24% | dividers, outlines | |
| ink | `#F4EFF9` | `#001F54` | text | |
| ink-2 | `#C9BEDA` | `#4B4A6B` | secondary text | placeholder below 4.5:1 |
| ink-3 | `#A497B8` | `#5A5878` | placeholders, inactive tabs, moon ring | text on `raised` in dark (4.49:1) |
| action | `#F23598`, text on it `#16061C` | `#B80F66`, text `#FFFFFF` | one primary button per screen | decoration, mood |
| action-text | `#FF6EB4` | `#B80F66` | active tab, links, selection ring | body text |
| eve | `#B48BFF` text; 3D `#8A4FFF` `#6E29FF` `#A36FFF` | `#6E29FF` | Eve's name, status line, thinking row, her 3D | any button or control |
| safe | `#89F336`, on it `#14200A` | `#38A711` track, text `#2B7A0E` | switch on, "only on this phone", lock active | mood, success confetti, progress |
| help | paper `#F5F0FB` + navy `#001F54` | inverted: navy `#001F54` + paper | crisis sheet, crisis card, Get help outline, Call buttons | anything that is not help |
| scrim | `#0C0914` 74% | plum 45% | behind sheets | |

Red is never used. Green never means "good mood". Errors use ink + `ph-warning-circle` + a plain sentence, never the help colours.

### Contrast (WCAG 2.2, measured on both ends of each ground ramp and on surfaces)

| Pair | Ratio | Pass |
|---|---|---|
| ink on ground (dark) | 14.6 to 14.9 | AAA |
| ink on raised (dark) | 10.8 | AAA |
| ink-2 on ground / raised | 9.3 / 6.9 | AAA / AA |
| ink-3 on surface | 5.1 | AA (not on raised) |
| `#16061C` on action `#F23598` | 5.3 | AA |
| action-text `#FF6EB4` on ground / raised | 6.4 / 4.75 | AA |
| eve `#B48BFF` on ground / raised | 6.3 / 4.7 | AA |
| safe `#89F336` on ground | 11.7 | AAA |
| navy on paper (help) | 14.2 | AAA |
| light: navy ink on ground | 13.1 to 14.6 | AAA |
| light: white on action `#B80F66` | 6.4 | AA |
| light: eve `#6E29FF` on ground | 5.0 to 5.6 | AA |
| light: safe text `#2B7A0E` on white | 5.4 | AA |
| light: `#38A711` switch track on white | 3.1 | non-text 3:1 |

`#8A4FFF` with white text is 4.52:1, too close to the line, so violet never carries button text. Raw legacy pink `#F23598` as text on the ground is 4.50:1, so text uses `#FF6EB4`.

### Light mode

Light is the daytime adaptation, not a second brand. Ground turns lilac white (tinted toward plum, hue about 300, so it can never read as cream). Ink becomes the legacy navy. Help inverts to a navy sheet so it is still the opposite of everything else. Eve and the breath flower always sit in their own night: a radial "eve well" (`#34063F` centre to `#1D1E2C`) behind them, because the renders are lit for a dark ground. Small Eve marks (header, message label) sit on a `#1E1F2D` disc for the same reason.

Moons in light mode fill with navy instead of off-white. The rule stays "more fill = better mood", always with the label.

### Alternative accent (the only one)

Lime as the action colour: `#89F336` with `#14200A` text (11.7:1), `#2B7A0E` in light. It is louder and closer to the legacy app, but a lime Continue reads as go/good and that leaks into mood. If chosen, the safe role falls back to ink. Pink stays the recommendation.

### Flutter tokens

```dart
// lib/app/theme/tokens.dart
import 'package:flutter/material.dart';

abstract final class Jugnu {
  // legacy palette, roles locked
  static const night = Color(0xFF1D1E2C);
  static const plum = Color(0xFF34063F);
  static const navy = Color(0xFF001F54);
  static const paper = Color(0xFFF5F0FB);

  // dark
  static const ink = Color(0xFFF4EFF9);
  static const ink2 = Color(0xFFC9BEDA);
  static const ink3 = Color(0xFFA497B8);
  static const action = Color(0xFFF23598);
  static const onAction = Color(0xFF16061C);
  static const actionText = Color(0xFFFF6EB4);
  static const eve = Color(0xFFB48BFF);
  static const eveMid = Color(0xFF8A4FFF);
  static const eveDeep = Color(0xFF6E29FF);
  static const eveHaze = Color(0xFFA36FFF);
  static const safe = Color(0xFF89F336);
  static const onSafe = Color(0xFF14200A);
  static const surface = Color(0x0FFFFFFF); // white 6%
  static const raised = Color(0x1AFFFFFF); // white 10%
  static const hair = Color(0x1FFFFFFF); // white 12%
  static const hairStrong = Color(0x38FFFFFF); // white 22%

  // light
  static const groundLightTop = Color(0xFFF7F4FB);
  static const groundLightBottom = Color(0xFFEFE6F5);
  static const ink2Light = Color(0xFF4B4A6B);
  static const ink3Light = Color(0xFF5A5878);
  static const actionLight = Color(0xFFB80F66);
  static const eveLight = Color(0xFF6E29FF);
  static const safeLight = Color(0xFF38A711);
  static const safeTextLight = Color(0xFF2B7A0E);

  static const groundDark = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [night, plum],
  );
  static const groundLight = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [groundLightTop, groundLightBottom],
  );
}

@immutable
class JugnuColors extends ThemeExtension<JugnuColors> {
  const JugnuColors({
    required this.ground, required this.surface, required this.raised,
    required this.hair, required this.ink2, required this.ink3,
    required this.actionText, required this.eve, required this.safe,
    required this.onSafe, required this.safeText, required this.helpBg,
    required this.helpInk, required this.eveWell,
  });
  final Gradient ground;
  final Color surface, raised, hair, ink2, ink3, actionText, eve;
  final Color safe, onSafe, safeText, helpBg, helpInk;
  final Gradient? eveWell; // null in dark

  static const dark = JugnuColors(
    ground: Jugnu.groundDark, surface: Jugnu.surface, raised: Jugnu.raised,
    hair: Jugnu.hair, ink2: Jugnu.ink2, ink3: Jugnu.ink3,
    actionText: Jugnu.actionText, eve: Jugnu.eve, safe: Jugnu.safe,
    onSafe: Jugnu.onSafe, safeText: Jugnu.safe,
    helpBg: Jugnu.paper, helpInk: Jugnu.navy, eveWell: null,
  );
  static const light = JugnuColors(
    ground: Jugnu.groundLight, surface: Colors.white, raised: Colors.white,
    hair: Color(0x1F34063F), ink2: Jugnu.ink2Light, ink3: Jugnu.ink3Light,
    actionText: Jugnu.actionLight, eve: Jugnu.eveLight, safe: Jugnu.safeLight,
    onSafe: Colors.white, safeText: Jugnu.safeTextLight,
    helpBg: Jugnu.navy, helpInk: Jugnu.paper,
    eveWell: RadialGradient(colors: [Jugnu.plum, Jugnu.night, Color(0x001D1E2C)], stops: [0.46, 0.70, 0.71]),
  );

  @override
  JugnuColors copyWith() => this;
  @override
  JugnuColors lerp(ThemeExtension<JugnuColors>? other, double t) =>
      t < 0.5 ? this : (other as JugnuColors);
}

ColorScheme jugnuScheme(Brightness b) => b == Brightness.dark
    ? const ColorScheme.dark(
        primary: Jugnu.action, onPrimary: Jugnu.onAction,
        secondary: Jugnu.eve, onSecondary: Jugnu.night,
        tertiary: Jugnu.safe, onTertiary: Jugnu.onSafe,
        surface: Jugnu.night, onSurface: Jugnu.ink,
        onSurfaceVariant: Jugnu.ink2, outline: Jugnu.hairStrong,
        outlineVariant: Jugnu.hair,
        error: Jugnu.ink, onError: Jugnu.night, // errors: icon + text, not colour
      )
    : const ColorScheme.light(
        primary: Jugnu.actionLight, onPrimary: Colors.white,
        secondary: Jugnu.eveLight, onSecondary: Colors.white,
        tertiary: Jugnu.safeLight, onTertiary: Colors.white,
        surface: Jugnu.groundLightTop, onSurface: Jugnu.navy,
        onSurfaceVariant: Jugnu.ink2Light, outline: Color(0x3D34063F),
        outlineVariant: Color(0x1F34063F),
        error: Jugnu.navy, onError: Colors.white,
      );
```

### Named roles (use these in widgets, never raw colours)

Widgets read roles, not palette names, so a role can't drift onto the wrong element. Add them to `JugnuColors`:

| Role token | Dark | Light | Only for |
|---|---|---|---|
| `evePresence` | `Jugnu.eve` | `Jugnu.eveLight` | Eve's name, status line, thinking row, halo tint |
| `primaryAction` | `Jugnu.action` / `Jugnu.onAction` | `Jugnu.actionLight` / white | the one primary button per screen |
| `primaryActionText` | `Jugnu.actionText` | `Jugnu.actionLight` | active tab, links, selection ring |
| `protectedState` | `Jugnu.safe` / `Jugnu.onSafe` | `Jugnu.safeLight` / `Jugnu.safeTextLight` | switch on, "only on this phone", lock active |
| `helpSurface` / `onHelpSurface` | `Jugnu.paper` / `Jugnu.navy` | `Jugnu.navy` / `Jugnu.paper` | crisis sheet, crisis card, session bar, Get help outline, Call |

```dart
// in JugnuColors
Color get evePresence => eve;
Color get primaryActionText => actionText;
Color get protectedState => safe;
Color get onProtectedState => onSafe;
Color get helpSurface => helpBg;
Color get onHelpSurface => helpInk;
// primaryAction / onPrimaryAction come from ColorScheme.primary / onPrimary
```

A lint rule (custom_lint or a grep in CI) fails the build if a feature file uses `Jugnu.*` directly instead of a role.

Paint the ground with a `DecoratedBox` under the `Scaffold` (`backgroundColor: Colors.transparent`), because `ColorScheme.surface` cannot hold a gradient.

## 3. Type

Google Fonts only, all bundled as assets (no runtime fetch; the user may be offline).

| Family | Role | Rule |
|---|---|---|
| Unbounded 300/400 | display: screen titles, Eve's name, the breath phase, onboarding headline | max 3 uses per screen; never in buttons, forms, settings rows or anything crisis |
| Atkinson Hyperlegible Next 400 to 700 | all UI and reading text | default for everything |
| Atkinson Hyperlegible Mono 500/600 | helpline numbers, times, breath count, dates in lists | numbers you might have to dial or read under stress |
| Noto Nastaliq Urdu 400 to 700 | Urdu script only | RTL, line height 2.0 to 2.1 |

Not a serif/sans "editorial" pairing, and none of Inter, Space Grotesk, Manrope, Fraunces, Instrument Serif. The contrast is wide-and-round display against a typeface designed for low vision, which fits users with reduced attention at night and survives 1.6x text scale.

Roman Urdu is LTR and set in Atkinson. Only text in Urdu script switches to Nastaliq and `TextDirection.rtl`. Do not infer direction from the `ur` locale code; Roman Urdu uses its own locale flag.

### Scale (logical px, line height)

| Token | Size / LH | Family, weight, tracking |
|---|---|---|
| displaySmall | 28 / 34 | Unbounded 300, -0.02em |
| titleLarge | 20 / 26 | Unbounded 400, -0.01em |
| headlineSmall (sheets, crisis) | 22 / 28 | Atkinson 700 |
| titleMedium (card titles) | 16 / 22 | Atkinson 700 |
| bodyLarge | 16 / 24 | Atkinson 400 |
| chat, Roman Urdu body | 16 / 24 | Atkinson 400 |
| bodyMedium (notes, scope lines, helper text) | 14 / 20 | Atkinson 400 |
| labelLarge (buttons) | 16 / 16 | Atkinson 700 |
| labelMedium (chips, tabs, mood labels) | 14 / 18 | Atkinson 600 |
| timestamp (times and dates only) | 13 / 18 | Atkinson Mono 500 |
| numberLarge | 26 / 30 | Atkinson Mono 600, selectable |
| urduBody | 18 / 36 | Noto Nastaliq Urdu 400 |

Floor: nothing a person needs to read is below 14 sp. Roman Urdu body copy (chat, sheet text, journal) is 16 sp. Only timestamps may use 13 sp. The audience includes low-literacy and low-vision users on cheap screens, at night.

## 4. Shape

Three shapes, each with one meaning.

| Shape | Radius | Meaning |
|---|---|---|
| Circle | 50% | alive: Eve, moons, the breath stage, icon buttons |
| Pill | full (`StadiumBorder`) | pressable: buttons, chips, switches, tab marker, segmented controls |
| Slab | 24 | holds content: cards, sheets (top corners) |
| Nested | 18 | anything inside a slab with 6 px padding (24 minus 6) |

Chat bubbles are slabs with one 8 px speech corner (user bubble bottom-right). Eve's messages have no bubble. Phone shells on the concept page are 52/44 (double bezel); that is presentation only.

Spacing: 4 px base. Screen gutter 20. Slab padding 18. Gaps 8 / 12 / 16 / 24. Touch targets 48 dp minimum for every control, including Get help, quick exit, Call, Copy, close, chips, the language switch and text links such as "Change" and "Wapas chat par". Primary buttons 52 dp. Adjacent targets keep at least 8 dp between them (Get help and quick exit use 10).

## 5. Components

**Get help (app bar).** Pill, 48 dp tall (visual and hit area), 1.5 px outline in `helpSurface`, heart icon + "Get help" / "Madad", 14 to 15 sp 700. Same spot on every screen including Welcome, sign-in, consent, lock screen and exercises. Never animated, never disabled, no badge. Opens the crisis sheet.

**Quick exit.** 48 dp circle, `ph-eye-slash`, label "Quick exit" for TalkBack. Right of Get help with a 10 dp gap, on every patient screen when the setting is on, so a shaking hand can't hit the wrong one.

**Crisis sheet.** Modal bottom sheet, `helpBg` fill, 24 top radius, drag handle. Heading in Atkinson 700 22 with a filled heart. One line of body. Body text 16 sp. Per helpline: name (700 15), number in Mono 600 24 to 26 as selectable text, one-line scope at 14 sp, then Call (filled `onHelpSurface`, 48 dp) and Copy (outlined, 48 dp), 8 dp apart. Dismiss ("Wapas chat par") is a 48 dp text button. No 3D, no motion inside the sheet, no Unbounded. Category-aware lists (suicide, abuse, child, sexual violence) stay as in v2.

**Crisis card (in transcript) and session bar.** Same help colours. Card repeats the numbers; the slim "Madad yahan hai" bar sits above the composer for the session and cannot be dismissed.

**Eve header.** 52 dp Eve presence (section 7), name in Unbounded 18, status line in `evePresence` 14: "yahan hai", "sun rahi hai" while the user types, "soch rahi hai…" before a reply.

**Eve message.** No bubble. 20 dp Eve mark (a crop of the poster) + "Eve" label in `evePresence` 14 on the first message of a group, then plain ink text at 16 sp, max 92% width, 3 to 5 lines. Semantics label "Eve said: …".

**User message.** `raised` slab, 24 radius with 8 px bottom-right corner, max 82% width.

**Thinking row.** 20 dp Eve mark + "Eve soch rahi hai" in `eve`, opacity pulse 800 ms. Replaces the three-dot indicator.

**Composer.** 52 dp pill field on `surface`, always enabled. Send is a 52 dp circle in `action`; while Eve is generating it turns `raised` with `ink3` icon (disabled, not hidden). Quick replies: outlined pills above it, 48 dp tall, 15 sp, 2 to 3, contextual.

**Inline privacy note.** `surface` nested slab, 14 sp text, icon tinted `safeText` when the note describes a protection. Chat: "Yeh chat sirf is phone par save hai. Eve ke jawab hamare server se aate hain." Never claim Eve runs on the phone.

**Mood check-in.** Five options in this order: Bahut bura, Theek nahi, Theek hoon, Acha, Zabardast. Each is a 28 dp moon (new, crescent, half, gibbous, full) over its label at 14 sp (labels wrap to two lines, "Zabardast" stays one word), 48 dp minimum target, `radiogroup` semantics. Under the row, the scale ends in words: "Empty moon: hardest" on the left, "Full: best" on the right. Show them until the person has logged three check-ins, then hide them; the labels stay forever. Selected: `raised` background, moon scales 1.1 with a 2 px `action` ring, label 700. 450 ms after the tap the card folds to one line: moon + label + "Saved on this phone, 9:41 pm" + "Change". No confirm step, no loading state.

**Week trend.** Seven columns, a moon per logged day placed by value, joined by a 1.5 px `ink3` line. A missed day is a short flat dash (12 x 2 dp, `ink3`), smaller than any moon and never round, so it can't be read as "Bahut bura". The line breaks around it. Today, before a check-in, shows the same dash. No streak count. Semantics label reads the whole week.

**Welcome.** Headline "Someone to talk to, day or night." (not "any hour": Eve is served and can be down; the helplines carry the 24/7 promise). When Eve can't be reached, the chat shows the existing "Eve is resting" state with exercises and Get help, never an error.

**Language switch.** Three 48 dp segments: English, Roman Urdu, اردو.

**Insight.** One sentence, then "Based on N check-ins. A pattern, not a diagnosis." with an info icon.

**Breathing screen.** Full screen, no tab bar. A 288 dp circular stage holds the breath flower (its own asset, never Eve): it opens on the in-breath, holds, folds on the out-breath, holds, while a bead laps the guide ring once per 16 s loop. Phase word in Unbounded 30, count in Mono, step pills In 4 / Hold 4 / Out 4 / Hold 4 at 14 sp. Pause as an outlined pill. "Stop whenever you like. Nothing is counted."

**Journal list.** Date in Mono, small moon, two-line clamp. Urdu entries render in Nastaliq RTL. Storage note: "Entries are saved to your account, so you can read them on another phone. A clinician sees them only if you turn sharing on."

**Switch.** 52 x 32 pill. On: `safe` track, `onSafe` knob. Off: `raised` track with strong hairline, `ink3` knob.

**Where your things are kept.** Three rows on the privacy screen: Only on this phone (Eve chats and the mood read from them), In your account (check-ins you log, journal, assessments), With a clinician (nothing until you switch it on). Update these lines whenever the data flow changes.

**Bottom nav.** Eve, Today, Journal, You, labels 14 sp. Phosphor light icons; active tab uses the fill icon in `primaryActionText` on a 56 x 30 `raised` pill. Each tab is at least 52 dp tall.

Icons: Phosphor (`phosphor_flutter`), light weight for everything, fill only for the active tab and the crisis heart.

## 6. Motion

Fast where the app responds, slow only where the body is involved.

| Moment | Duration | Curve | Reduced motion |
|---|---|---|---|
| Press any pressable | 160 ms to 0.97 scale, faster release | ease-out `Cubic(0.23, 1, 0.32, 1)` | colour change only |
| Mood select, switch | 200 to 220 ms | ease-out | instant, ring still shows |
| Check-in fold | 260 ms after a 450 ms hold | ease-out | crossfade 150 ms |
| Summary line in | 240 ms fade + 4 px rise | ease-out | fade only |
| Sheet open / close | 320 ms / 200 ms | drawer `Cubic(0.32, 0.72, 0, 1)` | fade 150 ms |
| Eve idle halo | 6 s loop, scale 0.96 to 1.03 | ease-in-out `Cubic(0.77, 0, 0.175, 1)` | static halo, poster still |
| Eve listening | 240 ms, halo warms toward pink | ease-out | colour change without motion |
| Eve thinking | 1.6 s halo pulse, 800 ms text pulse | ease-in-out | status text only |
| Breath clock | 16 s, 4 4 4 4 | clip time (the bead laps at constant speed) | poster still; words and count only |
| Get help, crisis sheet content | none | none | none |

Rules: animate transform and opacity only. No page-load choreography in the app. No bounce. Every animation honours the OS setting (`MediaQuery.disableAnimations`) and the in-app Reduce motion toggle. Under reduced motion, 3D assets show their poster PNG and videos do not play.

One clock drives breathing. With video or GLB, the phase word, count and step pills read the clip's own position (`VideoPlayerController.position` or the Filament animator time) modulo 16 s, so text and picture can't drift. With no clip running (reduced motion, poster only), a single `AnimationController(duration: 16 s)` drives the text.

## 7. 3D

Assets from the Blender pipeline, in `assets/3d/` in the app and `3d/` next to the concept page:

- `eve.glb`: clips `idle` (8 s, one slow breath), `listening` (4 s, leans in, petals open, inner glow shows), `thinking` (8 s, petals counter-rotate, haze swirl turns). A twisted jasmine/lotus bud with a hidden flame core over two faint ripple rings, violet aura, no face. No lime anywhere: rings, rim and motes are violet `#A36FFF` and white-pink `#FFD3EA`, so lime stays the protected-state colour only.
- `breath.glb`: clip `box`, 16 s. An eight-petal flower inside a guide ring: 0 to 4 s petals unfold, 4 to 8 s hold open, 8 to 12 s fold to a bud, 12 to 16 s hold closed. A bead laps the ring once per loop.
- `eve-idle.mp4` / `.webm` (8 s), `breath-box.mp4` / `.webm` (16 s): 720 x 720 renders with bloom. The mp4s sit on `#1D1E2C`; the webms carry alpha (web only: Android `video_player` can't show VP9 alpha and iOS can't play webm, so the app uses the mp4s on a `#1D1E2C` backing).
- `eve.png`, `breath.png`: 720 x 720 posters. `eve-hero.png` 1080 x 1920: Eve in a plum-to-night space with drifting petals and motes, lower 40% left empty for copy.

The renders have bloom, rim light and motes that the glb can't carry, so the glb looks flatter. Rule: use the video or poster wherever the glow matters, and the live glb only where Eve's state has to change.

### Where 3D lives

- Welcome: `eve-hero.png` full bleed behind the whole screen, headline, facts and Continue in its empty lower 40%, with a gradient to `#1D1E2C` under the text. It stays dark in light mode (Eve's night). Cheapest possible first run: one image, no WebGL, no download.
- Eve chat header: live `eve.glb` at 52 dp, the one place her state changes. `listening` while the user types, `thinking` from send until the first token, `idle` otherwise. Crossfade 300 ms between clips.
- Breathing: the breath flower, `box`, centre of the screen. It must never look like Eve: Eve is a companion, breath is a tool. The concept page uses the rendered `breath-box` video here because it keeps the baked glow and exact timing; on capable phones the GLB is allowed.
- One live 3D view per screen, at most.

### Where it never goes

- The crisis sheet, crisis card, session bar, or anything help-related. Help is flat, still and paper.
- Assessments, consent, sign-in, settings, journal.
- Behind text or as a background loop.
- No emotional reaction to a crisis flag (no "sad Eve"). In crisis mode Eve holds `idle`.

### Fallback ladder (low-end Android)

1. GLB through Filament (or model-viewer on web) when the device reports 6 GB RAM or more, is not in battery saver, and reduced motion is off.
2. Video loop (WebM VP9, MP4 H.264 fallback) on 2 to 4 GB RAM or data saver. Keep each loop under 600 KB.
3. Poster still (WebP in the app, 150 KB max) under reduced motion, battery saver, or if 3D fails to load in 1.5 s. This is the default fallback: the person always sees the real render, never a generic glowing ball.
4. Painted silhouette, only if no asset is on the phone at all: for Eve a flat bud (pointed top, round base, pink to violet), for breath the guide ring and a pink core. Never a glossy sphere.

The layout never depends on which rung loads: every Eve slot has a fixed square size, and the poster fills it until the asset is ready. The renders have a night background (`#1E1F2D`), so on the plum ground they are composited with a lighten blend and a soft radial edge; in light mode they sit in the eve well. Budgets: GLB under 1.5 MB each, under 30k triangles, one emissive material, baked animation, no real-time shadows. Pause rendering when the view is off screen or the app is backgrounded.

The concept page uses `@google/model-viewer@4.0.0` (pinned; 4.3.1 is current if an upgrade is needed) with `autoplay`, `animation-name`, `interaction-prompt="none"`, `disable-zoom`, no `camera-controls`, and the artist's fixed front camera: `camera-orbit="0deg 82deg auto"` with `field-of-view="28deg"` so Eve fills her slot. The aura, haze and rings are front-facing cards, so the camera must never orbit. In Flutter, prefer `flutter_scene` with a fixed camera on high-end phones (untested with these files: check emissive strength and the alpha cards first); `model_viewer_plus` works but costs a WebView. Cap real-time rendering at 30 fps and pause it off screen. For breathing, run the 4-4-4-4 timer in Dart and seek or restart the video each cycle so a dropped frame can't drift the count.

## 8. Copy rules that the visuals depend on

- No em or en dashes in UI text.
- Never write "Eve runs on this phone". Eve replies from the server; chat history is stored only on the phone.
- The journal lives in the account; say so where it is written.
- Nothing is shared with a clinician unless the user switches it on, item by item.
- No streaks, no "you missed", no confetti, no "great job" on good moods.
- Helpline numbers are written in text, not only in buttons. Umang 0311-7786264, Rescue 1122, Madadgaar 1098 are still unverified (owner decision D2), and all crisis copy needs clinician sign-off (D1).

## 9. Open items

- `listening` and `thinking` exist only in the glb. If low-end phones should also show Eve's state in the chat header, the artist can add mp4 loops for them (a few lines in `src/eve.py`).
- flutter_scene has not been tested with these files.
- The moon scale is new. Test it with 5 people before locking it; if the meaning isn't clear, fall back to five filled dots of increasing size with the same labels.
- Roman Urdu strings on the mockups need native review (D8), especially "Bachon aur khawateen ke liye" as the Madadgaar scope line.
- Unbounded and Atkinson Hyperlegible Next need a check at 1.6x text scale on a 360 dp wide phone; Unbounded titles may need to drop to 24.
