import 'package:flutter/material.dart';

/// Design tokens — every visual decision derives from here.
///
/// This is a **provisional** palette drawn from the legacy brand:
///   night #1D1E2C · plum #34063F · pink #F23598 · violet #8A4FFF · lime #89F336
///
/// The design team's approved system will replace this file in one place; no
/// hex literals appear anywhere else in the codebase.
abstract final class Tokens {
  // ---------------------------------------------------------------------------
  // Legacy brand palette (source of truth; derive everything else from here)
  // ---------------------------------------------------------------------------

  /// Deep midnight blue-black. Primary dark scaffold background.
  static const night = Color(0xFF1D1E2C);

  /// Deep plum purple. Dark card/surface colour.
  static const plum = Color(0xFF34063F);

  /// Hot pink. Primary action colour (dark mode). ~4.7:1 on [night].
  static const pink = Color(0xFFF23598);

  /// Violet purple. Secondary accent. ~3.1:1 on [night] — use for large UI
  /// elements, not body text.
  static const violet = Color(0xFF8A4FFF);

  /// Lime green. Positive/wellness indicator (trend up, exercise complete).
  static const lime = Color(0xFF89F336);

  // ---------------------------------------------------------------------------
  // Dark theme (default / "dark-first")
  // ---------------------------------------------------------------------------

  static const groundDark = night;

  /// Slightly lighter than [night] so cards float. Avoids pure [plum] which
  /// reads as brand rather than neutral container at small sizes.
  static const surfaceDark = Color(0xFF252035);

  /// Near-white with a faint lavender tint — readable on [groundDark] and
  /// [surfaceDark] at >16:1.
  static const inkDark = Color(0xFFF5EEFF);

  /// Primary action in dark mode: hot pink. AA at 4.7:1 on [groundDark].
  static const primaryDark = pink;

  /// Secondary action in dark mode: violet. AA large-text on [groundDark].
  static const secondaryDark = violet;

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------

  /// Lavender-tinted off-white. Soft, brand-adjacent, avoids clinical white.
  static const groundLight = Color(0xFFF5F0FF);

  static const surfaceLight = Color(0xFFFFFFFF);

  /// Near-black with a plum tint — readable on [groundLight] at >16:1.
  static const inkLight = Color(0xFF1A0A25);

  /// Darkened pink for light mode — 5.8:1 on [groundLight], passes AA.
  static const primaryLight = Color(0xFFB8007A);

  /// Darkened violet for light mode — 4.6:1 on [groundLight], passes AA.
  static const secondaryLight = Color(0xFF6B30D6);

  // ---------------------------------------------------------------------------
  // Shared semantic colours
  // ---------------------------------------------------------------------------

  /// Crisis / urgent action. Never red (too close to error). These are the warm
  /// tones that work for the helpline call button.
  static const urgentDark = Color(0xFFE0A35C);
  static const urgentLight = Color(0xFF945F22);

  /// Form and input errors — deliberately different from crisis.
  static const errorDark = Color(0xFFF2B8B5);
  static const errorLight = Color(0xFFB3261E);

  // ---------------------------------------------------------------------------
  // Valence scale −2 … +2 (cool slate → sage green; no red/green traffic lights)
  // ---------------------------------------------------------------------------

  static const valence = [
    Color(0xFF6E7FA3), // −2
    Color(0xFF8A98B8), // −1
    Color(0xFFA9A6B0), //  0
    Color(0xFF8FB39A), // +1
    Color(0xFF5E9A7A), // +2
  ];

  static Color valenceColor(int v) => valence[(v + 2).clamp(0, 4)];

  // ---------------------------------------------------------------------------
  // Spacing scale (4-point grid)
  // ---------------------------------------------------------------------------

  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;

  // ---------------------------------------------------------------------------
  // Border radii
  // ---------------------------------------------------------------------------

  static const rSmall = 12.0;
  static const rCard = 18.0;
  static const rSheet = 28.0;

  // ---------------------------------------------------------------------------
  // Motion durations (all conditional on MediaQuery.disableAnimations)
  // ---------------------------------------------------------------------------

  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 360);

  // ---------------------------------------------------------------------------
  // Layout constraints
  // ---------------------------------------------------------------------------

  /// Max width for reading content on wide screens.
  static const readingWidth = 640.0;

  /// Max width for the clinician workspace content area.
  static const clinicianRail = 1024.0;
}

/// Utility to respect reduced-motion preferences from the OS and the in-app toggle.
extension MotionX on BuildContext {
  Duration motion(Duration d) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : d;
}
