import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:therapylink/app/theme/theme.dart';
import 'package:therapylink/core/auth/auth_providers.dart';
import 'package:therapylink/core/auth/auth_repository.dart';
import 'package:therapylink/features/auth/sign_in_screen.dart';
import 'package:therapylink/l10n/app_localizations.dart';
import 'package:therapylink/ui/components/buttons.dart';

/// Records what the screen asked for; [fail] makes the next call throw.
class _FakeAuth implements AuthRepository {
  final calls = <String>[];
  Object? fail;

  Future<UserCredential> _call(String what) async {
    calls.add(what);
    final f = fail;
    if (f != null) throw f;
    return _NoCredential();
  }

  @override
  Future<UserCredential> signInWithEmail(String email, String password) => _call('signIn:$email');
  @override
  Future<UserCredential> createWithEmail(String email, String password) => _call('create:$email');
  @override
  Future<UserCredential?> signInWithGoogle() => _call('google');
  @override
  Future<void> sendPasswordReset(String email) => _call('reset:$email');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NoCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<_FakeAuth> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final auth = _FakeAuth();
  await tester.pumpWidget(ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
    child: MaterialApp(
      theme: buildTheme(Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SignInScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _fill(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), password);
}

void main() {
  testWidgets('Sign in sends the email and password to Firebase', (tester) async {
    final auth = await _pump(tester);
    await _fill(tester, ' a@b.co ', 'secret');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['signIn:a@b.co']);
  });

  testWidgets('an empty email is caught before Firebase is asked', (tester) async {
    final auth = await _pump(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(auth.calls, isEmpty);
    expect(find.text('Enter your email'), findsOneWidget);
  });

  testWidgets('a wrong password shows a plain message', (tester) async {
    final auth = await _pump(tester);
    auth.fail = FirebaseAuthException(code: 'invalid-credential');
    await _fill(tester, 'a@b.co', 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text("That email and password don't match."), findsOneWidget);
  });

  testWidgets('Create an account switches the form and creates the account', (tester) async {
    final auth = await _pump(tester);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await _fill(tester, 'a@b.co', 'short');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(auth.calls, isEmpty, reason: 'a password under 8 characters is refused locally');

    await _fill(tester, 'a@b.co', 'long enough');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    expect(auth.calls, ['create:a@b.co']);
  });

  testWidgets('Google and password reset reach the auth repository', (tester) async {
    final auth = await _pump(tester);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Type your email above first, then tap this again.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(auth.calls, ['google', 'reset:a@b.co']);
    expect(find.text('Reset email sent.'), findsOneWidget);
  });
}
