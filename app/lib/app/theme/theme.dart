import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the full [ThemeData] for the given brightness.
///
/// Pass [urduScript] = true when the active locale uses Noto Nastaliq Urdu
/// script (Urdu-script UI, phase 2). For Roman Urdu and English the Latin
/// text theme is used.
ThemeData buildTheme(Brightness brightness, {required bool urduScript}) {
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: dark ? Tokens.primaryDark : Tokens.primaryLight,
    brightness: brightness,
    surface: dark ? Tokens.groundDark : Tokens.groundLight,
    primary: dark ? Tokens.primaryDark : Tokens.primaryLight,
    secondary: dark ? Tokens.secondaryDark : Tokens.secondaryLight,
    onSurface: dark ? Tokens.inkDark : Tokens.inkLight,
    tertiary: dark ? Tokens.urgentDark : Tokens.urgentLight,
    error: dark ? Tokens.errorDark : Tokens.errorLight,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );

  // Latin body font: Manrope (clean, humanist sans; matches brand direction).
  final latin = GoogleFonts.manropeTextTheme(base.textTheme);

  // Urdu-script overlay for phase 2 (Noto Nastaliq Urdu; Roman Urdu stays LTR
  // with the Latin font — see locale.dart).
  final text = (urduScript
          ? GoogleFonts.notoNastaliqUrduTextTheme(latin)
          : latin)
      .apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  final cardColor = dark ? Tokens.surfaceDark : Tokens.surfaceLight;
  final outline =
      scheme.onSurface.withValues(alpha: dark ? 0.12 : 0.08);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1),
      headlineMedium: text.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.15),
      headlineSmall: text.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.55),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.55),
      labelLarge:
          text.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.rCard),
        side: BorderSide(color: outline),
      ),
    ),
    dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Tokens.s16, vertical: Tokens.s16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.rSmall),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.rSmall),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.rSmall),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle:
            text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        side: BorderSide(color: outline),
        foregroundColor: scheme.onSurface,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide(color: outline),
      backgroundColor: cardColor,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardColor,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: cardColor,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(Tokens.rSheet)),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.rSmall)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android:
          _CalmTransitionsBuilder(FadeForwardsPageTransitionsBuilder()),
      TargetPlatform.iOS:
          _CalmTransitionsBuilder(CupertinoPageTransitionsBuilder()),
      TargetPlatform.macOS:
          _CalmTransitionsBuilder(CupertinoPageTransitionsBuilder()),
      TargetPlatform.windows:
          _CalmTransitionsBuilder(FadeForwardsPageTransitionsBuilder()),
      TargetPlatform.linux:
          _CalmTransitionsBuilder(FadeForwardsPageTransitionsBuilder()),
    }),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// Skips the platform transition entirely when the OS (or the app's in-app
/// toggle) has disabled animations. Wraps any [PageTransitionsBuilder].
class _CalmTransitionsBuilder extends PageTransitionsBuilder {
  const _CalmTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    final delegated = inner.delegatedTransition;
    if (delegated == null) return null;
    return (ctx, anim, secAnim, snap, child) =>
        MediaQuery.disableAnimationsOf(ctx)
            ? child
            : delegated(ctx, anim, secAnim, snap, child);
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      MediaQuery.disableAnimationsOf(context)
          ? child
          : inner.buildTransitions(
              route, context, animation, secondaryAnimation, child);
}
