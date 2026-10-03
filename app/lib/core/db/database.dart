import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/auth_providers.dart';
import '../security/database_key.dart';
import 'database_notice.dart';
import 'encrypted_database.dart';

part 'database.g.dart';

/// Everything Eve hears lives here and nowhere else.
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Condensed notes on the part of this conversation that no longer fits the model's window.
  TextColumn get summary => text().nullable()();

  /// Messages created at or before this instant are covered by [summary] and not sent verbatim.
  DateTimeColumn get summarizedThrough => dateTime().nullable()();

  /// Messages at or before this instant have already been read for long-term memories.
  DateTimeColumn get rememberedThrough => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// What Eve carries between conversations: short notes the model writes from what the person said.
/// Shown, and deletable one by one, under You > What Eve remembers. Stored only here; in cloud
/// mode the notes that relate to a message are sent along with it.
class Memories extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // person | situation | goal | helped | plan
  TextColumn get content => text()();
  TextColumn get conversationId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // user | assistant | system
  TextColumn get content => text()();
  IntColumn get valence => integer().nullable()(); // Guardian output for user turns, −2..2
  TextColumn get emotion => text().nullable()();
  BoolColumn get flagged => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mood points queued for upload, hand-logged and inferred from chat. Text never leaves; only these
/// numbers do.
class MoodQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get valence => integer()();
  TextColumn get emotion => text().nullable()();
  TextColumn get source => text()();
  DateTimeColumn get recordedAt => dateTime()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Conversations, Messages, MoodQueue, Memories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // SQLite ships with foreign keys off; without this, deleting a conversation would orphan its
    // messages instead of cascading.
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(conversations, conversations.summary);
        await m.addColumn(conversations, conversations.summarizedThrough);
        await m.addColumn(conversations, conversations.rememberedThrough);
        await m.createTable(memories);
      }
    },
  );

  Future<Conversation?> conversationById(String id) => (select(conversations)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<void> setSummary(String id, String summary, DateTime through) =>
      (update(conversations)..where((c) => c.id.equals(id))).write(ConversationsCompanion(summary: Value(summary), summarizedThrough: Value(through)));

  Future<void> setRememberedThrough(String id, DateTime through) =>
      (update(conversations)..where((c) => c.id.equals(id))).write(ConversationsCompanion(rememberedThrough: Value(through)));

  Stream<List<Memory>> watchMemories() => (select(memories)..orderBy([(m) => OrderingTerm.desc(m.createdAt)])).watch();

  Future<List<Memory>> allMemories() => (select(memories)..orderBy([(m) => OrderingTerm.desc(m.createdAt)])).get();

  /// Applies one consolidation pass atomically: replaced and evicted notes go, new ones arrive.
  Future<void> applyMemoryChanges({required List<MemoriesCompanion> add, required List<String> remove}) => transaction(() async {
    if (remove.isNotEmpty) await (delete(memories)..where((m) => m.id.isIn(remove))).go();
    if (add.isNotEmpty) await batch((b) => b.insertAll(memories, add));
  });

  Future<void> deleteMemory(String id) => (delete(memories)..where((m) => m.id.equals(id))).go();

  Future<void> clearMemories() => delete(memories).go();

  /// Deletes one conversation; its messages go with it through the foreign-key cascade.
  Future<void> deleteConversation(String id) => (delete(conversations)..where((c) => c.id.equals(id))).go();

  /// Everything Eve has heard on this phone: every conversation, message and memory note, plus the
  /// chat-derived mood points not yet uploaded. Check-ins the person logged by hand stay.
  Future<void> deleteAllEveData() => transaction(() async {
    await delete(messages).go();
    await delete(conversations).go();
    await delete(memories).go();
    await (delete(moodQueue)..where((m) => m.source.equals('chat'))).go();
  });

  /// Empties every table. Used on sign-out and account deletion, before the file itself goes.
  Future<void> wipe() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });

  Stream<List<Message>> watchMessages(String conversationId) =>
      (select(messages)..where((m) => m.conversationId.equals(conversationId))..orderBy([(m) => OrderingTerm.asc(m.createdAt)])).watch();

  Future<List<Message>> recentMessages(String conversationId, {int limit = 20}) async {
    final rows = await (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          // Secondary sort by id DESC gives stable ordering when messages share the same
          // millisecond (happens in tests and briefly on fast hardware).
          ..orderBy([
            (m) => OrderingTerm.desc(m.createdAt),
            (m) => OrderingTerm.desc(m.id),
          ])
          ..limit(limit))
        .get();
    return rows.reversed.toList();
  }

  /// Creates the conversation once; later calls only touch updatedAt, so the summary and memory
  /// markers written in between are never overwritten.
  Future<void> upsertConversation(String id, {String? title}) async {
    final now = DateTime.now();
    await into(conversations).insert(
      ConversationsCompanion.insert(id: id, title: Value(title), createdAt: now, updatedAt: now),
      onConflict: DoUpdate((_) => ConversationsCompanion(updatedAt: Value(now))),
    );
  }

  Future<void> addMessage(MessagesCompanion m) => into(messages).insert(m);

  /// Exercise cards record completion by rewriting their content; nothing else is ever edited.
  Future<void> setMessageContent(String id, String content) =>
      (update(messages)..where((m) => m.id.equals(id))).write(MessagesCompanion(content: Value(content)));

  Future<int> countMessages(String conversationId) async {
    final n = messages.id.count();
    final q = selectOnly(messages)
      ..addColumns([n])
      ..where(messages.conversationId.equals(conversationId));
    return (await q.getSingle()).read(n) ?? 0;
  }

  Future<void> setMessageAnalysis(String id, {int? valence, String? emotion, bool? flagged}) =>
      (update(messages)..where((m) => m.id.equals(id))).write(
        MessagesCompanion(valence: Value(valence), emotion: Value(emotion), flagged: Value(flagged ?? false)),
      );

  Future<void> queueMood({required int valence, String? emotion, required String source}) => into(moodQueue).insert(
    MoodQueueCompanion.insert(valence: valence, emotion: Value(emotion), source: source, recordedAt: DateTime.now()),
  );

  Future<List<MoodQueueData>> pendingMood() => (select(moodQueue)..where((m) => m.uploaded.equals(false))).get();

  Future<void> markUploaded(Iterable<int> ids) =>
      (update(moodQueue)..where((m) => m.id.isIn(ids.toList()))).write(const MoodQueueCompanion(uploaded: Value(true)));

  Future<List<MoodQueueData>> localMoodSince(DateTime since) =>
      (select(moodQueue)..where((m) => m.recordedAt.isBiggerOrEqualValue(since))..orderBy([(m) => OrderingTerm.asc(m.recordedAt)])).get();
}

/// One database file per account, so a second person signing in on a shared phone never sees the
/// first one's conversations. Signed out, nothing should be reading it; the guest file stays empty.
String databaseNameFor(String? uid) => uid == null ? 'therapylink_guest' : 'therapylink_$uid';

/// Kept out of Documents: on iOS that folder is visible to Finder and the Files app.
Future<String> _databasePath(String name) async => '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}$name.sqlite';

/// How a named database is opened: encrypted with SQLCipher under that database's own key, after
/// encrypting a plaintext file an earlier build left (see encrypted_database_native.dart). Tests
/// swap in an in-memory executor.
final databaseOpenerProvider = Provider<QueryExecutor Function(String name)>((ref) {
  final keys = ref.watch(databaseKeyStoreProvider);
  return (name) => openEncryptedDatabase(
    path: () => _databasePath(name),
    key: () => keys.keyFor(name),
    onNotice: (notice) => ref.read(databaseNoticeProvider.notifier).report(notice),
  );
});

/// Removes a named database's files from disk, then its key, so anything the OS failed to delete
/// is unreadable. Tests swap in a recorder.
final databaseDeleterProvider = Provider<Future<void> Function(String name)>((ref) {
  final keys = ref.watch(databaseKeyStoreProvider);
  return (name) async {
    if (kIsWeb) return;
    try {
      await deleteDatabaseFiles(await _databasePath(name));
    } finally {
      try {
        await keys.forget(name);
      } catch (e) {
        debugPrint('could not delete the database key: ${e.runtimeType}');
      }
    }
  };
});

/// Rebuilt when the account changes: the old file is closed and the new person's is opened.
final databaseProvider = Provider<AppDatabase>((ref) {
  final name = databaseNameFor(ref.watch(currentUidProvider));
  final db = AppDatabase(ref.watch(databaseOpenerProvider)(name));
  ref.onDispose(db.close);
  return db;
});
