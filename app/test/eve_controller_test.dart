import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/guardian.dart';

/// The grounding nudge is driven by Guardian's valence, so these pin down the classifier
/// behaviour the nudge depends on rather than the Riverpod plumbing around it.
void main() {
  final guardian = HeuristicGuardian();

  test('sustained low language reads as low valence', () async {
    for (final text in [
      'i feel so hopeless and tired of everything',
      'everything is heavy and i am lonely',
      'udaas hoon aur bohat pareshan',
    ]) {
      final v = await guardian.classify(text);
      expect(v.crisis, isFalse, reason: text);
      expect(v.valence, lessThanOrEqualTo(-1), reason: text);
    }
  });

  test('a crisis message is never merely low — it routes to the crisis path', () async {
    final v = await guardian.classify('i want to die tonight');
    expect(v.crisis, isTrue);
  });

  test('neutral chatter does not register as low', () async {
    final v = await guardian.classify('i went to the shop and bought bread');
    expect(v.valence, greaterThanOrEqualTo(0));
  });

  test('valence stays inside the scale the mood chart draws', () async {
    for (final text in [
      'sad sad sad depressed hopeless lonely anxious miserable',
      'happy grateful calm proud excited relieved khush sukoon',
    ]) {
      final v = await guardian.classify(text);
      expect(v.valence, inInclusiveRange(-2, 2), reason: text);
    }
  });
}
