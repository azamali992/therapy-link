import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/core/ml/eve_engine.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/features/assessments/assessment_items.dart';

void main() {
  group('prompt folding', () {
    test('prepends the system prompt to the first user turn only', () {
      final out = foldSystemIntoFirstUser([
        {'role': 'user', 'content': 'hi'},
        {'role': 'assistant', 'content': 'hello'},
        {'role': 'user', 'content': 'again'},
      ]);
      expect(out.first['content'], startsWith(eveSystemPrompt));
      expect(out.first['content'], endsWith('\n\nhi'));
      expect(out[1], {'role': 'assistant', 'content': 'hello'});
      expect(out[2]['content'], 'again');
    });

    test('rejects a conversation that does not start with the user', () {
      expect(() => foldSystemIntoFirstUser([{'role': 'assistant', 'content': 'x'}]), throwsArgumentError);
    });
  });

  group('heuristic guardian', () {
    final g = HeuristicGuardian();

    test('flags explicit risk in English and Roman Urdu', () async {
      expect((await g.classify("I don't want to wake up tomorrow, I want to die")).crisis, isTrue);
      expect((await g.classify('bas ab jeena nahi chahta')).crisis, isTrue);
    });

    test('does not flag ordinary stress', () async {
      final v = await g.classify('exams are killing me, so tired of this week');
      expect(v.crisis, isFalse);
      expect(v.valence, lessThan(0));
    });

    test('positive language lifts valence', () async {
      expect((await g.classify('honestly feeling grateful and calm today')).valence, greaterThan(0));
    });
  });

  group('assessment items', () {
    test('PHQ-9 and GAD-7 have the right item counts in both languages', () {
      expect(assessmentItems(Instrument.phq9, 'en').length, 9);
      expect(assessmentItems(Instrument.phq9, 'ur').length, 9);
      expect(assessmentItems(Instrument.gad7, 'en').length, 7);
      expect(assessmentItems(Instrument.gad7, 'ur').length, 7);
      expect(assessmentMax(Instrument.phq9), 27);
      expect(assessmentMax(Instrument.gad7), 21);
    });
  });

  group('server Eve engine', () {
    test('eveUnderstandsNotes is true (v16-clean was trained on memory notes)', () {
      expect(eveUnderstandsNotes, isTrue);
    });

    test('eveSystemPrompt is the v2 psychologist prompt', () {
      // Must match ml/therapylink_ml/prompts.py SERVED_SYSTEM_PROMPT exactly.
      expect(eveSystemPrompt, isNotEmpty);
      expect(eveSystemPrompt, contains('Work like a good psychologist'));
      expect(eveSystemPrompt, contains('Umang'));
      expect(eveSystemPrompt, contains('Rescue 1122'));
    });

    test('StubEveEngine is ready and replies immediately for tests', () async {
      final engine = StubEveEngine();
      expect(await engine.isReady, isTrue);
      final tokens = await engine.reply([{'role': 'user', 'content': 'hi'}]).toList();
      expect(tokens.join(), isNotEmpty);
    });

    test('foldSystemIntoFirstUser injects notes after the system prompt', () {
      const notes = '[Memory]\nUser likes hiking.';
      final out = foldSystemIntoFirstUser(
        [{'role': 'user', 'content': 'hello'}],
        notes: notes,
      );
      expect(out.first['content'], contains(eveSystemPrompt));
      expect(out.first['content'], contains(notes));
      expect(out.first['content'], contains('hello'));
    });
  });
}
