import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/features/eve/memory.dart';

var _clock = DateTime(2026, 9, 16, 9);

Memory _mem(String kind, String content, {String? id, DateTime? at}) {
  _clock = _clock.add(const Duration(minutes: 1));
  return Memory(id: id ?? '${_clock.millisecondsSinceEpoch}', kind: kind, content: content, createdAt: at ?? _clock);
}

Message _msg(String role, String content) {
  _clock = _clock.add(const Duration(minutes: 1));
  return Message(id: '${_clock.microsecondsSinceEpoch}', conversationId: 'c', role: role, content: content, flagged: false, createdAt: _clock);
}

void main() {
  group('notes folded into the prompt', () {
    test('memories and summary appear under their headers, memories first', () {
      final notes = buildContextNotes(memories: [_mem('person', 'Sister Ayesha lives in Lahore')], summary: 'They talked about exams.')!;
      expect(notes.indexOf(memoryHeader), lessThan(notes.indexOf(summaryHeader)));
      expect(notes, contains('- Sister Ayesha lives in Lahore'));
      expect(notes, contains('They talked about exams.'));
    });

    test('nothing to say means no block at all', () {
      expect(buildContextNotes(), isNull);
      expect(buildContextNotes(summary: '   '), isNull);
    });

    test('the budget stops adding notes once full', () {
      final many = [for (var i = 0; i < 40; i++) _mem('situation', 'note number $i ${'x' * 60}')];
      final notes = buildContextNotes(memories: many, budget: 300)!;
      expect(notes.length, lessThan(300 + memoryHeader.length + 10));
    });
  });

  group('choosing which memories to show', () {
    test('only notes that relate to this message are sent, best match first', () {
      final plan = _mem('plan', 'Talk to manager about the deadline on Monday');
      final unrelated = _mem('person', 'Has a cat called Biscuit');
      final related = _mem('situation', 'Exams in November are causing panic');
      final chosen = selectMemories([related, unrelated, plan], query: 'my exams are making me panic again');
      expect(chosen, [related]);
      expect(selectMemories([plan], query: 'spoke to my manager about the deadline'), [plan]);
    });

    test('a message that shares nothing with the notes gets none of them', () {
      expect(selectMemories([_mem('person', 'Has a cat called Biscuit')], query: "what's the point of any of this"), isEmpty);
    });
  });

  group('consolidating new notes (Mem0 update step)', () {
    test('a repeat is skipped, a newer note on the same subject replaces the old one, anything else is added', () {
      final old = _mem('situation', 'Final exams start next week and they feel unprepared', id: 'old');
      final pet = _mem('person', 'Younger brother Ali shares their room', id: 'pet');
      final result = consolidate([
        (kind: 'situation', content: 'Final exams start next week and they feel unprepared'),
        (kind: 'situation', content: 'Final exams start next week, feeling more prepared now'),
        (kind: 'goal', content: 'Wants to sleep before midnight'),
      ], [old, pet]);
      expect(result.remove, ['old']);
      expect(result.add.map((a) => a.content), ['Final exams start next week, feeling more prepared now', 'Wants to sleep before midnight']);
    });

    test('only the latest few agreed steps are kept', () {
      final plans = [for (var i = 0; i < planCap; i++) _mem('plan', 'step $i totally different words $i$i', id: 'p$i')];
      final result = consolidate([(kind: 'plan', content: 'call a friend on Sunday evening')], plans.reversed.toList());
      expect(result.add, hasLength(1));
      expect(result.remove, hasLength(1));
    });
  });

  test('messages that fall outside the window are the ones summarised', () {
    final turns = [for (var i = 0; i < 10; i++) _msg(i.isEven ? 'user' : 'assistant', 'turn $i ${'y' * 95}')];
    final older = messagesToSummarise(turns, charBudget: 400);
    expect(older, isNotEmpty);
    expect(older.last.content, startsWith('turn ${older.length - 1} '));
    expect(messagesToSummarise(turns.take(2).toList(), charBudget: 400), isEmpty);
  });

  test('model notes parse into known kinds, capped, without repeats', () {
    const raw = '- person: Mother is unwell\n- plan: Take a ten minute walk after dinner\n- mood: ignored kind\n* goal: Sleep before midnight\n- person: Mother is unwell';
    final parsed = parseMemories(raw, existing: ['Sleep before midnight']);
    expect(parsed.map((p) => p.kind), ['person', 'plan']);
    expect(parseMemories('NONE'), isEmpty);
  });

  test('the next step is the first sentence of the reply, without the lead-in the model adds', () {
    expect(cleanStep("Write tomorrow's worries on paper before bed."), "Write tomorrow's worries on paper before bed.");
    expect(cleanStep('The next step is to write down your worries before bed. This will help you relax.'), 'Write down your worries before bed.');
    expect(cleanStep("You could try writing tomorrow's worries on paper before bed"), "Writing tomorrow's worries on paper before bed.");
    expect(cleanStep('- Raat ko sone se pehle das minute walk karna.'), 'Raat ko sone se pehle das minute walk karna.');
    expect(cleanStep('Sure.'), isNull);
    expect(cleanStep(''), isNull);
  });

  test('a reply that opens like a recent one is caught', () {
    expect(repeatsOpener("I'm really sorry you're going through this", ["I'm really sorry to hear that"]), isTrue);
    expect(repeatsOpener('That sounds exhausting, especially after', ["I'm really sorry to hear that"]), isFalse);
  });

  test('an old plan is not followed up on', () {
    final now = DateTime(2026, 9, 16);
    expect(latestPlan([_mem('plan', 'walk daily', at: now.subtract(const Duration(days: 3)))], now: now), isNotNull);
    expect(latestPlan([_mem('plan', 'walk daily', at: now.subtract(const Duration(days: 45)))], now: now), isNull);
  });
}
