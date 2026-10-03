/// /sign-in — email/password and Google sign-in.
///
/// Behaviour is wired by the core team (Firebase Auth). This file owns the
/// Jugnu-styled UI layout only. Every redirect and consent check stays in
/// router.dart; no navigation logic lives here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _signIn() {
    // TODO(core-team): call firebase_auth signInWithEmailAndPassword.
  }

  void _signInGoogle() {
    // TODO(core-team): call google_sign_in then signInWithCredential.
  }

  void _createAccount() {
    // TODO(core-team): navigate to create-account or show the sign-up form.
    context.go('/welcome');
  }

  void _forgotPassword() {
    // TODO(core-team): show password-reset sheet or navigate.
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final colors = Theme.of(context).extension<JugnuColors>()!;

    return JugnuScaffold(
      appBar: JugnuAppBar(
        title: Text(l.signInTitle),
        onGetHelp: () => showCrisisSheet(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            Jugnu.s20, Jugnu.s8, Jugnu.s20, Jugnu.s48),
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
            ),
            const SizedBox(height: Jugnu.s12),

            // Password field
            TextField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: l.password,
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
              onSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: Jugnu.s8),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                child: Text(l.forgotPassword),
              ),
            ),
            const SizedBox(height: Jugnu.s16),

            // Primary: sign in
            PrimaryButton(label: l.signIn, onPressed: _signIn),
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
                  child: Text('or',
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
            GhostButton(label: l.continueWithGoogle, onPressed: _signInGoogle),
            const SizedBox(height: Jugnu.s24),

            // Create account
            Center(
              child: TextButton(
                onPressed: _createAccount,
                child: Text(l.noAccount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
