import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'api_client.dart';
import 'models.dart';

/// The server's view of the signed-in user. Null while signed out.
final meProvider = FutureProvider<Me?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(apiClientProvider).me();
});
