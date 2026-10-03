import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/settings.dart';
import 'secret_store.dart';

/// The key each local database is encrypted with: 32 random bytes, one per database file (so one
/// per account on the phone) and per install, kept in the Keystore or Keychain and never in prefs.
///
/// The key is never logged and never put in an exception message. It leaves this class only as
/// the hex string SQLCipher's PRAGMA key takes.
class DatabaseKeyStore {
  DatabaseKeyStore(this._secrets, this._prefs, {Random? random}) : _random = random ?? Random.secure();

  final SecretStore _secrets;
  final SharedPreferences _prefs;
  final Random _random;

  static const _entryPrefix = 'tl.dbkey.';
  static const _installIdPref = 'dbKeyInstallId';
  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  final _keys = <String, Future<String>>{};
  Future<String>? _installId;

  /// The key for [databaseName], created on first use and the same on every call after. Two calls
  /// racing on a fresh install share one creation, so they can never end up with different keys.
  Future<String> keyFor(String databaseName) async {
    final pending = _keys[databaseName] ??= _loadOrCreate(databaseName);
    try {
      return await pending;
    } catch (_) {
      // A Keystore hiccup must not stick: the next open tries again.
      if (identical(_keys[databaseName], pending)) _keys.remove(databaseName);
      rethrow;
    }
  }

  /// Deletes the key. Whatever is left of the file it opened is unreadable from then on, which is
  /// what sign-out and account deletion want even if the OS keeps the file's blocks around.
  Future<void> forget(String databaseName) async {
    _keys.remove(databaseName);
    await _secrets.delete(await _entryName(databaseName));
  }

  Future<String> _loadOrCreate(String databaseName) async {
    final entry = await _entryName(databaseName);
    final existing = await _secrets.read(entry);
    if (existing != null) {
      // Never replaced: a new key would make the existing file unreadable for good.
      if (!_hex64.hasMatch(existing)) throw StateError('the stored database key is malformed');
      return existing;
    }
    final key = _hex([for (var i = 0; i < 32; i++) _random.nextInt(256)]);
    await _secrets.write(entry, key);
    // Read back: a store that dropped the write would otherwise leave a file encrypted under a key
    // nobody can find again.
    if (await _secrets.read(entry) != key) throw StateError('the database key could not be stored');
    return key;
  }

  Future<String> _entryName(String databaseName) async => '$_entryPrefix${await (_installId ??= _loadInstallId())}.$databaseName';

  /// Keychain items outlive an uninstall on iOS; prefs don't. A missing install id therefore means
  /// a fresh install, and any keys a previous install left behind are removed before new ones are
  /// made, so every install starts with its own.
  Future<String> _loadInstallId() async {
    final saved = _prefs.getString(_installIdPref);
    if (saved != null) return saved;
    final stale = (await _secrets.readAll()).keys.where((k) => k.startsWith(_entryPrefix));
    for (final k in stale) {
      await _secrets.delete(k);
    }
    final id = _hex([for (var i = 0; i < 8; i++) _random.nextInt(256)]);
    await _prefs.setString(_installIdPref, id);
    return id;
  }

  static String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
}

final databaseKeyStoreProvider = Provider<DatabaseKeyStore>(
  (ref) => DatabaseKeyStore(ref.watch(secretStoreProvider), ref.watch(sharedPreferencesProvider)),
);
