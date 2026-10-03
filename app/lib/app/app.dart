import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'locale.dart';
import 'router.dart';
import 'theme/theme.dart';

// ---------------------------------------------------------------------------
// Stub settings — TODO(core-team): replace with the real settings provider
// from lib/core/settings/settings.dart.
// ---------------------------------------------------------------------------

/// Placeholder settings bag. Replace with the real Settings model + provider.
/// TODO(core-team): wire to SharedPreferences via settingsProvider.
class _AppSettings {
  const _AppSettings();
  ThemeMode get themeMode => ThemeMode.dark; // dark-first default
  Locale? get locale => null;               // null = system locale
  double get textScale => 1.0;
  bool get reduceMotion => false;
}

final _appSettingsProvider = Provider<_AppSettings>((_) => const _AppSettings());

/// OS text scale × in-app slider, capped so an OS at 2× doesn't become 3.2×.
double effectiveTextScale(double os, double app) => (os * app).clamp(0.8, 2.0);

class TherapyLinkApp extends ConsumerWidget {
  const TherapyLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(_appSettingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TherapyLink',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, urduScript: false),
      darkTheme: buildTheme(Brightness.dark, urduScript: false),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: const [
        ...romanUrduDelegates,
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => _AppFrame(
        settings: settings,
        router: router,
        child: child!,
      ),
    );
  }
}

/// Wraps every route: applies the text scale, reduced-motion preference and,
/// for Roman Urdu, forces LTR layout so Latin-script copy isn't mirrored by
/// Flutter's ur-locale direction inference.
class _AppFrame extends StatelessWidget {
  const _AppFrame({
    required this.settings,
    required this.router,
    required this.child,
  });

  final _AppSettings settings;
  final dynamic router; // GoRouter — typed loosely to avoid an extra import
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    Widget framed = MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(
          effectiveTextScale(mq.textScaler.scale(1.0), settings.textScale),
        ),
        disableAnimations:
            mq.disableAnimations || settings.reduceMotion,
      ),
      child: child,
    );
    if (!isRomanUrdu(Localizations.localeOf(context))) return framed;
    // Roman Urdu content is written LTR (Latin script); override the RTL
    // direction that Flutter infers from the `ur` locale tag.
    return Directionality(textDirection: TextDirection.ltr, child: framed);
  }
}
