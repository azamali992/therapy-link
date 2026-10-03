import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/features/eve/conversations_repository.dart';

import 'crisis_fakes.dart';

final _t0 = DateTime(2026, 9, 1, 10);

Future<void> _conversation(AppDatabase db, String id, {required DateTime updated, String? title}) =>
    db.into(db.conversations).insert(ConversationsCompanion.insert(id: id, title: Value(title), createdAt: updated, updatedAt: updated));

var _n = 0;

Future<void> _message(AppDatabase db, String conversation, String role, String content, {DateTime? at}) => db.addMessage(
  MessagesCompanion.insert(id: 'msg${_n++}', conversationId: conversation, role: role, content: content, createdAt: at ?? _t0.add(Duration(minutes: _n))),
);

Future<void> _memory(AppDatabase db, String conversation) => db.applyMemoryChanges(
  add: [MemoriesCompanion.insert(id: 'mem-$conversation', kind: 'situation', content: 'Exams in November', conversationId: Value(conversation), createdAt: _t0)],
  remove: const [],
);

void main() {
  group('oneLineTitle', () {
    test('keeps the first line, whitespace collapsed', () {
      expect(oneLineTitle('  I could not   sleep again\nand then work was awful'), 'I could not sleep again');
    });

    test('caps a long first line', () {
      final t = oneLineTitle('a' * 200)!;
      expect(t.length, lessThanOrEqualTo(81));
      expect(t, endsWith('…'));
    });

    test('nothing left means no title', () {
      expect(oneLineTitle('   \n  '), isNull);
      expect(oneLineTitle(null), isNull);
    });
  });

  group('ConversationsRepository', () {
    late AppDatabase db;
    late ConversationsRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = ConversationsRepository(db);
    });
    tearDown(() => db.close());

    test('lists conversations newest first with title, date and a count of spoken turns', () async {
      await _conversation(db, 'old', updated: _t0);
      await _message(db, 'old', 'user', 'Exams are close\nand I am panicking');
      await _message(db, 'old', 'assistant', 'That sounds like a lot.');
      await _message(db, 'old', 'crisis', 'suicide|en');
      await _conversation(db, 'new', updated: _t0.add(const Duration(days: 2)));
      await _message(db, 'new', 'user', 'hello');

      final rows = await repo.watchAll().first;

      expect(rows.map((r) => r.id), ['new', 'old']);
      expect(rows.last.title, 'Exams are close');
      expect(rows.last.messageCount, 2, reason: 'crisis and exercise cards are not messages');
      expect(rows.first.updatedAt, _t0.add(const Duration(days: 2)));
    });

    test('the title comes from the first thing the person said, not from Eve', () async {
      await _conversation(db, 'c', updated: _t0);
      await _message(db, 'c', 'assistant', 'Welcome back', at: _t0);
      await _message(db, 'c', 'user', 'first', at: _t0.add(const Duration(minutes: 1)));
      await _message(db, 'c', 'user', 'second', at: _t0.add(const Duration(minutes: 2)));
      expect((await repo.watchAll().first).single.title, 'first');
    });

    test('a thread with no words from the person has no title, so the list shows its date', () async {
      await _conversation(db, 'c', updated: _t0);
      await _message(db, 'c', 'exercise', 'box');
      final row = (await repo.watchAll().first).single;
      expect(row.title, isNull);
      expect(row.messageCount, 0);
    });

    test('empty conversation rows are left out', () async {
      await _conversation(db, 'empty', updated: _t0);
      expect(await repo.watchAll().first, isEmpty);
    });

    test('the list updates as messages arrive', () async {
      final seen = <int>[];
      final sub = repo.watchAll().listen((rows) => seen.add(rows.length));
      await pumpEventQueue();
      await _conversation(db, 'c', updated: _t0);
      await _message(db, 'c', 'user', 'hi');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen.last, 1);
    });

    test('delete removes the conversation and its messages, keeps its memory notes and the others', () async {
      await _conversation(db, 'gone', updated: _t0);
      await _message(db, 'gone', 'user', 'delete me');
      await _message(db, 'gone', 'assistant', 'ok');
      await _memory(db, 'gone');
      await _conversation(db, 'kept', updated: _t0);
      await _message(db, 'kept', 'user', 'keep me');

      await repo.delete('gone');

      expect(await db.conversationById('gone'), isNull);
      expect(await db.countMessages('gone'), 0);
      expect(await db.countMessages('kept'), 1);
      expect((await db.allMemories()).single.conversationId, 'gone');
      expect((await repo.watchAll().first).map((r) => r.id), ['kept']);
    });

    test('delete does not rely on the foreign-key cascade', () async {
      await _conversation(db, 'c', updated: _t0);
      await _message(db, 'c', 'user', 'hi');
      await db.customStatement('PRAGMA foreign_keys = OFF');

      await repo.delete('c');

      expect(await db.countMessages('c'), 0);
      expect(await db.conversationById('c'), isNull);
    });
  });

  group('EveController', () {
    test('deleting the open conversation opens a fresh one and keeps memory notes', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      await h.eve.send('hello');
      final first = h.conversation;
      await _memory(h.db, first);

      expect(await h.eve.deleteConversation(first), isTrue);

      expect(h.conversation, isNot(first));
      expect(await h.db.countMessages(first), 0);
      expect(await h.db.conversationById(first), isNull);
      expect(await h.db.allMemories(), hasLength(1));
      expect(h.state.generating, isFalse);
    });

    test('deleting another conversation leaves the open one alone', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      await _conversation(h.db, 'other', updated: _t0);
      await _message(h.db, 'other', 'user', 'older');
      await h.eve.send('hello');
      final open = h.conversation;

      expect(await h.eve.deleteConversation('other'), isTrue);

      expect(h.conversation, open);
      expect(await h.db.countMessages(open), 2);
      expect(await h.db.countMessages('other'), 0);
    });

    test('opening a conversation from the list switches to it', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      await _conversation(h.db, 'earlier', updated: _t0);
      await _message(h.db, 'earlier', 'user', 'from before');

      expect(await h.eve.openConversation('earlier'), isTrue);

      expect(h.conversation, 'earlier');
      expect(h.prefs.getString('conversationId'), 'earlier');
    });

    test('mid-reply, switching away and deleting the open thread are both refused', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      await _conversation(h.db, 'earlier', updated: _t0);
      await _message(h.db, 'earlier', 'user', 'from before');
      h.engine.gate = Completer<void>();
      final reply = h.eve.send('hello');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final open = h.conversation;

      expect(await h.eve.openConversation('earlier'), isFalse);
      expect(await h.eve.deleteConversation(open), isFalse);
      expect(h.conversation, open);

      // Another thread can still go while Eve replies here.
      expect(await h.eve.deleteConversation('earlier'), isTrue);

      h.engine.gate!.complete();
      await reply;
      expect(await h.db.countMessages(open), 2);
    });

    Future<void> inFlight(Harness h, int completions) async {
      for (var i = 0; i < 200 && h.engine.completions.length < completions; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(h.engine.completions, hasLength(completions));
    }

    test('a memory pass already running for a conversation writes nothing once it is deleted', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      await h.eve.send('My exams start in November');
      final first = h.conversation;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.engine.completions, isEmpty, reason: 'two turns are too few for an in-session memory pass');
      await _conversation(h.db, 'other', updated: _t0);
      await _message(h.db, 'other', 'user', 'from before');

      // Leaving for another thread queues the closing pass for the first; hold it inside the model call.
      h.engine.completionText = 'situation: Exams start in November';
      h.engine.gate = Completer<void>();
      expect(await h.eve.openConversation('other'), isTrue);
      await inFlight(h, 1);

      expect(await h.eve.deleteConversation(first), isTrue);
      h.engine.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await h.db.allMemories(), isEmpty);
      expect(await h.db.conversationById(first), isNull);
    });

    test('deleting the open conversation right after talking stops the pass it queued', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      h.engine.completionText = 'situation: Exams start in November';
      // Seven earlier turns, so the pass queued by the next reply reads for memories.
      final open = h.conversation;
      await h.db.upsertConversation(open);
      final start = DateTime.now().subtract(const Duration(hours: 1));
      for (var i = 0; i < 7; i++) {
        await _message(h.db, open, i.isEven ? 'user' : 'assistant', 'turn $i', at: start.add(Duration(minutes: i)));
      }
      h.engine.gate = Completer<void>();
      final reply = h.eve.send('My exams start in November');
      await inFlight(h, 0);
      h.engine.gate!.complete();
      await reply;
      // The reply is saved; the memory pass is next on the queue. Hold it in its model call.
      h.engine.gate = Completer<void>();
      await inFlight(h, 1);

      expect(await h.eve.deleteConversation(open), isTrue);
      h.engine.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await h.db.allMemories(), isEmpty);
      expect(h.conversation, isNot(open));
    });

    test('an upkeep pass for a conversation that stays still writes memories', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      await h.eve.send('My exams start in November');
      final first = h.conversation;
      await _conversation(h.db, 'other', updated: _t0);
      await _message(h.db, 'other', 'user', 'from before');
      h.engine.completionText = 'situation: Exams start in November';

      expect(await h.eve.openConversation('other'), isTrue);
      await inFlight(h, 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect((await h.db.allMemories()).single.conversationId, first);
    });
  });
}