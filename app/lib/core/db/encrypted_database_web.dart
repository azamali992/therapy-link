import 'package:drift/drift.dart';

import 'database_notice.dart';

/// The web build is the clinician console, which keeps nothing on the device. There is no
/// encrypted storage in a browser to put Eve's conversations in, so nothing opens here: a query
/// fails instead of quietly writing plaintext to IndexedDB.
QueryExecutor openEncryptedDatabase({
  required Future<String> Function() path,
  required Future<String> Function() key,
  required void Function(DatabaseNotice notice) onNotice,
}) => DatabaseConnection.delayed(Future.error(UnsupportedError('the local database is not available on the web')));

Future<void> deleteDatabaseFiles(String path) async {}
