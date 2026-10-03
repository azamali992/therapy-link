import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/me_provider.dart';
import '../core/api/models.dart';
import '../core/auth/auth_providers.dart';
import '../core/settings/settings.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/clinician/caseload_screen.dart';
import '../features/clinician/patient_screen.dart';
import '../features/clinician/requests_screen.dart';
import '../features/eve/conversations_screen.dart';
import '../features/eve/eve_screen.dart';
import '../ui/gallery.dart';
import '../features/exercises/exercises_screen.dart';
import '../features/journal/journal_editor_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/onboarding/consent_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/shell/clinician_shell.dart';
import '../features/shell/patient_shell.dart';
import '../features/today/assessment_screen.dart';
import '../features/today/today_screen.dart';
import '../features/you/access_log_screen.dart';
import '../features/you/care_screen.dart';
import '../features/you/clinician_join_screen.dart';
import '../features/you/memory_screen.dart';
import '../features/you/settings_screen.dart';
import '../features/you/you_screen.dart';

/// The instruments reachable by link; any other name is turned away.
Instrument? instrumentFromPath(String? name) => switch (name) {
  'phq9' => Instrument.phq9,
  'gad7' => Instrument.gad7,
  _ => null,
};

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(meProvider, (_, _) => notifyListeners());
    _ref.listen(settingsProvider.select((s) => s.onboarded), (_, _) => notifyListeners());
    _ref.listen(settingsProvider.select((s) => s.consented), (_, _) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final settings = _ref.read(settingsProvider);
    return routeRedirect(
      state.uri,
      consented: settings.consented,
      onboarded: settings.onboarded,
      auth: _ref.read(authStateProvider),
      me: _ref.read(meProvider),
    );
  }
}

/// Pure redirect function — no framework dependencies, fully unit-testable.
///
/// Returns a replacement path when [uri] should be redirected, or null to stay.
String? routeRedirect(
  Uri uri, {
  required bool consented,
  required bool onboarded,
  required AsyncValue<Object?> auth,
  required AsyncValue<Me?> me,
}) {
  final path = uri.path;

  // Nothing opens, signed in or not, until the current consent version is accepted.
  if (!consented) {
    if (path == '/welcome' || path == '/consent') return null;
    return onboarded ? '/consent' : '/welcome';
  }

  if (auth.isLoading) return null;
  final signedIn = auth.value != null;
  final onAuthPages = path == '/welcome' || path == '/sign-in' || path == '/consent';

  if (!signedIn) {
    if (path == '/welcome' || path == '/sign-in') return null;
    return onboarded ? '/sign-in' : '/welcome';
  }
  if (me.isLoading) return null;
  final isClinician = me.value?.role == Role.clinician;
  if (onAuthPages || path == '/') return isClinician ? '/clinic' : '/eve';
  if (isClinician && !path.startsWith('/clinic')) return '/clinic';
  if (!isClinician && path.startsWith('/clinic')) return '/eve';
  // A deep link to an instrument the app doesn't know would otherwise throw in the builder.
  final seg = uri.pathSegments;
  if (seg.length >= 3 && seg[0] == 'today' && seg[1] == 'assess' && instrumentFromPath(seg[2]) == null) return '/today';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),

      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),

      // Debug-only component gallery — hidden from release builds.
      if (kDebugMode)
        GoRoute(path: '/gallery', builder: (_, _) => const UiGallery()),

      // -----------------------------------------------------------------------
      // Patient shell — 4 tabs: Eve · Today · Journal · You
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => PatientShell(shell: shell),
        branches: [
          // Tab 0: Eve
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/eve',
                builder: (_, _) => const EveScreen(),
                routes: [
                  GoRoute(
                    path: 'conversations',
                    builder: (_, _) => const ConversationsScreen(),
                  ),
                ],
              ),
            ],
          ),

          // Tab 1: Today
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (_, _) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: 'assess/:instrument',
                    builder: (_, s) => AssessmentScreen(
                      // The redirect has already turned unknown instrument names away.
                      instrument: instrumentFromPath(s.pathParameters['instrument']) ?? Instrument.phq9,
                    ),
                  ),
                  GoRoute(
                    path: 'exercises/:id',
                    builder: (_, s) => ExercisesScreen(id: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),

          // Tab 2: Journal
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/journal',
                builder: (_, _) => const JournalScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, s) => JournalEditorScreen(prompt: s.extra as String?),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => JournalEditorScreen(entryId: s.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),

          // Tab 3: You
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/you',
                builder: (_, _) => const YouScreen(),
                routes: [
                  GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
                  GoRoute(path: 'memory', builder: (_, _) => const MemoryScreen()),
                  GoRoute(path: 'access-log', builder: (_, _) => const AccessLogScreen()),
                  GoRoute(path: 'care', builder: (_, _) => const CareScreen()),
                  GoRoute(path: 'clinician', builder: (_, _) => const ClinicianJoinScreen()),
                ],
              ),
            ],
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // Clinician shell
      // -----------------------------------------------------------------------
      ShellRoute(
        builder: (_, _, child) => ClinicianShell(child: child),
        routes: [
          GoRoute(
            path: '/clinic',
            builder: (_, _) => const CaseloadScreen(),
            routes: [
              GoRoute(
                path: 'patients/:id',
                builder: (_, s) => PatientScreen(uid: s.pathParameters['id']!),
              ),
              GoRoute(
                path: 'requests',
                builder: (_, _) => const RequestsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
