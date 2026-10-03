import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/features/eve/crisis_mode.dart';
import 'package:therapylink/features/eve/eve_controller.dart';
import 'package:therapylink/features/shared/crisis_copy.dart';

import 'crisis_fakes.dart';

/// Waits until [done] holds, letting the controller's awaits run in between.
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(done(), isTrue, reason: 'condition never held');
}

int _inAnHour() => DateTime.now().add(const Duration(minutes: 40)).millisecondsSinceEpoch;

void main() {
  group('one turn at a time', () {
    test('a double send starts one reply, not two', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);

      final first = h.eve.send('hello');
      final second = h.eve.send('hello');
      await Future.wait([first, second]);

      expect(h.engine.replies, hasLength(1));
      expect((await h.messages()).where((m) => m.role == 'user'), hasLength(1));
    });

    test('New conversation while Eve is replying does nothing and starts no second inference', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      h.engine.gate = Completer<void>();
      final before = h.conversation;

      final sending = h.eve.send('hello');
      await until(() => h.engine.replies.isNotEmpty);
      await h.eve.newConversation();
      expect(await h.eve.wrapUp(nextStepLabel: (s) => s), isFalse);
      h.engine.gate!.complete();
      await sending;
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(h.conversation, before);
      expect(h.engine.maxInFlight, 1);
      expect(h.engine.replies, hasLength(1));
    });

    test('generating always resets, even when a turn fails part-way', () async {
      final h = await Harness.create(guardian: FakeGuardian((_) => throw StateError('guardian down')));
      addTearDown(h.dispose);

      await h.eve.send('hello');

      expect(h.state.generating, isFalse);
      // And the next message is not locked out.
      await h.eve.send('still there?');
      expect((await h.messages()).where((m) => m.role == 'user'), hasLength(2));
    });
  });

  group('help does not depend on storage', () {
    test('a crisis message still opens the crisis sheet when the database cannot be written', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      await h.db.close(); // every write now throws

      await h.eve.send('CRISIS: I have the pills here');

      expect(h.state.crisisPending, isTrue);
      expect(h.state.crisisKind, CrisisKind.suicide);
      expect(h.state.generating, isFalse);
      expect(h.engine.replies, isEmpty);
    });

    test('an ordinary message that fails to save raises no crisis', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);
      await h.db.close();

      await h.eve.send('had a long day at work');

      expect(h.state.crisisPending, isFalse);
      expect(h.state.generating, isFalse);
    });
  });

  group('the crisis route', () {
    test('a crisis turn never reaches the engine and leaves a crisis card in the transcript', () async {
      final h = await Harness.create(engine: FakeEngine(failOnCall: true));
      addTearDown(h.dispose);

      await h.eve.send('CRISIS marna chahti hoon');

      expect(h.engine.violations, 0);
      final rows = await h.messages();
      expect(rows.map((m) => m.role), ['user', crisisRole]);
      expect(rows.first.flagged, isTrue);
      expect(parseCrisis(rows.last.content), (kind: CrisisKind.suicide, language: CrisisLanguage.romanUrdu));
      expect(h.state.crisisPending, isTrue);
      expect(h.state.crisisLanguage, CrisisLanguage.romanUrdu);
      expect(h.state.generating, isFalse);
    });

    test('the kind of danger reaches the card and the sheet', () async {
      final h = await Harness.create(engine: FakeEngine(failOnCall: true), guardian: FakeGuardian(null, CrisisKind.child));
      addTearDown(h.dispose);

      await h.eve.send("CRISIS I'm 14 and my stepdad touched me");

      expect(h.state.crisisKind, CrisisKind.child);
      expect(parseCrisis((await h.messages()).last.content).kind, CrisisKind.child);
    });

    test('risk split across turns is caught even after a long benign message', () async {
      // Reads only the head of a passage, the way the trained Guardian's 128 tokens do, and flags
      // the risk only when both halves of it are in view.
      final guardian = FakeGuardian((t) {
        final head = t.length > 600 ? t.substring(0, 600) : t;
        return head.contains('lost my job') && head.contains('tallest bridge');
      });
      final h = await Harness.create(guardian: guardian);
      addTearDown(h.dispose);

      await h.eve.send('I lost my job today. ${'Then I walked around the market for a long time and looked at things. ' * 12}');
      expect(h.engine.replies, hasLength(1));
      h.engine.failOnCall = true;

      await h.eve.send('which is the tallest bridge in the city');

      expect(h.engine.violations, 0);
      expect(guardian.seen.last, startsWith('which is the tallest bridge'));
      expect((await h.messages()).last.role, crisisRole);
    });

    test('the turn after a crisis is still in crisis mode, even with no crisis words in it', () async {
      final h = await Harness.create(engine: FakeEngine(failOnCall: true));
      addTearDown(h.dispose);

      await h.eve.send('CRISIS I want to die');
      h.eve.crisisShown();
      await h.eve.send('I already took them');

      expect(h.engine.violations, 0);
      final rows = await h.messages();
      expect(rows.map((m) => m.role), ['user', crisisRole, 'user', crisisRole]);
      expect(rows[2].flagged, isTrue);
      // The card is always there; the sheet doesn't interrupt again within ten minutes.
      expect(h.state.crisisPending, isFalse);
    });
  });

  group('sticky crisis mode', () {
    test('a flagged turn starts an hour of crisis mode that survives a restart', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);

      await h.eve.send('CRISIS');

      final until = h.prefs.getInt('eveCrisisActiveUntil');
      expect(until, isNotNull);
      final left = DateTime.fromMillisecondsSinceEpoch(until!).difference(DateTime.now());
      expect(left, greaterThan(crisisModeLength - const Duration(minutes: 1)));
      expect(h.prefs.getString('eveCrisisKind'), 'suicidal');
    });

    test('while it lasts every Eve reply is followed by a crisis card that the model never sees', () async {
      final h = await Harness.create(prefs: {'eveCrisisActiveUntil': _inAnHour(), 'eveCrisisKind': 'abuse'});
      addTearDown(h.dispose);

      await h.eve.send('thank you for listening');
      await h.eve.send('I feel a bit calmer');

      final rows = await h.messages();
      expect(rows.map((m) => m.role), ['user', 'assistant', crisisRole, 'user', 'assistant', crisisRole]);
      expect(parseCrisis(rows[2].content).kind, CrisisKind.abuse);
      final lastHistory = h.engine.replies.last.history;
      expect(lastHistory.map((m) => m['role']), everyElement(isIn(['user', 'assistant'])));
      expect(lastHistory.map((m) => m['content']).join(), isNot(contains('abuse|')));
    });

    test('it ends on time', () async {
      final past = DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
      final h = await Harness.create(prefs: {'eveCrisisActiveUntil': past});
      addTearDown(h.dispose);

      await h.eve.send('hello');

      expect((await h.messages()).map((m) => m.role), ['user', 'assistant']);
    });

    test('no next step is offered at wrap-up', () async {
      final h = await Harness.create(prefs: {'eveCrisisActiveUntil': _inAnHour()});
      addTearDown(h.dispose);
      h.engine.completionText = 'You talked about a hard week.';
      await h.eve.send('it was a hard week');
      await h.eve.send('work and home both');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final before = h.engine.completions.length;

      expect(await h.eve.wrapUp(nextStepLabel: (s) => 'Next: $s'), isTrue);

      expect(h.engine.completions.length - before, 1, reason: 'only the summary, no step request');
      final last = (await h.messages()).lastWhere((m) => m.role == 'assistant');
      expect(last.content, isNot(contains('Next:')));
    });
  });

  test('mood read from chat stays on the phone', () async {
    final h = await Harness.create(guardian: FakeGuardian((_) => false));
    addTearDown(h.dispose);

    await h.eve.send('feeling very low today');

    expect(await h.db.pendingMood(), isEmpty);
  });

  test('a reply that gives a foreign helpline has the number taken out and the real lines added', () async {
    final h = await Harness.create(engine: FakeEngine(replyText: 'Please call 800-273-8255 (Suicide & Crisis Lifeline) right away.'));
    addTearDown(h.dispose);

    await h.eve.send('what is the most painless way');

    final rows = await h.messages();
    final reply = rows.firstWhere((m) => m.role == 'assistant').content;
    expect(reply, isNot(contains('8255')));
    expect(reply, contains(CrisisCopy.en.numberRemoved));
    expect(rows.last.role, crisisRole);
  });

  test('a foreign number is never on screen while the reply streams', () async {
    final engine = FakeEngine()..tokens = ['Please call ', '800', '-273', '-82', '55', ' right now.'];
    final h = await Harness.create(engine: engine);
    addTearDown(h.dispose);
    final shown = <String>[];
    final sub = h.container.listen(eveControllerProvider, (_, next) => shown.add(next.partial));
    addTearDown(sub.close);

    await h.eve.send('what is the most painless way');

    expect(shown, isNotEmpty);
    for (final partial in shown) {
      expect(partial, isNot(contains('800')));
      expect(partial, isNot(contains('273')));
    }
    expect(shown, contains('Please call ${CrisisCopy.en.numberRemoved} right now.'));
  });

  test('a wrap-up that gives a foreign number has it taken out and the real lines added', () async {
    final h = await Harness.create();
    addTearDown(h.dispose);
    h.engine.completionText = 'You talked about a hard week. You can call 988 any time.';
    h.engine.stepText = 'Ring 800-273-8255 tonight';
    await h.eve.send('it was a hard week');
    await h.eve.send('work and home both');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(await h.eve.wrapUp(nextStepLabel: (s) => 'Next: $s'), isTrue);

    final rows = await h.messages();
    final wrap = rows.lastWhere((m) => m.role == 'assistant').content;
    expect(wrap, isNot(contains('988')));
    expect(wrap, isNot(contains('8255')));
    expect(wrap, contains(CrisisCopy.en.numberRemoved));
    expect(rows.last.role, crisisRole);
  });

  test('a flagged turn and its crisis card stay out of the summary and memory requests', () async {
    final h = await Harness.create();
    addTearDown(h.dispose);
    final conversation = h.conversation;
    await h.db.upsertConversation(conversation);
    var at = DateTime.now().subtract(const Duration(hours: 1));
    var n = 0;
    Future<void> add(String role, String content, {bool flagged = false}) async {
      at = at.add(const Duration(minutes: 1));
      await h.db.addMessage(MessagesCompanion.insert(
        id: 'm${n++}',
        conversationId: conversation,
        role: role,
        content: content,
        flagged: Value(flagged),
        createdAt: at,
      ));
    }

    const unflagged = 'I started a pottery class on Saturdays';
    const flagged = 'CRISIS i have a plan for tonight';
    final card = crisisContent(CrisisKind.suicide, CrisisLanguage.en);
    // Sized so both turns fall outside the summary's verbatim window (4,500 characters) and inside
    // the memory pass's reading window (5,000), so both requests would see them.
    for (var i = 0; i < 3; i++) {
      await add(i.isEven ? 'user' : 'assistant', 'earlier ${'x' * 992}');
    }
    await add('user', unflagged);
    await add('user', flagged, flagged: true);
    await add(crisisRole, card);
    for (var i = 0; i < 4; i++) {
      await add(i.isEven ? 'assistant' : 'user', 'later ${'y' * 1114}');
    }

    h.engine.completionText = 'They talked about a new class.';
    await h.eve.newConversation();
    await until(() => h.engine.completions.length >= 2);

    String request(String opening) => h.engine.completions.map((c) => c.single['content']!).firstWhere((c) => c.startsWith(opening));
    final summary = request('Summarise');
    final memory = request('Read this conversation');
    for (final sent in [summary, memory]) {
      expect(sent, contains(unflagged));
      expect(sent, isNot(contains(flagged)));
      expect(sent, isNot(contains(card)));
    }
    // The span still moves past the flagged turn, so it is not read again next time.
    final convo = await h.db.conversationById(conversation);
    expect(convo!.summarizedThrough, isNotNull);
    expect(convo.rememberedThrough, (await h.db.recentMessages(conversation, limit: 500)).last.createdAt);
  });

  group('wrap-up leaves flagged turns out', () {
    Future<Harness> seeded(List<(String, String, bool)> rows) async {
      final h = await Harness.create();
      final conversation = h.conversation;
      await h.db.upsertConversation(conversation);
      var at = DateTime.now().subtract(const Duration(minutes: 30));
      var n = 0;
      for (final (role, content, flagged) in rows) {
        at = at.add(const Duration(minutes: 1));
        await h.db.addMessage(MessagesCompanion.insert(
          id: 'w${n++}',
          conversationId: conversation,
          role: role,
          content: content,
          flagged: Value(flagged),
          createdAt: at,
        ));
      }
      return h;
    }

    const flagged = 'CRISIS i have a plan for tonight';

    test('the wrap-up, its step and the memory pass after it never see a flagged turn', () async {
      final h = await seeded([
        ('user', 'I started a pottery class on Saturdays', false),
        ('assistant', 'That sounds lovely.', false),
        ('user', flagged, true),
        (crisisRole, crisisContent(CrisisKind.suicide, CrisisLanguage.en), false),
        ('user', 'I will book the next class tomorrow', false),
      ]);
      addTearDown(h.dispose);
      h.engine.completionText = 'You talked about a new class.';
      h.engine.stepText = 'Book the next class tomorrow.';

      expect(await h.eve.wrapUp(nextStepLabel: (s) => 'Next: $s'), isTrue);
      await until(() => h.engine.completions.any((c) => c.single['content']!.startsWith('Read this conversation')));

      final sent = h.engine.completions.map((c) => c.single['content']!).toList();
      expect(sent.where((c) => c.startsWith('A person has been talking')), hasLength(1));
      expect(sent.where((c) => c.startsWith('From this conversation')), hasLength(1));
      for (final request in sent) {
        expect(request, contains('pottery'));
        expect(request, isNot(contains(flagged)));
      }
    });

    test('with only flagged turns from the person there is nothing to wrap up', () async {
      final h = await seeded([
        ('user', flagged, true),
        ('assistant', 'I am here with you.', false),
        ('user', 'CRISIS nothing matters', true),
      ]);
      addTearDown(h.dispose);

      expect(await h.eve.wrapUp(nextStepLabel: (s) => 'Next: $s'), isFalse);
      expect(h.engine.completions, isEmpty);
      expect((await h.messages()).where((m) => m.role == 'assistant'), hasLength(1));
    });
  });
}
