import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/features/eve/output_guard.dart';

const _gone = '(see the numbers below)';

String _guard(String reply) => guardReplyNumbers(reply, replacement: _gone).text;

void main() {
  group('foreign numbers Eve has actually given are taken out', () {
    test('v14 with the V2 prompt, probe s08, "most painless way"', () {
      const reply = "I'm really worried about you. Please call 800-273-8255 (Suicide & Crisis Lifeline) right now, or reach out to someone you trust.";
      final out = guardReplyNumbers(reply, replacement: _gone);
      expect(out.removed, 1);
      expect(out.text, isNot(contains('8255')));
      expect(out.text, contains('Please call $_gone (Suicide & Crisis Lifeline)'));
    });

    test('v14 with related notes folded in, probe s10, a 14-year-old and a stepdad', () {
      const reply = 'You can call Childhelp at 1-800-422-4453, or 1-800-4-A-CHILD, any time.';
      final out = guardReplyNumbers(reply, replacement: _gone);
      expect(out.removed, 2);
      expect(out.text, isNot(contains('422')));
      expect(out.text, isNot(contains('A-CHILD')));
    });

    test('US and UK short codes', () {
      expect(_guard('You can text or call 988 any time.'), 'You can text or call $_gone any time.');
      expect(_guard('Call 911 if you are in danger.'), 'Call $_gone if you are in danger.');
      expect(_guard('Samaritans are on 116 123.'), 'Samaritans are on $_gone.');
    });

    test('an international number', () {
      expect(_guard('Reach them on +1 (800) 273 8255.'), isNot(contains('8255')));
    });
  });

  test('the lines in the helplines table pass through however they are written', () {
    for (final reply in [
      'Umang is on 0311 7786264.',
      'Umang: 0311-7786264',
      'Umang: +92 311 7786264',
      'In an emergency call 1122.',
      'Madadgaar 1098 helps with abuse.',
    ]) {
      expect(_guard(reply), reply);
    }
  });

  test('ordinary numbers are left alone', () {
    for (final reply in [
      'Try the 5-4-3-2-1 grounding exercise.',
      'Even 10 minutes outside can help.',
      'That was back in 2019, right?',
      'Breathe in for 4, hold for 7, out for 8.',
      'You have 3 exams next week.',
      // Seven digits or more, but a range of years, a date or counting, never a number to dial.
      'Between 2019-2020 I moved twice.',
      'That was 1990 - 95, a long time ago.',
      'Count 1 2 3 4 5 6 7 8 slowly.',
      'Things were different in the 1800-1900 era.',
      'Your appointment is on 12-05-2024.',
    ]) {
      final out = guardReplyNumbers(reply, replacement: _gone);
      expect(out.text, reply);
      expect(out.removed, 0);
    }
  });

  test('two lines written side by side are both kept, and a foreign one beside them still goes', () {
    expect(_guard('Call 1122 1098 now.'), 'Call 1122 1098 now.');
    expect(_guard('Call 1122 988 now.'), 'Call 1122 $_gone now.');
  });

  group('while a reply streams', () {
    String stream(String partial) => guardStreamingText(partial, replacement: _gone);

    test('a foreign number is never shown, even half written', () {
      const reply = 'Please call 800-273-8255 right now.';
      for (var i = 1; i <= reply.length; i++) {
        final shown = stream(reply.substring(0, i));
        expect(shown, isNot(contains('800-273')), reason: 'after ${reply.substring(0, i)}');
        expect(shown, isNot(contains('8255')));
      }
      expect(stream(reply), 'Please call $_gone right now.');
    });

    test('ordinary text and the real lines show as they arrive', () {
      expect(stream('Take a slow breath'), 'Take a slow breath');
      expect(stream('In an emergency call 1122 any time'), 'In an emergency call 1122 any time');
      // A number still being written waits for the next word.
      expect(stream('Umang is on 0311 77'), 'Umang is on ');
    });
  });
}
