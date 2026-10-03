import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

/// One row of the conversation list.
@immutable
class ConversationSummary {
  const ConversationSummary({required this.id, required this.title, required this.createdAt, required this.updatedAt, required this.messageCount});

  final String id;

  /// The first thing the person said, cut to one line, or null when there is nothing to show
  /// (a thread that only holds an exercise card, say). The list falls back to the date.
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// What the person and Eve said. Crisis and exercise cards are not counted.
  final int messageCount;
}

/// Longest title kept; the row ellipsizes anyway, this only keeps a pasted essay out of memory.
const _titleMax = 80;

/// The first line of [text], whitespace collapsed and capped, or null if nothing is left.
String? oneLineTitle(String? text) {
  if (text == null) return null;
  final line = text.trim().split('\n').first.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (line.isEmpty) return null;
  return line.length <= _titleMax ? line : '${line.substring(0, _titleMax).trimRight()}…';
}

/// Reads and deletes whole conversations. Kept beside the Eve feature, on top of the database's
/// public API, so core/db stays unchanged.
class ConversationsRepository {
  ConversationsRepository(this._db);

  final AppDatabase _db;

  /// Every conversation with at least one row in it, newest activity first. Re-emits whenever a
  /// message or conversation changes.
  Stream<List<ConversationSummary>> watchAll() {
    // The rowid breaks ties between conversations touched in the same second (drift stores times
    // to the second).
    final query = _db.customSelect(
      '''
      SELECT c.id AS id, c.title AS title, c.created_at AS created_at, c.updated_at AS updated_at,
        (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = c.id AND m.role IN ('user', 'assistant')) AS turns,
        (SELECT m.content FROM messages m WHERE m.conversation_id = c.id AND m.role = 'user'
           ORDER BY m.created_at ASC, m.rowid ASC LIMIT 1) AS first_user
      FROM conversations c
      WHERE EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = c.id)
      ORDER BY c.updated_at DESC, c.rowid DESC
      ''',
      readsFrom: {_db.conversations, _db.messages},
    );
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          ConversationSummary(
            id: r.read<String>('id'),
            title: oneLineTitle(r.readNullable<String>('title')) ?? oneLineTitle(r.readNullable<String>('first_user')),
            createdAt: r.read<DateTime>('created_at'),
            updatedAt: r.read<DateTime>('updated_at'),
            messageCount: r.read<int>('turns'),
          ),
      ],
    );
  }

  /// Deletes a conversation and every message in it, together or not at all. Memory notes written
  /// from it are separate and stay; the person manages those under What Eve remembers.
  Future<void> delete(String id) => _db.transaction(() async {
    // Messages first and explicitly: the cascade only runs with the foreign-key pragma on, and a
    // half-deleted thread must never be left behind.
    await (_db.delete(_db.messages)..where((m) => m.conversationId.equals(id))).go();
    await (_db.delete(_db.conversations)..where((c) => c.id.equals(id))).go();
  });
}

final conversationsRepositoryProvider = Provider<ConversationsRepository>((ref) => ConversationsRepository(ref.watch(databaseProvider)));

final conversationListProvider = StreamProvider<List<ConversationSummary>>((ref) => ref.watch(conversationsRepositoryProvider).watchAll());
