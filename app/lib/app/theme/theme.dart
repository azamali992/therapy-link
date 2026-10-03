import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

// ── Font family name constants ─────────────────────────────────────────────
// These must match exactly what is declared under flutter.fonts in pubspec.yaml.

const _kDisplay = 'Unbounded';
const _kUI = 'AtkinsonHyperlegibleNext';
const _kMono = 'AtkinsonHyperlegibleMono';
const _kUrdu = 'NotoNastaliqUrdu';

// ── Type scale ────────────────────────────────────────────────────────────

/// Returns a [TextTheme] with all Jugnu named styles applied.
/// [ink] is the default text colour (changes between dark and light).
TextTheme _jugnuTextTheme(Color ink) {
  return TextTheme(
    // display 28/34 Unbounded 300, -0.02em
    displaySmall: TextStyle(
      fontFamily: _kDisplay,
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w300,
      letterSpacing: 28 * -0.02,
      color: ink,
    ),

    // title 20/26 Unbounded 400, -0.01em
    titleLarge: TextStyle(
      fontFamily: _kDisplay,
      fontSize: 20,
      height: 26 / 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 20 * -0.01,
      color: ink,
    ),

    // heading 22/28 Atkinson 700 (sheets, crisis)
    headlineSmall: TextStyle(
      fontFamily: _kUI,
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w700,
      color: ink,
    ),

    // card titles 16/22 Atkinson 700
    titleMedium: TextStyle(
      fontFamily: _kUI,
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w700,
      color: ink,
    ),

    // body 16/24 Atkinson 400
    bodyLarge: TextStyle(
      fontFamily: _kUI,
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      color: ink,
    ),

    // notes / helper text 14/20 Atkinson 400
    bodyMedium: TextStyle(
      fontFamily: _kUI,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      color: ink,
    ),

    // buttons 16/16 Atkinson 700
    labelLarge: TextStyle(
      fontFamily: _kUI,
      fontSize: 16,
      height: 1.0,
      fontWeight: FontWeight.w700,
      color: ink,
    ),

    // chips / tabs / mood labels 14/18 Atkinson 600
    labelMedium: TextStyle(
      fontFamily: _kUI,
      fontSize: 14,
      height: 18 / 14,
      fontWeight: FontWeight.w600,
      color: ink,
    ),

    // timestamps 13/18 Mono 500
    labelSmall: TextStyle(
      fontFamily: _kMono,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w500,
      color: ink,
      fontFeatures: [const FontFeature.tabularFigures()],
    ),

    // override bodySmall for urdu body (declared separately via jugnuUrduBody)
    bodySmall: TextStyle(
      fontFamily: _kUI,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      color: ink,
    ),
  );
}

/// Urdu script body style — applied only to widgets that render Urdu script.
/// Roman Urdu stays in [_kUI] with [TextDirection.ltr].
TextStyle jugnuUrduBody(Color ink) => TextStyle(
      fontFamily: _kUrdu,
      fontSize: 18,
      height: 2.0,
      fontWeight: FontWeight.w400,
      color: ink,
    );

/// Helpline number style — selectable, large mono.
TextStyle jugnuNumberLarge(Color ink) => TextStyle(
      fontFamily: _kMono,
      fontSize: 26,
      height: 30 / 26,
      fontWeight: FontWeight.w600,
      color: ink,
      fontFeatures: [const FontFeature.tabularFigures()],
    );

/// Timestamp style (shortcut for [TextTheme.labelSmall]).
TextStyle jugnuTimestamp(Color ink) => TextStyle(
      fontFamily: _kMono,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w500,
      color: ink,
      fontFeatures: [const FontFeature.tabularFigures()],
    );

// ── ThemeData builder ─────────────────────────────────────────────────────

/// Builds the full [ThemeData] for the given [brightness].
///
/// [urduScript] is reserved for a future phase where the entire app UI is
/// rendered in Urdu script (Noto Nastaliq). Today it is always false for
/// English and Roman-Urdu locales — individual widgets call [jugnuUrduBody]
/// directly when they need to render Arabic-script Urdu.
ThemeData buildTheme(Brightness brightness, {bool urduScript = false}) {
  final dark = brightness == Brightness.dark;
  final jugnuExt = dark ? JugnuColors.dark : JugnuColors.light;
  final scheme = jugnuScheme(brightness);
  final ink = scheme.onSurface;

  final text = _jugnuTextTheme(ink);

  final cardColor =
      dark ? const Color(0xFF33213F) : Colors.white; // slab solid bg

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    extensions: [jugnuExt],

    // Scaffold background is transparent so the gradient DecoratedBox shows
    // (widgets/jugnu_scaffold.dart paints the gradient).
    scaffoldBackgroundColor: Colors.transparent,

    textTheme: text,

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: ink),
    ),

    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Jugnu.rSlab),
        side: BorderSide(
            color: dark ? Jugnu.hair : const Color(0x1F34063F), width: 1),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: dark ? Jugnu.hair : const Color(0x1F34063F),
      space: 1,
      thickness: 1,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: jugnuExt.surface,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: Jugnu.s16, vertical: Jugnu.s16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Jugnu.rNested),
        borderSide: BorderSide(color: jugnuExt.hair),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Jugnu.rNested),
        borderSide: BorderSide(color: jugnuExt.hair),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Jugnu.rNested),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      hintStyle: text.bodyLarge?.copyWith(color: jugnuExt.ink3),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(Jugnu.primaryButtonHeight),
        shape: const StadiumBorder(),
        textStyle: text.labelLarge,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(Jugnu.primaryButtonHeight),
        shape: const StadiumBorder(),
        side: BorderSide(color: jugnuExt.hairStrong),
        foregroundColor: ink,
        textStyle: text.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: jugnuExt.primaryActionText,
        minimumSize: const Size(0, Jugnu.minTarget),
        textStyle: text.labelLarge,
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: jugnuExt.surface,
      shape: const StadiumBorder(),
      side: BorderSide(color: jugnuExt.hairStrong),
      labelStyle: text.labelMedium?.copyWith(color: ink),
    ),

    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return jugnuExt.safe;
        return jugnuExt.raised;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return jugnuExt.onSafe;
        return jugnuExt.ink3;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return jugnuExt.hairStrong;
      }),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardColor,
      indicatorColor: Colors.transparent,
      height: Jugnu.navBarHeight,
      labelTextStyle:
          WidgetStatePropertyAll(text.labelMedium?.copyWith(color: ink)),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: jugnuExt.helpBg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Jugnu.rSheet)),
      ),
      dragHandleColor: jugnuExt.helpInk.withValues(alpha: 0.28),
      dragHandleSize: const Size(40, 4),
      showDragHandle: true,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cardColor,
      contentTextStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Jugnu.rNested)),
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

// ── Page transition wrapper ───────────────────────────────────────────────

/// Skips platform transitions when the OS or in-app toggle has disabled
/// animations ([MediaQuery.disableAnimations]).
class _CalmTransitionsBuilder extends PageTransitionsBuilder {
  const _CalmTransitionsBuilder(this.inner);
  final PageTransitionsBuilder inner;

  @override
  Duration get transitionDuration => inner.transitionDuration;
  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    final d = inner.delegatedTransition;
    if (d == null) return null;
    return (ctx, anim, sec, snap, child) =>
        MediaQuery.disableAnimationsOf(ctx)
            ? child
            : d(ctx, anim, sec, snap, child);
  }

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
          Animation<double> animation, Animation<double> secondary, Widget child) =>
      MediaQuery.disableAnimationsOf(context)
          ? child
          : inner.buildTransitions(route, context, animation, secondary, child);
}
