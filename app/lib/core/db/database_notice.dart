import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something about opening the local database the person has to be told, because it changed or
/// could not change what is kept on the phone.
enum DatabaseNotice {
  /// A database from an earlier build could not be encrypted. It was kept as it is and is still
  /// used, and encryption is tried again the next time the app opens.
  migrationFailed,

  /// The file could not be opened with this phone's key (usually after the key store was reset).
  /// It was moved aside, not deleted, and a new empty database was started.
  unreadable,

  /// The database could not be opened at all this time (the key store or SQLCipher failed).
  /// Nothing can be saved or read until it opens; every later use tries again.
  openFailed,
}

/// The latest [DatabaseNotice], shown once by the app frame and then cleared.
class DatabaseNoticeNotifier extends Notifier<DatabaseNotice?> {
  @override
  DatabaseNotice? build() => null;

  void report(DatabaseNotice notice) => state = notice;

  void clear() => state = null;
}

final databaseNoticeProvider = NotifierProvider<DatabaseNoticeNotifier, DatabaseNotice?>(DatabaseNoticeNotifier.new);
