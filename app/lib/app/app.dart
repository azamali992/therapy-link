import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/consent_sync.dart';
import '../core/settings/settings.dart';
import '../features/shared/privacy_gate.dart';
import '../l10n/app_localizations.dart';
import 'locale.dart';
import 'router.dart';
import 'theme/theme.dart';

/// The OS text scale times the in-app slider, capped so an OS already at 2× doesn't become 3.2×
/// and break every fixed layout. 2.0 is past the 1.6× the design is tested at.
double effectiveTextScale(double os, double app) => (os * app).clamp(0.8, 2.0);

class TherapyLinkApp extends ConsumerWidget {
  const TherapyLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    // Keeps consent state on the server in sync after sign-in.
    ref.watch(consentSyncProvider);

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
      // Quick exit resets navigation to the start; '/' redirects to the home tab for the role.
      builder: (context, child) => appFrame(context, PrivacyGate(onQuickExit: () => router.go('/'), child: child!), settings),
    );
  }
}

/// Wraps every route: text scale, reduced motion and, for Roman Urdu, left-to-right layout.
Widget appFrame(BuildContext context, Widget child, Settings settings) {
  final mq = MediaQuery.of(context);
  final framed = MediaQuery(
    data: mq.copyWith(
      textScaler: TextScaler.linear(effectiveTextScale(mq.textScaler.scale(1.0), settings.textScale)),
      disableAnimations: mq.disableAnimations || settings.reduceMotion,
    ),
    child: child,
  );
  if (!isRomanUrdu(Localizations.localeOf(context))) return framed;
  return Directionality(textDirection: TextDirection.ltr, child: framed);
}
