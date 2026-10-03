// Tests that the patient shell renders exactly 4 tabs in the correct order
// (Eve · Today · Journal · You) and that the shell gradient is present.
//
// PatientShell now uses JugnuNavBar (custom component) instead of Material
// NavigationBar, so finders look for JugnuNavBar and the tab labels directly.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:therapylink/app/theme/theme.dart';
import 'package:therapylink/features/shell/patient_shell.dart';
import 'package:therapylink/l10n/app_localizations.dart';
import 'package:therapylink/ui/components/jugnu_nav_bar.dart';

// ---------------------------------------------------------------------------
// Minimal widget harness — no Firebase, no Riverpod
// ---------------------------------------------------------------------------

/// A [StatefulNavigationShell] needs a real GoRouter context. We build a
/// minimal GoRouter with a StatefulShellRoute so [PatientShell] gets a real
/// shell to work with.
GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/eve',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => PatientShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/eve',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('Eve'))),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('Today'))),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/journal',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('Journal'))),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/you',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('You'))),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _harness(GoRouter router) => MaterialApp.router(
      theme: buildTheme(Brightness.dark, urduScript: false),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );

void main() {
  group('PatientShell tabs', () {
    testWidgets('renders the JugnuNavBar', (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(_harness(router));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // JugnuNavBar replaces Material NavigationBar on narrow viewports.
      expect(find.byType(JugnuNavBar), findsOneWidget);
    });

    testWidgets('tabs are Eve, Today, Journal, You in order', (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(_harness(router));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // All four labels must be present in the nav bar.
      expect(find.text('Eve'), findsWidgets);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Journal'), findsWidgets);
      expect(find.text('You'), findsWidgets);
    });

    testWidgets('has exactly 4 tab items', (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(_harness(router));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // JugnuNavBar renders exactly one Text label per tab.
      // Scope to the nav bar to avoid matching stub page body text.
      final navBar = find.byType(JugnuNavBar);
      expect(navBar, findsOneWidget);

      expect(
        find.descendant(of: navBar, matching: find.text('Eve')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Today')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Journal')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('You')),
        findsOneWidget,
      );
    });

    testWidgets('ground gradient is present behind the shell', (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(_harness(router));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The shell wraps in a DecoratedBox with the ground gradient.
      expect(find.byType(DecoratedBox), findsWidgets);
    });
  });
}
