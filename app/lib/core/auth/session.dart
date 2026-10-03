import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/eve/eve_controller.dart';
import '../api/api_client.dart';
import '../db/database.dart';
import '../ml/onnx_guardian.dart';
import '../settings/settings.dart';
import 'auth_providers.dart';

/// Sign-out found check-ins that could not be uploaded (usually no connection). Signing out now
/// would lose them, so the caller asks the person first.
class UnsentMoodException implements Exception {
  const UnsentMoodException(this.count);

  final int count;

  @override
  String toString() => 'UnsentMoodException($count)';
}

/// Ending a session on a phone that may be shared: whatever this person left on the device goes
/// with them, so the next account to sign in starts empty.
class SessionService {
  SessionService(this._ref);

  final Ref _ref;

  /// Uploads any mood points still queued, since the wipe would otherwise lose them, then wipes the
  /// local database and per-person prefs, signs out and removes the file. If the upload fails the
  /// phone is left untouched and [UnsentMoodException] says how many would be lost; the caller can
  /// retry or call again with [discardUnsent].
  Future<void> signOut({bool discardUnsent = false}) async {
    if (!discardUnsent) await _uploadPendingMood();
    await _endSession();
  }

  /// Deletes the account on the server (data and sign-in), then clears this phone the same way.
  /// If the server call fails nothing local is touched, so the person can retry. Queued mood
  /// points are not uploaded: the account they would go to is gone.
  ///
  /// The downloaded Guardian models go too: deleting an account should leave nothing of it behind.
  /// Sign-out keeps them, since they hold nothing personal and the next sign-in would download them again.
  Future<void> deleteAccount() async {
    await _ref.read(apiClientProvider).deleteMe();
    await _endSession();
    try {
      await _ref.read(modelFilesDeleterProvider)();
    } catch (e) {
      // The account and everything personal are already gone; a model file the OS won't let go
      // of is not worth failing the deletion over.
      debugPrint('could not delete model files: $e');
    }
    _ref.invalidate(guardianModelManagerProvider);
  }

  /// Removes every Eve conversation and memory note on this phone and opens a fresh thread. The
  /// memory switch is left as the person set it.
  Future<void> deleteAllEveData() async {
    await _ref.read(databaseProvider).deleteAllEveData();
    await _ref.read(settingsProvider.notifier).forgetConversation();
    _ref.invalidate(eveControllerProvider);
  }

  Future<void> _uploadPendingMood() async {
    // The web build (clinician console) has no local database to read.
    if (kIsWeb) return;
    final db = _ref.read(databaseProvider);
    final pending = await db.pendingMood();
    if (pending.isEmpty) return;
    try {
      await _ref.read(apiClientProvider).uploadMood([for (final p in pending) moodUploadOf(p)]);
    } catch (_) {
      throw UnsentMoodException(pending.length);
    }
    await db.markUploaded(pending.map((p) => p.id));
  }

  Future<void> _endSession() async {
    final name = databaseNameFor(_ref.read(currentUidProvider));
    // Rows go first, while the database is still open, so nothing survives even if the file
    // can't be removed (web, or the OS holding a lock).
    if (!kIsWeb) await _ref.read(databaseProvider).wipe();
    await _ref.read(settingsProvider.notifier).clearPersonal();
    // Eve's in-memory session (a pending crisis prompt, grounding and break offers) belonged to
    // this person. Invalidating reruns EveController.build, which resets its state.
    _ref.invalidate(eveControllerProvider);
    await _ref.read(authRepositoryProvider).signOut();
    await _ref.read(databaseDeleterProvider)(name);
  }
}

final sessionProvider = Provider<SessionService>(SessionService.new);

/// Removes the downloaded Guardian files. In v3, Eve runs server-side; only Guardian files live locally.
/// Tests swap in a recorder.
final modelFilesDeleterProvider = Provider<Future<void> Function()>((_) => _deleteModelFiles);

Future<void> _deleteModelFiles() async {
  if (kIsWeb) return;
  try {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/guardian');
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (e) {
    debugPrint('could not delete guardian model files: $e');
    rethrow;
  }
}
