import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/features/eve/exercise_cards.dart';

void main() {
  test('exercise messages round-trip their id and completion', () {
    expect(parseExercise('sigh'), (id: 'sigh', done: false));
    expect(parseExercise(exerciseContent('ground', done: true)), (id: 'ground', done: true));
    for (final id in exerciseIds) {
      expect(parseExercise(exerciseContent(id)).id, id);
    }
  });

  test('an Eve reply that offers breathing or grounding gets a try-it-here action', () {
    expect(mentionsExercise('Would you like to try a short breathing exercise with me?'), isTrue);
    expect(mentionsExercise('Kya aap ek lambi saans lena chahenge?'), isTrue);
    expect(mentionsExercise('That sounds really hard. What happened at work?'), isFalse);
  });

  test('tense-and-release schedule covers seven groups, squeeze then release', () {
    expect(MuscleSchedule.totalSeconds, 7 * 15);
    expect(MuscleSchedule.at(0), (group: 0, tensing: true, remaining: 5));
    expect(MuscleSchedule.at(4), (group: 0, tensing: true, remaining: 1));
    expect(MuscleSchedule.at(5), (group: 0, tensing: false, remaining: 10));
    expect(MuscleSchedule.at(15), (group: 1, tensing: true, remaining: 5));
    expect(MuscleSchedule.at(MuscleSchedule.totalSeconds - 1).group, 6);
    // Never indexes past the last group, even if the timer overshoots.
    expect(MuscleSchedule.at(MuscleSchedule.totalSeconds + 30).group, 6);
  });
}
