/// Exercises that run inside the chat.
///
/// Each one is stored as a message with role [exerciseRole]; its content is the exercise id, with
/// ':done' appended once finished, so a card reopens in the right state. These rows are never sent
/// to the model — the history builder only forwards user and assistant turns.
const exerciseRole = 'exercise';

const breathingExerciseIds = ['sigh', 'box', 'calming'];
const groundingExerciseId = 'ground';
const muscleExerciseId = 'muscle';
const exerciseIds = [...breathingExerciseIds, groundingExerciseId, muscleExerciseId];

({String id, bool done}) parseExercise(String content) {
  final done = content.endsWith(':done');
  return (id: done ? content.substring(0, content.length - 5) : content, done: done);
}

String exerciseContent(String id, {bool done = false}) => done ? '$id:done' : id;

/// Does an Eve reply offer an exercise? When it does, the chat shows a "try it here" action under
/// the bubble instead of leaving the person to find the Today tab.
final _offerPattern = RegExp(
  r'\b(breath|breathe|breathing|saans|ground(ing)?|5-4-3-2-1|relax(ation)?|tense and release|muscle)',
  caseSensitive: false,
);
bool mentionsExercise(String reply) => _offerPattern.hasMatch(reply);

/// One muscle group: squeeze for [tense] seconds, let go for [release]. Pure for tests.
class MuscleSchedule {
  static const groups = 7;
  static const tense = 5;
  static const release = 10;
  static const groupSeconds = tense + release;
  static const totalSeconds = groups * groupSeconds;

  /// (group index, tensing?, seconds left in this phase) at [elapsed].
  static ({int group, bool tensing, int remaining}) at(int elapsed) {
    final clamped = elapsed.clamp(0, totalSeconds - 1);
    final group = clamped ~/ groupSeconds;
    final inGroup = clamped % groupSeconds;
    final tensing = inGroup < tense;
    final remaining = tensing ? tense - inGroup : groupSeconds - inGroup;
    return (group: group, tensing: tensing, remaining: remaining);
  }
}

/// Pure walk through the 5-4-3-2-1 grounding steps.
class GroundingSteps {
  static const counts = [5, 4, 3, 2, 1];
}
