import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../shared/widgets.dart';

/// /sign-in — email/password and Google sign-in.
///
/// TODO(core-team): wire form submission to firebase_auth and google_sign_in.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Screen(
      title: l.signInTitle,
      quickExit: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Tokens.s24),
          Text(l.signInSubtitle,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Tokens.s24),
          TextFormField(
            decoration: InputDecoration(labelText: l.email),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: Tokens.s12),
          TextFormField(
            decoration: InputDecoration(labelText: l.password),
            obscureText: true,
          ),
          const SizedBox(height: Tokens.s24),
          FilledButton(
            onPressed: () {
              // TODO(core-team): call signInWithEmailAndPassword.
            },
            child: Text(l.signIn),
          ),
          const SizedBox(height: Tokens.s12),
          OutlinedButton.icon(
            icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
            label: Text(l.continueWithGoogle),
            onPressed: () {
              // TODO(core-team): call signInWithGoogle.
            },
          ),
          const SizedBox(height: Tokens.s24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                  onPressed: () {},
                  child: Text(l.noAccount)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                  onPressed: () {},
                  child: Text(l.forgotPassword)),
            ],
          ),
        ],
      ),
    );
  }
}
