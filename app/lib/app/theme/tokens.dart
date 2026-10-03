import 'package:flutter/material.dart';

// ignore_for_file: avoid_classes_with_only_static_members

/// Raw legacy palette. Every named role derives from exactly one constant here.
/// Feature code must not reference [Jugnu] directly — use [JugnuColors] roles
/// (from `Theme.of(context).extension<JugnuColors>()`) or [ColorScheme] slots.
abstract final class Jugnu {
  // ── legacy palette ─────────────────────────────────────────────────────────
  static const night = Color(0xFF1D1E2C);
  static const plum = Color(0xFF34063F);
  static const navy = Color(0xFF001F54);
  static const paper = Color(0xFFF5F0FB);

  // ── dark ink ───────────────────────────────────────────────────────────────
  static const ink = Color(0xFFF4EFF9);
  static const ink2 = Color(0xFFC9BEDA);
  static const ink3 = Color(0xFFA497B8);

  // ── dark action ────────────────────────────────────────────────────────────
  static const action = Color(0xFFF23598);
  static const onAction = Color(0xFF16061C);
  static const actionText = Color(0xFFFF6EB4); // text on dark ground/raised

  // ── dark eve ───────────────────────────────────────────────────────────────
  static const eve = Color(0xFFB48BFF);
  static const eveMid = Color(0xFF8A4FFF);
  static const eveDeep = Color(0xFF6E29FF);
  static const eveHaze = Color(0xFFA36FFF);

  // ── dark safe (protected-state) ────────────────────────────────────────────
  static const safe = Color(0xFF89F336);
  static const onSafe = Color(0xFF14200A);

  // ── dark surfaces ──────────────────────────────────────────────────────────
  /// white 6% overlay: slabs, composer, notes
  static const surface = Color(0x0FFFFFFF);
  /// white 10% overlay: user bubble, selected option, tab marker
  static const raised = Color(0x1AFFFFFF);
  /// white 12%: hairlines, outlines
  static const hair = Color(0x1FFFFFFF);
  /// white ~22%: strong hairlines
  static const hairStrong = Color(0x38FFFFFF);

  // ── light palette overrides ────────────────────────────────────────────────
  static const groundLightTop = Color(0xFFF7F4FB);
  static const groundLightBottom = Color(0xFFEFE6F5);
  static const ink2Light = Color(0xFF4B4A6B);
  static const ink3Light = Color(0xFF5A5878);
  static const actionLight = Color(0xFFB80F66);
  static const actionTextLight = Color(0xFFB80F66);
  static const eveLight = Color(0xFF6E29FF);
  static const safeLight = Color(0xFF38A711);
  static const safeTextLight = Color(0xFF2B7A0E);

  // ── gradients ──────────────────────────────────────────────────────────────
  static const groundDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [night, plum],
  );
  static const groundLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [groundLightTop, groundLightBottom],
  );

  // ── spacing (4 dp base grid) ───────────────────────────────────────────────
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;
  static const s52 = 52.0;

  // ── radii ──────────────────────────────────────────────────────────────────
  /// slab/card outer radius
  static const rSlab = 24.0;
  /// nested card inside a slab (slab − 6 dp padding)
  static const rNested = 18.0;
  /// bottom sheet top corners
  static const rSheet = 24.0;
  /// user-bubble speech corner
  static const rSpeech = 8.0;

  // ── layout constraints ─────────────────────────────────────────────────────
  static const screenGutter = 20.0;
  static const slabPadding = 18.0;
  static const readingWidth = 640.0;
  static const clinicianRail = 1024.0;

  // ── target sizes ──────────────────────────────────────────────────────────
  static const minTarget = 48.0;
  static const primaryButtonHeight = 52.0;
  static const navBarHeight = 68.0;

  // ── motion ────────────────────────────────────────────────────────────────
  static const motionPress = Duration(milliseconds: 160);
  static const motionMood = Duration(milliseconds: 200);
  static const motionFold = Duration(milliseconds: 260);
  static const motionFoldHold = Duration(milliseconds: 450);
  static const motionSummaryIn = Duration(milliseconds: 240);
  static const motionSheetOpen = Duration(milliseconds: 320);
  static const motionSheetClose = Duration(milliseconds: 200);
  static const motionThinkingPulse = Duration(milliseconds: 800);
  static const motionBreath = Duration(seconds: 16);

  static const curveEaseOut = Cubic(0.23, 1, 0.32, 1);
  static const curveEaseIO = Cubic(0.77, 0, 0.175, 1);
  static const curveSheet = Cubic(0.32, 0.72, 0, 1);
  static const pressScale = 0.97;
}

// ── Named role token extension ─────────────────────────────────────────────

/// [ThemeExtension] that carries every named Jugnu colour role.
///
/// Widgets must only read these named getters; they must not touch [Jugnu.*]
/// directly. This lets the two modes (dark/light) swap colours under the hood
/// without any feature code changing.
@immutable
class JugnuColors extends ThemeExtension<JugnuColors> {
  const JugnuColors({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.hair,
    required this.hairStrong,
    required this.ink2,
    required this.ink3,
    required this.actionText,
    required this.eve,
    required this.safe,
    required this.onSafe,
    required this.safeText,
    required this.helpBg,
    required this.helpInk,
    required this.eveWell,
    required this.scrim,
    required this.moonFill,
    required this.moonRing,
  });

  final Gradient ground;
  final Color surface;
  final Color raised;
  final Color hair;
  final Color hairStrong;
  final Color ink2;
  final Color ink3;
  final Color actionText;
  final Color eve;
  final Color safe;
  final Color onSafe;
  final Color safeText;
  final Color helpBg;
  final Color helpInk;
  /// Radial gradient behind Eve in light mode; null (transparent) in dark.
  final Gradient? eveWell;
  final Color scrim;
  final Color moonFill;
  final Color moonRing;

  // ── named role accessors ──────────────────────────────────────────────────

  /// Eve's name, status line, thinking row, halo tint.
  Color get evePresence => eve;

  /// Active links, tab icon, selection ring. (Primary action comes from ColorScheme.primary.)
  Color get primaryActionText => actionText;

  /// Switch on, "only on this phone", lock active — track colour.
  Color get protectedState => safe;
  Color get onProtectedState => onSafe;

  /// Crisis sheet / card background.
  Color get helpSurface => helpBg;

  /// Text on the crisis sheet / card.
  Color get onHelpSurface => helpInk;

  // ── constants ─────────────────────────────────────────────────────────────

  static const dark = JugnuColors(
    ground: Jugnu.groundDark,
    surface: Jugnu.surface,
    raised: Jugnu.raised,
    hair: Jugnu.hair,
    hairStrong: Jugnu.hairStrong,
    ink2: Jugnu.ink2,
    ink3: Jugnu.ink3,
    actionText: Jugnu.actionText,
    eve: Jugnu.eve,
    safe: Jugnu.safe,
    onSafe: Jugnu.onSafe,
    safeText: Jugnu.safe,
    helpBg: Jugnu.paper,
    helpInk: Jugnu.navy,
    eveWell: null,
    scrim: Color(0xBD0C0914), // #0C0914 74%
    moonFill: Jugnu.ink,
    moonRing: Jugnu.ink3,
  );

  static const light = JugnuColors(
    ground: Jugnu.groundLight,
    surface: Colors.white,
    raised: Colors.white,
    hair: Color(0x1F34063F), // plum 12%
    hairStrong: Color(0x3D34063F), // plum 24%
    ink2: Jugnu.ink2Light,
    ink3: Jugnu.ink3Light,
    actionText: Jugnu.actionTextLight,
    eve: Jugnu.eveLight,
    safe: Jugnu.safeLight,
    onSafe: Colors.white,
    safeText: Jugnu.safeTextLight,
    helpBg: Jugnu.navy,
    helpInk: Jugnu.paper,
    eveWell: RadialGradient(
      colors: [Jugnu.plum, Jugnu.night, Color(0x001D1E2C)],
      stops: [0.46, 0.70, 0.71],
    ),
    scrim: Color(0x7334063F), // plum 45%
    moonFill: Jugnu.navy,
    moonRing: Jugnu.ink3Light,
  );

  @override
  JugnuColors copyWith({
    Gradient? ground,
    Color? surface,
    Color? raised,
    Color? hair,
    Color? hairStrong,
    Color? ink2,
    Color? ink3,
    Color? actionText,
    Color? eve,
    Color? safe,
    Color? onSafe,
    Color? safeText,
    Color? helpBg,
    Color? helpInk,
    Gradient? eveWell,
    Color? scrim,
    Color? moonFill,
    Color? moonRing,
  }) =>
      JugnuColors(
        ground: ground ?? this.ground,
        surface: surface ?? this.surface,
        raised: raised ?? this.raised,
        hair: hair ?? this.hair,
        hairStrong: hairStrong ?? this.hairStrong,
        ink2: ink2 ?? this.ink2,
        ink3: ink3 ?? this.ink3,
        actionText: actionText ?? this.actionText,
        eve: eve ?? this.eve,
        safe: safe ?? this.safe,
        onSafe: onSafe ?? this.onSafe,
        safeText: safeText ?? this.safeText,
        helpBg: helpBg ?? this.helpBg,
        helpInk: helpInk ?? this.helpInk,
        eveWell: eveWell ?? this.eveWell,
        scrim: scrim ?? this.scrim,
        moonFill: moonFill ?? this.moonFill,
        moonRing: moonRing ?? this.moonRing,
      );

  @override
  JugnuColors lerp(ThemeExtension<JugnuColors>? other, double t) =>
      t < 0.5 ? this : (other as JugnuColors? ?? this);
}

/// Builds the [ColorScheme] for either mode.
ColorScheme jugnuScheme(Brightness b) => b == Brightness.dark
    ? const ColorScheme.dark(
        primary: Jugnu.action,
        onPrimary: Jugnu.onAction,
        secondary: Jugnu.eve,
        onSecondary: Jugnu.night,
        tertiary: Jugnu.safe,
        onTertiary: Jugnu.onSafe,
        surface: Jugnu.night,
        onSurface: Jugnu.ink,
        onSurfaceVariant: Jugnu.ink2,
        outline: Jugnu.hairStrong,
        outlineVariant: Jugnu.hair,
        // errors use ink + warning icon, not a colour
        error: Jugnu.ink,
        onError: Jugnu.night,
      )
    : const ColorScheme.light(
        primary: Jugnu.actionLight,
        onPrimary: Colors.white,
        secondary: Jugnu.eveLight,
        onSecondary: Colors.white,
        tertiary: Jugnu.safeLight,
        onTertiary: Colors.white,
        surface: Jugnu.groundLightTop,
        onSurface: Jugnu.navy,
        onSurfaceVariant: Jugnu.ink2Light,
        outline: Color(0x3D34063F),
        outlineVariant: Color(0x1F34063F),
        error: Jugnu.navy,
        onError: Colors.white,
      );

/// Respects reduced-motion preferences: returns [Duration.zero] when the OS
/// setting or the in-app toggle has disabled animations.
extension MotionX on BuildContext {
  Duration motion(Duration d) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : d;
}

// ── Backward-compatibility shim ───────────────────────────────────────────
//
// Existing feature screens written against the provisional `Tokens` class
// continue to compile. New code must use `Jugnu.*` palette names or, better,
// the `JugnuColors` role accessors from the theme extension.
//
// Spacing and layout constants in `Tokens` map directly to `Jugnu`.

/// @deprecated Use [Jugnu] palette names or [JugnuColors] role tokens instead.
abstract final class Tokens {
  static const s4 = Jugnu.s4;
  static const s8 = Jugnu.s8;
  static const s12 = Jugnu.s12;
  static const s16 = Jugnu.s16;
  static const s20 = Jugnu.s20;
  static const s24 = Jugnu.s24;
  static const s32 = Jugnu.s32;
  static const s48 = Jugnu.s48;
  static const readingWidth = Jugnu.readingWidth;
  static const clinicianRail = Jugnu.clinicianRail;

  // Provisional colours — kept for compilation; feature code should not rely on these.
  static const brand = Color(0xFF11ACBC);
  static const groundDark = Jugnu.night;
  static const groundLight = Jugnu.groundLightTop;
  static const surfaceDark = Color(0xFF252035);
  static const surfaceLight = Colors.white;
  static const inkDark = Jugnu.ink;
  static const inkLight = Jugnu.navy;
  static const accent = Color(0xFF0E7A85);
  static const accentDark = Color(0xFF4FC9D8);
  static const rSmall = Jugnu.rNested;
  static const rCard = Jugnu.rSlab;
  static const rSheet = Jugnu.rSheet;
  static const fast = Jugnu.motionPress;
  static const normal = Jugnu.motionSummaryIn;
  static const slow = Jugnu.motionSheetOpen;

  static const valence = [
    Color(0xFF6E7FA3), // -2
    Color(0xFF8A98B8), // -1
    Color(0xFFA9A6B0), //  0
    Color(0xFF8FB39A), // +1
    Color(0xFF5E9A7A), // +2
  ];

  static Color valenceColor(int v) => valence[(v + 2).clamp(0, 4)];
}
