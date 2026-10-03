import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../settings/settings.dart';
import 'api_client.dart';

/// Tells the server which consent version this person accepted. Consent is given on the phone
/// before any account exists, so it is sent whenever someone is signed in with a current consent:
/// on sign-in, on launch, and right after a new version is accepted. Sign-out clears the phone's
/// consent, so what is sent is always the consent of the person now signed in, never a previous
/// user's. The PUT is idempotent, and a failure is simply retried on the next of those.
final consentSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  final settings = ref.watch(settingsProvider.select((s) => s.consented ? (version: s.consentVersion, acceptedAt: s.consentAcceptedAt) : null));
  if (uid == null || settings == null || settings.version == null || settings.acceptedAt == null) return;
  ref
      .read(apiClientProvider)
      .putConsent(version: settings.version!, acceptedAt: settings.acceptedAt!)
      .catchError((Object e) => debugPrint('consent sync deferred: $e'));
});
