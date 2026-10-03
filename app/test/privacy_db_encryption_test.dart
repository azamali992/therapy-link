import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/core/db/database_notice.dart';
import 'package:therapylink/core/db/encrypted_database_native.dart';
import 'package:therapylink/core/security/database_key.dart';
import 'package:therapylink/core/security/secret_store.dart';

// These run against real SQLCipher: pubspec.yaml selects package:sqlite3's SQLCipher build for
// every platform, the test VM included. What they cannot cover is the phone itself: the Android
// Keystore and iOS Keychain behind flutter_secure_storage (a map stands in for them here), and
// the Android and iOS SQLCipher binaries, which only a device build links. The first test proves
// the library under test really is SQLCipher, so a build that fell back to plain SQLite fails
// here instead of passing with nothing encrypted.

class _MapSecrets implements SecretStore {
  final values = <String, String>{};
  int writes = 0;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
}

String _key(int seed) {
  final r = Random(seed);
  return [for (var i = 0; i < 32; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}

Future<void> _inline(void Function() work) async => work();

MessagesCompanion _message(String id, String text) =>
    MessagesCompanion.insert(id: id, conversationId: 'c1', role: 'user', content: text, createdAt: DateTime(2026, 9, 1));

/// Writes a database the way builds before encryption did: plain SQLite, no key.
Future<void> _writePlaintext(String path, List<String> texts) async {
  final db = AppDatabase(NativeDatabase(File(path)));
  await db.upsertConversation('c1');
  for (var i = 0; i < texts.length; i++) {
    await db.addMessage(_message('m$i', texts[i]));
  }
  await db.close();
}

Future<List<String>> _readWithKey(String path, String key) async {
  final db = AppDatabase(NativeDatabase(File(path), setup: (d) => applyDatabaseKey(d, key)));
  try {
    return [for (final m in await db.recentMessages('c1', limit: 100)) m.content];
  } finally {
    await db.close();
  }
}

bool _hasPlaintextHeader(String path) => String.fromCharCodes(File(path).readAsBytesSync().take(15)) == 'SQLite format 3';

bool _fileContains(String path, String text) => String.fromCharCodes(File(path).readAsBytesSync()).contains(text);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('tl_privacy_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the SQLite the app links is SQLCipher', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    expect('${db.select('PRAGMA cipher_version').first.columnAt(0)}', isNotEmpty);
  });

  group('database key', () {
    late _MapSecrets secrets;
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secrets = _MapSecrets();
    });

    test('is 32 random bytes, created once and reused, also by a new store after a restart', () async {
      final first = await DatabaseKeyStore(secrets, prefs).keyFor('therapylink_u1');
      expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
      final again = await DatabaseKeyStore(secrets, prefs).keyFor('therapylink_u1');
      expect(again, first);
      expect(secrets.writes, 1);
      // Nothing about the key goes to plain prefs.
      expect(prefs.getKeys().map(prefs.get), isNot(contains(first)));
    });

    test('two opens racing on a fresh install share one key', () async {
      final store = DatabaseKeyStore(secrets, prefs);
      final keys = await Future.wait([store.keyFor('therapylink_u1'), store.keyFor('therapylink_u1')]);
      expect(keys[0], keys[1]);
      expect(secrets.writes, 1);
    });

    test('each account on the phone gets its own key', () async {
      final store = DatabaseKeyStore(secrets, prefs);
      expect(await store.keyFor('therapylink_u1'), isNot(await store.keyFor('therapylink_u2')));
    });

    test('a new install does not reuse a key an old install left in the Keychain', () async {
      final old = await DatabaseKeyStore(secrets, prefs).keyFor('therapylink_u1');
      // Reinstalling clears prefs; on iOS the Keychain entry survives.
      SharedPreferences.setMockInitialValues({});
      final fresh = await DatabaseKeyStore(secrets, await SharedPreferences.getInstance()).keyFor('therapylink_u1');
      expect(fresh, isNot(old));
      expect(secrets.values.values, isNot(contains(old)));
    });

    test('forget removes it, and the next open makes a new one', () async {
      final store = DatabaseKeyStore(secrets, prefs);
      final first = await store.keyFor('therapylink_u1');
      await store.forget('therapylink_u1');
      expect(secrets.values.values, isNot(contains(first)));
      expect(await store.keyFor('therapylink_u1'), isNot(first));
    });
  });

  group('encrypted file', () {
    test('holds nothing readable, and opens only with its key', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      final key = _key(1);
      final db = AppDatabase(openEncryptedDatabase(path: () async => path, key: () async => key, onNotice: (_) {}));
      await db.upsertConversation('c1');
      await db.addMessage(_message('m1', 'my husband shouts at me'));
      await db.close();

      expect(_hasPlaintextHeader(path), isFalse);
      expect(_fileContains(path, 'husband'), isFalse);
      expect(await _readWithKey(path, key), ['my husband shouts at me']);
    });

    test('a wrong key fails to open', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      final db = AppDatabase(openEncryptedDatabase(path: () async => path, key: () async => _key(1), onNotice: (_) {}));
      await db.upsertConversation('c1');
      await db.close();

      expect(() => probeEncryptedDatabase(path, _key(2)), throwsA(isA<WrongDatabaseKeyException>()));
      expect(_readWithKey(path, _key(2)), throwsA(anything));
    });

    test('errors never carry the key', () {
      final path = '${dir.path}/therapylink_u1.sqlite';
      File(path).writeAsBytesSync(List.filled(4096, 7));
      final key = _key(3);
      try {
        probeEncryptedDatabase(path, key);
        fail('should not open');
      } catch (e) {
        expect('$e', isNot(contains(key)));
      }
    });
  });

  group('plaintext file from an earlier build', () {
    test('is encrypted once, keeping every message, and the plaintext is gone', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      await _writePlaintext(path, ['first', 'second secret']);
      expect(_hasPlaintextHeader(path), isTrue);

      final prepared = await prepareDatabaseFile(path, _key(1), worker: _inline);
      expect(prepared.encrypted, isTrue);
      expect(prepared.notice, isNull);
      expect(_hasPlaintextHeader(path), isFalse);
      expect(_fileContains(path, 'second secret'), isFalse);
      expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['therapylink_u1.sqlite']);
      expect(await _readWithKey(path, _key(1)), ['first', 'second secret']);

      // Once: the next open only checks the key.
      final again = await prepareDatabaseFile(path, _key(1), worker: _inline);
      expect(again.encrypted, isTrue);
      expect(await _readWithKey(path, _key(1)), ['first', 'second secret']);
    });

    test('keeps the schema version, so drift does not migrate it again', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      await _writePlaintext(path, ['x']);
      await prepareDatabaseFile(path, _key(1), worker: _inline);
      final db = sqlite3.open(path);
      addTearDown(db.close);
      applyDatabaseKey(db, _key(1));
      expect(db.userVersion, 2);
    });

    test('runs on a background isolate from the real opener', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      await _writePlaintext(path, ['hello']);
      // The notice callback holds something that can't cross isolates, as the real one (holding
      // the provider graph) does. The migration and the key setup must not drag it along.
      final port = ReceivePort();
      addTearDown(port.close);
      final notices = <DatabaseNotice>[];
      final db = AppDatabase(openEncryptedDatabase(
        path: () async => path,
        key: () async => _key(1),
        onNotice: (n) {
          port.sendPort;
          notices.add(n);
        },
      ));
      expect([for (final m in await db.recentMessages('c1')) m.content], ['hello']);
      await db.close();
      expect(notices, isEmpty);
      expect(_hasPlaintextHeader(path), isFalse);
    });

    test('if encrypting fails the person is told and the file is kept and still opens', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      await _writePlaintext(path, ['keep me']);
      final before = File(path).readAsBytesSync();
      // A directory where the encrypted copy would go makes the real migration fail midway.
      Directory('$path.encrypting').createSync();

      final notices = <DatabaseNotice>[];
      final db = AppDatabase(openEncryptedDatabase(path: () async => path, key: () async => _key(1), onNotice: notices.add));
      expect([for (final m in await db.recentMessages('c1')) m.content], ['keep me']);
      await db.close();

      expect(notices, [DatabaseNotice.migrationFailed]);
      expect(_hasPlaintextHeader(path), isTrue);
      expect(File(path).lengthSync(), greaterThanOrEqualTo(before.length));
    });

    test('a failing migration leaves the original byte for byte and no half-made copy', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      await _writePlaintext(path, ['keep me']);
      final before = File(path).readAsBytesSync();

      final prepared = await prepareDatabaseFile(path, _key(1), worker: _inline, migrate: (_, _) => throw const FileSystemException('disk full'));
      expect(prepared.encrypted, isFalse);
      expect(prepared.notice, DatabaseNotice.migrationFailed);
      expect(File(path).readAsBytesSync(), before);
      expect(File('$path.encrypting').existsSync(), isFalse);
    });

    test('a migration cut off between its two renames is put back and finished', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      await _writePlaintext(path, ['survived']);
      File(path).renameSync('$path.plaintext');

      final prepared = await prepareDatabaseFile(path, _key(1), worker: _inline);
      expect(prepared.encrypted, isTrue);
      expect(File('$path.plaintext').existsSync(), isFalse);
      expect(await _readWithKey(path, _key(1)), ['survived']);
    });
  });

  test('a file the key cannot open is moved aside, never deleted, and the person is told', () async {
    final path = '${dir.path}/therapylink_u1.sqlite';
    final db = AppDatabase(openEncryptedDatabase(path: () async => path, key: () async => _key(1), onNotice: (_) {}));
    await db.upsertConversation('c1');
    await db.close();
    final bytes = File(path).readAsBytesSync();

    final prepared = await prepareDatabaseFile(path, _key(2), worker: _inline);
    expect(prepared.notice, DatabaseNotice.unreadable);
    expect(File(path).existsSync(), isFalse);
    final aside = dir.listSync().whereType<File>().singleWhere((f) => f.path.contains('.unreadable-'));
    expect(aside.readAsBytesSync(), bytes);
  });

  group('an open that fails', () {
    test('(the key store throws) tells the person once and opens on a later try', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      var keyReads = 0;
      final notices = <DatabaseNotice>[];
      final db = AppDatabase(openEncryptedDatabase(
        path: () async => path,
        key: () async {
          if (++keyReads <= 2) throw StateError('Keystore unavailable');
          return _key(1);
        },
        onNotice: notices.add,
      ));
      await expectLater(db.upsertConversation('c1'), throwsStateError);
      await expectLater(db.recentMessages('c1'), throwsStateError);
      // Once for the run of failures, not once per query.
      expect(notices, [DatabaseNotice.openFailed]);

      await db.upsertConversation('c1');
      await db.addMessage(_message('m1', 'saved after all'));
      expect([for (final m in await db.recentMessages('c1')) m.content], ['saved after all']);
      await db.close();
      expect(await _readWithKey(path, _key(1)), ['saved after all']);
      expect(notices, [DatabaseNotice.openFailed]);
    });

    test('(inside drift\'s own open) is dropped too, and the next query starts over', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      final failures = <Object>[];
      var opens = 0;
      var setups = 0;
      final db = AppDatabase(ReopeningExecutor(
        () async {
          opens++;
          return NativeDatabase(File(path), setup: (d) {
            // The first connection's setup fails, as keying on the drift isolate can.
            if (++setups == 1) throw const WrongDatabaseKeyException();
            applyDatabaseKey(d, _key(1));
          });
        },
        onFailure: failures.add,
      ));
      await expectLater(db.upsertConversation('c1'), throwsA(isA<WrongDatabaseKeyException>()));
      expect(failures, hasLength(1));

      await db.upsertConversation('c1');
      await db.addMessage(_message('m1', 'hello'));
      expect([for (final m in await db.recentMessages('c1')) m.content], ['hello']);
      await db.close();
      expect(failures, hasLength(1));
      expect(opens, 2);
    });
  });

  group('an open that fails', () {
    test('(the key store throws) tells the person once and opens on a later try', () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      var keyReads = 0;
      final notices = <DatabaseNotice>[];
      final db = AppDatabase(openEncryptedDatabase(
        path: () async => path,
        key: () async {
          if (++keyReads <= 2) throw StateError('Keystore unavailable');
          return _key(1);
        },
        onNotice: notices.add,
      ));
      await expectLater(db.upsertConversation('c1'), throwsStateError);
      await expectLater(db.recentMessages('c1'), throwsStateError);
      // Once for the run of failures, not once per query.
      expect(notices, [DatabaseNotice.openFailed]);

      await db.upsertConversation('c1');
      await db.addMessage(_message('m1', 'saved after all'));
      expect([for (final m in await db.recentMessages('c1')) m.content], ['saved after all']);
      await db.close();
      expect(await _readWithKey(path, _key(1)), ['saved after all']);
      expect(notices, [DatabaseNotice.openFailed]);
    });

    test("(inside drift's own open) is dropped too, and the next query starts over", () async {
      final path = '${dir.path}/therapylink_u1.sqlite';
      final failures = <Object>[];
      var opens = 0;
      var setups = 0;
      final db = AppDatabase(ReopeningExecutor(
        () async {
          opens++;
          return NativeDatabase(File(path), setup: (d) {
            // The first connection's setup fails, as keying on the drift isolate can.
            if (++setups == 1) throw const WrongDatabaseKeyException();
            applyDatabaseKey(d, _key(1));
          });
        },
        onFailure: failures.add,
      ));
      await expectLater(db.upsertConversation('c1'), throwsA(isA<WrongDatabaseKeyException>()));
      expect(failures, hasLength(1));

      await db.upsertConversation('c1');
      await db.addMessage(_message('m1', 'hello'));
      expect([for (final m in await db.recentMessages('c1')) m.content], ['hello']);
      await db.close();
      expect(failures, hasLength(1));
      expect(opens, 2);
    });
  });

  test('deleting a database removes its journals and leftovers but not another account\'s file', () async {
    final mine = '${dir.path}/therapylink_a.sqlite';
    for (final name in [mine, '$mine-wal', '$mine.encrypting', '$mine.unreadable-1', '${dir.path}/therapylink_ab.sqlite']) {
      File(name).writeAsStringSync('x');
    }
    await deleteDatabaseFiles(mine);
    expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['therapylink_ab.sqlite']);
  });
}
