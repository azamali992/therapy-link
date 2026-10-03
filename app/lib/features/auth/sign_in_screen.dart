/// /sign-in — email/password and Google sign-in.
///
/// One form for both signing in and creating an account. A successful sign-in changes the
/// auth state and router.dart moves on from there; no navigation logic lives here.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/theme/tokens.dart';
import '../../core/auth/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/components/buttons.dart';
import '../../ui/components/jugnu_app_bar.dart';
import '../../ui/components/jugnu_scaffold.dart';
import '../shared/crisis_sheet.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _creating = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Runs one auth call at a time and turns its failure into a message the person can act on.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    String? error;
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      error = _messageFor(l, e.code);
    } on GoogleSignInException catch (e) {
      debugPrint('google sign-in failed: ${e.code}');
      error = l.authErrorGoogle;
    } catch (e) {
      debugPrint('sign-in failed: ${e.runtimeType}');
      error = l.authErrorGeneric;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  static String _messageFor(AppLocalizations l, String code) => switch (code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' || 'INVALID_LOGIN_CREDENTIALS' =>
          l.authErrorMismatch,
        'email-already-in-use' => l.authErrorInUse,
        'weak-password' => l.authErrorWeakPassword,
        'invalid-email' || 'missing-email' => l.authErrorInvalidEmail,
        'too-many-requests' => l.authErrorTooMany,
        'network-request-failed' => l.authErrorNetwork,
        _ => l.authErrorGeneric,
      };

  void _submit() {
    final l = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty) return setState(() => _error = l.validateEmail);
    if (_creating ? password.length < 8 : password.isEmpty) {
      return setState(() => _error = l.validatePassword);
    }
    final auth = ref.read(authRepositoryProvider);
    _run(() => _creating ? auth.createWithEmail(email, password) : auth.signInWithEmail(email, password));
  }

  void _signInGoogle() => _run(() => ref.read(authRepositoryProvider).signInWithGoogle());

  void _toggleMode() => setState(() {
        _creating = !_creating;
        _error = null;
        _notice = null;
      });

  void _forgotPassword() {
    final l = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return setState(() => _error = l.resetNeedsEmail);
    _run(() async {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      _notice = l.resetSent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;
    final message = _error ?? _notice;

    return JugnuScaffold(
      appBar: JugnuAppBar(
        title: Text(_creating ? l.createAccount : l.signInTitle),
        onGetHelp: () => showCrisisSheet(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            Jugnu.s20, Jugnu.s8, Jugnu.s20, Jugnu.s48),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtitle
              Text(
                l.signInSubtitle,
                style: t.bodyLarge?.copyWith(color: colors.ink2),
              ),
              const SizedBox(height: Jugnu.s24),

              // Email field
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(labelText: l.email),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: Jugnu.s12),

              // Password field
              TextField(
                controller: _passwordCtrl,
                decoration: InputDecoration(
                  labelText: l.password,
                  helperText: _creating ? l.validatePassword : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: colors.ink3,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                  ),
                ),
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: [_creating ? AutofillHints.newPassword : AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Jugnu.s8),

              // Forgot password
              if (!_creating)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    child: Text(l.forgotPassword),
                  ),
                ),

              // What went wrong, or that the reset email went out. Read out when it appears.
              if (message != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: Jugnu.s8),
                    child: Text(
                      message,
                      style: t.bodyMedium?.copyWith(
                          color: _error != null ? Theme.of(context).colorScheme.error : colors.safeText),
                    ),
                  ),
                ),
              const SizedBox(height: Jugnu.s16),

              // Primary: sign in, or create the account
              if (_busy) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: Jugnu.s8),
              ],
              PrimaryButton(
                label: _creating ? l.createAccount : l.signIn,
                onPressed: _busy ? () {} : _submit,
              ),
              const SizedBox(height: Jugnu.s12),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                        color: colors.hair, height: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Jugnu.s12),
                    child: Text(l.signInOr,
                        style: t.bodySmall?.copyWith(color: colors.ink3)),
                  ),
                  Expanded(
                    child: Divider(
                        color: colors.hair, height: 1),
                  ),
                ],
              ),
              const SizedBox(height: Jugnu.s12),

              // Google sign-in
              GhostButton(label: l.continueWithGoogle, onPressed: _busy ? () {} : _signInGoogle),
              const SizedBox(height: Jugnu.s24),

              // Switch between signing in and creating an account
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _toggleMode,
                  child: Text(_creating ? l.haveAccount : l.noAccount),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
