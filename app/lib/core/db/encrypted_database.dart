/// Opening the local database encrypted. The native build uses SQLCipher; the web build has no
/// local database (see the web file for why).
library;

export 'encrypted_database_web.dart' if (dart.library.ffi) 'encrypted_database_native.dart' show openEncryptedDatabase, deleteDatabaseFiles;
