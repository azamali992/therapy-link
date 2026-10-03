import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository(FirebaseAuth.instance));

final authStateProvider = StreamProvider<User?>((ref) => ref.watch(authRepositoryProvider).authState);

final isSignedInProvider = Provider<bool>((ref) => ref.watch(authStateProvider).value != null);

/// The signed-in Firebase uid, or null. Changes only when the account does, not on token refresh.
final currentUidProvider = Provider<String?>((ref) => ref.watch(authStateProvider.select((a) => a.value?.uid)));
