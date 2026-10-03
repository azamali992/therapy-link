import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/clinician/caseload_screen.dart';
import '../features/clinician/patient_screen.dart';
import '../features/clinician/requests_screen.dart';
import '../features/eve/conversations_screen.dart';
import '../features/eve/eve_screen.dart';
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

// ---------------------------------------------------------------------------
// Stub providers — TODO(core-team): replace with real implementations in
// lib/core/auth/ and lib/core/settings/. These stubs keep the app and tests
// runnable before the core layer is wired in.
// ---------------------------------------------------------------------------

/// Authentication state. Resolves to null (not signed in) until the real
/// Firebase auth stream is wired. Replace with authStateProvider from core.
/// TODO(core-team): wire to `firebase_auth.FirebaseAuth.instance.authStateChanges()`.
final authStateStubProvider = Provider<AsyncValue<Object?>>(
  (ref) => const AsyncValue.data(null),
);

/// Whether the current consent version has been accepted.
/// TODO(core-team): wire to the settings / consent-sync provider.
final consentedStubProvider = Provider<bool>((ref) => false);

/// Whether the device has completed onboarding (shown the welcome screen).
/// TODO(core-team): wire to the settings provider (shared_preferences).
final onboardedStubProvider = Provider<bool>((ref) => false);

/// User role. True when the signed-in user is a clinician.
/// TODO(core-team): wire to `meProvider` from lib/core/api/me_provider.dart.
final isClinicianStubProvider = Provider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateStubProvider, (_, _) => notifyListeners());
    _ref.listen(consentedStubProvider, (_, _) => notifyListeners());
    _ref.listen(onboardedStubProvider, (_, _) => notifyListeners());
    _ref.listen(isClinicianStubProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    return routeRedirect(
      state.uri,
      consented: _ref.read(consentedStubProvider),
      onboarded: _ref.read(onboardedStubProvider),
      auth: _ref.read(authStateStubProvider),
      isClinician: _ref.read(isClinicianStubProvider),
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
  required bool isClinician,
}) {
  final path = uri.path;

  // Nothing opens until the current consent version is accepted.
  if (!consented) {
    if (path == '/welcome' || path == '/consent') return null;
    return onboarded ? '/consent' : '/welcome';
  }

  if (auth.isLoading) return null;
  final signedIn = auth.value != null;
  final onAuthPages =
      path == '/welcome' || path == '/sign-in' || path == '/consent';

  if (!signedIn) {
    if (path == '/welcome' || path == '/sign-in') return null;
    return onboarded ? '/sign-in' : '/welcome';
  }

  if (onAuthPages || path == '/') {
    return isClinician ? '/clinic' : '/eve';
  }

  if (isClinician && !path.startsWith('/clinic')) return '/clinic';
  if (!isClinician && path.startsWith('/clinic')) return '/eve';

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
                    path: 'assess/:id',
                    builder: (_, s) =>
                        AssessmentScreen(id: s.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'exercises/:id',
                    builder: (_, s) =>
                        ExercisesScreen(id: s.pathParameters['id']),
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
                    builder: (_, s) =>
                        JournalEditorScreen(prompt: s.extra as String?),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => JournalEditorScreen(
                        entryId: s.pathParameters['id']),
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
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'memory',
                    builder: (_, _) => const MemoryScreen(),
                  ),
                  GoRoute(
                    path: 'access-log',
                    builder: (_, _) => const AccessLogScreen(),
                  ),
                  GoRoute(
                    path: 'care',
                    builder: (_, _) => const CareScreen(),
                  ),
                  GoRoute(
                    path: 'clinician',
                    builder: (_, _) => const ClinicianJoinScreen(),
                  ),
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
                builder: (_, s) =>
                    PatientScreen(uid: s.pathParameters['id']!),
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
