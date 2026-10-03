import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:sqlite3/sqlite3.dart';

import 'database_notice.dart';

// Everything here that touches the key keeps it out of logs and exception text: SqliteException's
// toString includes the statement that failed, and PRAGMA key carries the key, so every SQLite
// error on a keyed path is replaced by one that names only the step and the result code.

/// The first 16 bytes of every unencrypted SQLite file. A SQLCipher file starts with random salt.
const _plaintextHeader = 'SQLite format 3\u0000';

/// Opening would have needed SQLCipher but the linked SQLite is plain. The build is wrong, and
/// nothing is written rather than writing it unencrypted.
class CipherUnavailableException implements Exception {
  const CipherUnavailableException();

  @override
  String toString() => 'CipherUnavailableException: SQLCipher is not linked; refusing to open the database unencrypted';
}

/// The key did not open the file: a different key, or not a database at all.
class WrongDatabaseKeyException implements Exception {
  const WrongDatabaseKeyException();

  @override
  String toString() => 'WrongDatabaseKeyException: the database could not be read with this key';
}

/// A step of opening or encrypting failed. Says which, never with the SQL.
class DatabaseEncryptionException implements Exception {
  const DatabaseEncryptionException(this.step, [this.resultCode]);

  final String step;
  final int? resultCode;

  @override
  String toString() => 'DatabaseEncryptionException: $step failed${resultCode == null ? '' : ' (SQLite code $resultCode)'}';
}

final _hex64 = RegExp(r'^[0-9a-f]{64}$');

T _step<T>(String step, T Function() run) {
  try {
    return run();
  } on SqliteException catch (e) {
    throw DatabaseEncryptionException(step, e.resultCode);
  }
}

/// Keys [db] and checks it. PRAGMA key must be the first statement on a new connection; nothing,
/// not even a read of the schema, may run before it.
///
/// Then PRAGMA cipher_version proves the linked library is SQLCipher (on plain SQLite PRAGMA key
/// is silently ignored, which would leave the file in the clear), and reading the schema proves
/// the key opens this file.
void applyDatabaseKey(Database db, String hexKey) {
  // Checked so the key can go into the statement as a literal: it can only be 64 hex digits.
  if (!_hex64.hasMatch(hexKey)) throw ArgumentError('the database key must be 32 bytes as hex');
  _step('PRAGMA key', () => db.execute('PRAGMA key = "x\'$hexKey\'"'));
  final version = _step('PRAGMA cipher_version', () => db.select('PRAGMA cipher_version'));
  if (version.isEmpty || '${version.first.columnAt(0) ?? ''}'.isEmpty) throw const CipherUnavailableException();
  try {
    db.select('SELECT count(*) FROM sqlite_master');
  } on SqliteException {
    throw const WrongDatabaseKeyException();
  }
}

enum DatabaseFileKind { missing, plaintext, encrypted }

/// What is at [path], read from the header alone.
Future<DatabaseFileKind> databaseFileKind(String path) async {
  final file = File(path);
  if (!await file.exists()) return DatabaseFileKind.missing;
  final raf = await file.open();
  try {
    final head = await raf.read(16);
    // An empty file (created and never written) is opened as a new database, so encrypted.
    if (head.isEmpty) return DatabaseFileKind.encrypted;
    return String.fromCharCodes(head) == _plaintextHeader ? DatabaseFileKind.plaintext : DatabaseFileKind.encrypted;
  } finally {
    await raf.close();
  }
}

/// Encrypts the plaintext database at [path] in place, once.
///
/// sqlcipher_export copies it into a new keyed file next to it; the copy is reopened with the key
/// and every table's row count compared with the original. Only then is the original moved aside,
/// the copy moved into its place, and the original deleted. Any failure removes the half-made copy
/// and leaves the original where it was, so nothing is lost; the caller keeps using it and tries
/// again next time.
///
/// Deleting a file on flash storage does not overwrite its blocks. What protects them is the
/// device's own file encryption; this makes sure the app's copy from now on is encrypted too.
///
/// Synchronous and blocking: callers run it on another isolate.
void migratePlaintextDatabase(String path, String hexKey) {
  final copy = '$path.encrypting';
  final original = '$path.plaintext';
  _deleteQuietly(copy);

  final counts = <String, int>{};
  final source = _step('open plaintext', () => sqlite3.open(path));
  try {
    final version = _step('PRAGMA cipher_version', () => source.select('PRAGMA cipher_version'));
    if (version.isEmpty) throw const CipherUnavailableException();
    final userVersion = source.userVersion;
    for (final row in source.select("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")) {
      final table = row.columnAt(0) as String;
      counts[table] = source.select('SELECT count(*) FROM "${table.replaceAll('"', '""')}"').first.columnAt(0) as int;
    }
    // Both bound, never spliced: the path is the OS's and the key must not appear in any SQL text.
    _step('attach', () => source.execute('ATTACH DATABASE ? AS encrypted KEY ?', [copy, "x'$hexKey'"]));
    _step('sqlcipher_export', () => source.select("SELECT sqlcipher_export('encrypted')"));
    // sqlcipher_export copies the schema and rows, not the version drift migrates from.
    _step('copy user_version', () => source.execute('PRAGMA encrypted.user_version = $userVersion'));
    _step('detach', () => source.execute('DETACH DATABASE encrypted'));
  } catch (_) {
    source.close();
    _deleteQuietly(copy);
    rethrow;
  }
  source.close();

  try {
    _verifyCopy(copy, hexKey, counts);
  } catch (_) {
    _deleteQuietly(copy);
    rethrow;
  }

  File(path).renameSync(original);
  try {
    File(copy).renameSync(path);
  } catch (_) {
    File(original).renameSync(path);
    _deleteQuietly(copy);
    rethrow;
  }
  // The plaintext connection was closed cleanly, so any journal or WAL beside the path is stale
  // and would otherwise be read against the new file.
  for (final suffix in const ['-wal', '-shm', '-journal']) {
    _deleteQuietly('$path$suffix');
  }
  _deleteQuietly(original);
}

void _verifyCopy(String copy, String hexKey, Map<String, int> expected) {
  final db = _step('open copy', () => sqlite3.open(copy));
  try {
    applyDatabaseKey(db, hexKey);
    for (final MapEntry(key: table, value: rows) in expected.entries) {
      final got = _step('count copy', () => db.select('SELECT count(*) FROM "${table.replaceAll('"', '""')}"').first.columnAt(0) as int);
      if (got != rows) throw DatabaseEncryptionException('verify $table');
    }
  } finally {
    db.close();
  }
}

/// Opens the file at [path] with [hexKey] and closes it again, so a wrong key is found before
/// drift starts and not as a failure on every later query.
void probeEncryptedDatabase(String path, String hexKey) {
  final db = _step('open', () => sqlite3.open(path));
  try {
    applyDatabaseKey(db, hexKey);
  } finally {
    db.close();
  }
}

void _deleteQuietly(String path) {
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (e) {
    debugPrint('could not delete a database file: ${e.runtimeType}');
  }
}

// Closures sent to another isolate carry every variable their enclosing function captured, so
// they are built here, where the only things in scope are the ones they need. Made inside the
// functions below they would drag along the notice callback and, through it, the provider graph.
void Function() _job(void Function(String path, String hexKey) work, String path, String hexKey) => () => work(path, hexKey);

DatabaseSetup _keySetup(String hexKey) => (db) => applyDatabaseKey(db, hexKey);

/// How the file at a path should be opened, after any one-time work on it.
class PreparedDatabase {
  const PreparedDatabase({required this.encrypted, this.notice});

  /// False only when a plaintext file could not be encrypted and is opened as it is.
  final bool encrypted;
  final DatabaseNotice? notice;
}

/// Runs the synchronous SQLite work above off the UI isolate. Tests pass one that runs inline.
typedef DatabaseWorker = Future<void> Function(void Function() work);

Future<void> _onAnotherIsolate(void Function() work) => Isolate.run(work);

/// Gets the file at [path] ready to be opened with [hexKey]:
/// - nothing there: a new encrypted file will be created;
/// - a plaintext file from an earlier build: encrypted in place, once; if that fails the file is
///   kept and opened unencrypted, and [DatabaseNotice.migrationFailed] says so;
/// - an encrypted file the key does not open: moved aside (kept, never deleted here) and a new file
///   started, with [DatabaseNotice.unreadable].
@visibleForTesting
Future<PreparedDatabase> prepareDatabaseFile(
  String path,
  String hexKey, {
  DatabaseWorker worker = _onAnotherIsolate,
  void Function(String path, String hexKey) migrate = migratePlaintextDatabase,
}) async {
  // A crash between the two renames of a migration leaves the original beside an empty path. Put
  // it back; it is then migrated again from the start.
  final original = File('$path.plaintext');
  if (!await File(path).exists() && await original.exists()) await original.rename(path);

  switch (await databaseFileKind(path)) {
    case DatabaseFileKind.missing:
      return const PreparedDatabase(encrypted: true);
    case DatabaseFileKind.plaintext:
      try {
        await worker(_job(migrate, path, hexKey));
        return const PreparedDatabase(encrypted: true);
      } catch (e) {
        debugPrint('database encryption failed: $e');
        return const PreparedDatabase(encrypted: false, notice: DatabaseNotice.migrationFailed);
      }
    case DatabaseFileKind.encrypted:
      // A leftover from a migration that stopped after the swap: the plaintext is already copied.
      if (await original.exists()) await original.delete();
      try {
        await worker(_job(probeEncryptedDatabase, path, hexKey));
        return const PreparedDatabase(encrypted: true);
      } on WrongDatabaseKeyException {
        final aside = '$path.unreadable-${DateTime.now().millisecondsSinceEpoch}';
        await File(path).rename(aside);
        for (final suffix in const ['-wal', '-shm', '-journal']) {
          final f = File('$path$suffix');
          if (await f.exists()) await f.rename('$aside$suffix');
        }
        return const PreparedDatabase(encrypted: true, notice: DatabaseNotice.unreadable);
      }
  }
}

/// The executor for an encrypted database at [path]. The key and any migration are resolved
/// lazily, on first query, so opening stays synchronous for the provider that asks for it.
///
/// If the key store is temporarily unavailable the first open fails. [ReopeningExecutor] retries
/// on every subsequent query. [onNotice] is called with [DatabaseNotice.openFailed] once at the
/// start of a run of failures, not once per failing query.
QueryExecutor openEncryptedDatabase({
  required Future<String> Function() path,
  required Future<String> Function() key,
  required void Function(DatabaseNotice notice) onNotice,
}) {
  var notifiedFailure = false;
  return ReopeningExecutor(
    () async {
      final file = await path();
      final hexKey = await key();
      final prepared = await prepareDatabaseFile(file, hexKey);
      if (prepared.notice case final notice?) onNotice(notice);
      // On success, reset the "already notified" flag so a future failure run re-notifies.
      notifiedFailure = false;
      return NativeDatabase.createBackgroundConnection(
        File(file),
        // Runs on the drift isolate before anything else touches the connection.
        setup: prepared.encrypted ? _keySetup(hexKey) : null,
      );
    },
    onFailure: (_) {
      if (!notifiedFailure) {
        notifiedFailure = true;
        onNotice(DatabaseNotice.openFailed);
      }
    },
  );
}

/// A [QueryExecutor] that reopens its backing database whenever the previous open attempt failed.
///
/// Drift opens the backing [NativeDatabase] lazily: the [setup] callback runs the first time a
/// query is issued. If [setup] throws (e.g. the key store flickers during the drift isolate's
/// start-up), drift surfaces that error on the first query, leaving the executor in a broken state.
/// [ReopeningExecutor] catches that and discards the bad inner executor so the next query calls
/// [factory] again and gets a fresh connection. The [onFailure] callback receives every such error.
///
/// This is [visibleForTesting] because production code uses [openEncryptedDatabase], which handles
/// its own retry logic at a higher level. Tests use [ReopeningExecutor] to exercise the low-level
/// path where the drift isolate's setup callback itself throws.
@visibleForTesting
class ReopeningExecutor extends QueryExecutor {
  ReopeningExecutor(this._factory, {required this.onFailure});

  final Future<QueryExecutor> Function() _factory;
  final void Function(Object) onFailure;

  QueryExecutor? _delegate;
  Completer<QueryExecutor>? _opening;

  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  Future<QueryExecutor> _acquire() {
    final cached = _delegate;
    if (cached != null) return Future.value(cached);
    final pending = _opening;
    if (pending != null) return pending.future;
    final c = _opening = Completer<QueryExecutor>();
    _factory().then((e) {
      _opening = null;
      _delegate = e;
      c.complete(e);
    }, onError: (Object e, StackTrace s) {
      _opening = null;
      c.completeError(e, s);
    });
    return c.future;
  }

  void _reset(Object error) {
    _delegate = null;
    _opening = null;
    onFailure(error);
  }

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    try {
      return await (await _acquire()).ensureOpen(user);
    } catch (e) {
      _reset(e);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) =>
      _delegate!.runSelect(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _delegate!.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _delegate!.runUpdate(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _delegate!.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _delegate!.runCustom(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _delegate!.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => _delegate!.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _delegate!.beginExclusive();

  @override
  Future<void> close() async => _delegate?.close();
}

/// Removes the file at [path] and everything beside it that shares its name: journals, a copy left
/// by an interrupted migration, files moved aside as unreadable.
Future<void> deleteDatabaseFiles(String path) async {
  final file = File(path);
  final dir = file.parent;
  if (!await dir.exists()) return;
  final name = file.uri.pathSegments.last;
  await for (final entry in dir.list(followLinks: false)) {
    if (entry is! File) continue;
    final entryName = entry.uri.pathSegments.last;
    if (entryName != name && !entryName.startsWith('$name-') && !entryName.startsWith('$name.')) continue;
    try {
      await entry.delete();
    } catch (e) {
      debugPrint('could not delete $entryName: $e');
    }
  }
}
