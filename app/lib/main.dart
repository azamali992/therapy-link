import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'firebase_options.dart';

// ---------------------------------------------------------------------------
// Release URL guard (mirrors the Gradle-side check in build.gradle.kts).
// Compile the URL in with --dart-define=TL_API_URL=https://...
// ---------------------------------------------------------------------------

/// The API base URL injected at build time. Empty string in debug when no
/// dart-define is provided — the API client (core team) must not use it blank.
const String _apiBaseUrl = String.fromEnvironment('TL_API_URL');

/// Returns a human-readable problem string if [url] is absent or unsafe for a
/// release build, or null if [url] looks fine.
@visibleForTesting
String? releaseUrlProblem(String url) {
  if (url.isEmpty) return 'TL_API_URL dart-define is not set';
  const bad = ['http://', 'localhost', '127.0.0.1', '0.0.0.0',
      'placeholder', 'example.com', 'trycloudflare.com'];
  final hit = bad.firstWhere(
    (b) => url.contains(b),
    orElse: () => '',
  );
  return hit.isEmpty ? null : 'TL_API_URL looks wrong (contains "$hit")';
}

Future<void> main() async {
  // A plain assert is compiled out of release builds, which are the only ones
  // this guards. The Gradle build rejects the same URLs before signing; this
  // catches every other platform and future CI pipelines.
  if (kReleaseMode) {
    final problem = releaseUrlProblem(_apiBaseUrl);
    if (problem != null) {
      throw StateError(
          '$problem. Build with --dart-define=TL_API_URL=https://your-api.example.');
    }
  }

  WidgetsFlutterBinding.ensureInitialized();

  // Firebase: public client keys only; no service-account credentials here.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    const ProviderScope(
      child: TherapyLinkApp(),
    ),
  );
}
