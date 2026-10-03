import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/core/ml/onnx_guardian.dart' show union;
import 'package:therapylink/features/eve/crisis_mode.dart';

import 'crisis_fakes.dart';

/// Stands in for the trained model, which keys on the words: any "suicid" or "kill myself" is a crisis.
class _WordsGuardian implements Guardian {
  final seen = <String>[];
  @override
  Future<GuardianVerdict> classify(String text) async {
    seen.add(text);
    final hit = RegExp(r'suicid|kill myself|hurt myself|want to die', caseSensitive: false).hasMatch(text);
    return hit ? const GuardianVerdict(crisis: true, crisisScores: {'suicidal': 0.9}, valence: -2, kind: CrisisKind.suicide) : GuardianVerdict.none;
  }
}

void main() {
  final guardian = NegationAwareGuardian(UnionOfWordsAndKeywords());

  group('a person ruling a danger out is not a crisis', () {
    for (final text in [
      'I am not suicidal',
      "I'm not suicidal",
      "no, I'm not going to hurt myself, I am safe",
      'I would never kill myself',
      "I don't want to die",
      'I am not thinking about suicide, just tired',
      "I'm not planning to end my life",
      'main suicidal nahi hun',
      'khudkushi ka koi irada nahi hai',
      'mujhe marna nahi chahta',
      'میں خودکشی نہیں کر رہا',
    ]) {
      test(text, () async => expect((await guardian.classify(text)).crisis, isFalse));
    }
  });

  group('what is still a crisis', () {
    for (final text in [
      "I'm not suicidal but I want to die tonight",
      "I can't stop thinking about suicide",
      "I wasn't suicidal until last week",
      "I don't want to die but I don't want to live like this",
      "I'm not okay, I want to kill myself",
      'I am not going to lie, I want to end my life',
      "I don't know if I'm suicidal",
      'I want to die',
      'main suicidal hun',
    ]) {
      test(text, () async => expect((await guardian.classify(text)).crisis, isTrue));
    }
  });

  test('only the part left after the denial is read', () async {
    final inner = _WordsGuardian();
    await NegationAwareGuardian(inner).classify("I'm not suicidal. Work has been heavy.");
    expect(inner.seen.single, isNot(contains('suicid')));
    expect(inner.seen.single, contains('Work has been heavy'));
  });

  test('a message with no denial goes through untouched', () async {
    final inner = _WordsGuardian();
    await NegationAwareGuardian(inner).classify('hello there');
    expect(inner.seen.single, 'hello there');
  });

  group('in the conversation', () {
    int inAnHour() => DateTime.now().add(const Duration(minutes: 40)).millisecondsSinceEpoch;

    test('a crisis does not make every later message a crisis', () async {
      final h = await Harness.create();
      addTearDown(h.dispose);

      await h.eve.send('CRISIS: I want to end it');
      await h.eve.send('thank you for listening'); // the turn after still counts as part of it
      await h.eve.send('I feel a bit calmer');
      await h.eve.send('work has been a lot');

      // The old read joined the flagged messages back in each time, so every message after the first
      // was flagged and Eve was never asked.
      final rows = await h.messages();
      final users = rows.where((m) => m.role == 'user').toList();
      expect(users.map((m) => m.flagged), [true, true, false, false]);
      expect(rows.where((m) => m.role == 'assistant'), hasLength(2));
    });

    test('saying you are not suicidal after a flag ends crisis mode and the repeated cards', () async {
      final h = await Harness.create(prefs: {'eveCrisisActiveUntil': inAnHour(), 'eveCrisisKind': 'suicidal'});
      addTearDown(h.dispose);

      await h.eve.send("No, I'm not suicidal, just a bad week");
      await h.eve.send('work has been a lot');

      expect(h.container.read(crisisModeProvider).active, isFalse);
      expect(h.prefs.getInt('eveCrisisActiveUntil'), isNull);
      final rows = await h.messages();
      expect(rows.map((m) => m.role), ['user', 'assistant', 'user', 'assistant']);
    });

    test('a denial of suicide does not end crisis mode raised for an overdose', () async {
      final h = await Harness.create(prefs: {'eveCrisisActiveUntil': inAnHour(), 'eveCrisisKind': 'medical'});
      addTearDown(h.dispose);

      await h.eve.send("I'm not suicidal");

      expect(h.container.read(crisisModeProvider).active, isTrue);
    });

    test('a denial that also raises a flag keeps crisis mode on', () async {
      final h = await Harness.create(prefs: {'eveCrisisActiveUntil': inAnHour(), 'eveCrisisKind': 'suicidal'});
      addTearDown(h.dispose);

      await h.eve.send("I'm not suicidal but CRISIS I have the pills");

      expect(h.container.read(crisisModeProvider).active, isTrue);
      expect(h.engine.replies, isEmpty);
    });
  });
}

/// The keyword floor and a words-only model together, as the app runs them, under the same denial reading.
class UnionOfWordsAndKeywords implements Guardian {
  final _model = _WordsGuardian();
  final _keywords = HeuristicGuardian();

  @override
  Future<GuardianVerdict> classify(String text) async => union(await _keywords.classify(text), await _model.classify(text));
}
