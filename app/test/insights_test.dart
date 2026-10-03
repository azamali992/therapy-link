import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/features/today/insights.dart';

DateTime _at(int daysAgo, int hour) =>
    DateTime(2026, 9, 15, hour).subtract(Duration(days: daysAgo));

List<MoodSample> _samples(int count, {required int hour, required int valence, int startDaysAgo = 0}) =>
    [for (var i = 0; i < count; i++) MoodSample(_at(startDaysAgo + i, hour), valence)];

void main() {
  final now = DateTime(2026, 9, 15, 20);

  group('refuses to invent patterns', () {
    test('says nothing with almost no data', () {
      expect(findInsight([], now: now).kind, InsightKind.notEnoughData);
      expect(findInsight(_samples(3, hour: 9, valence: 2), now: now).kind, InsightKind.notEnoughData);
    });

    test('says nothing when one group is under the sample floor', () {
      // 8 mornings but only 3 evenings — not enough evenings to compare against.
      final s = [..._samples(8, hour: 9, valence: 2), ..._samples(3, hour: 20, valence: -2)];
      expect(findInsight(s, now: now).kind, InsightKind.notEnoughData);
    });

    test('says nothing when the difference is too small to mean anything', () {
      final s = [
        ..._samples(6, hour: 9, valence: 1),
        ..._samples(6, hour: 20, valence: 1, startDaysAgo: 6),
      ];
      expect(findInsight(s, now: now).kind, InsightKind.notEnoughData);
    });
  });

  group('time of day', () {
    test('reports a real morning/evening gap', () {
      final s = [
        ..._samples(6, hour: 9, valence: 2),
        ..._samples(6, hour: 21, valence: -1, startDaysAgo: 6),
      ];
      final i = findInsight(s, now: now);
      expect(i.kind, InsightKind.timeOfDay);
      expect(i.betterLabel, 'morning');
      expect(i.worseLabel, 'evening');
      expect(i.delta, greaterThanOrEqualTo(0.6));
      expect(i.samples, 12);
    });

    test('names the right direction when evenings are the better ones', () {
      final s = [
        ..._samples(6, hour: 8, valence: -2),
        ..._samples(6, hour: 19, valence: 1, startDaysAgo: 6),
      ];
      final i = findInsight(s, now: now);
      expect(i.betterLabel, 'evening');
      expect(i.worseLabel, 'morning');
    });
  });

  group('week over week', () {
    test('spots a lift against the previous week', () {
      final s = [
        for (var d = 0; d < 6; d++) MoodSample(_at(d, 14), 2),
        for (var d = 8; d < 14; d++) MoodSample(_at(d, 14), -1),
      ];
      final i = findInsight(s, now: now);
      expect(i.kind, InsightKind.weekOverWeek);
      expect(i.betterLabel, 'up');
    });

    test('spots a decline too', () {
      final s = [
        for (var d = 0; d < 6; d++) MoodSample(_at(d, 14), -2),
        for (var d = 8; d < 14; d++) MoodSample(_at(d, 14), 1),
      ];
      expect(findInsight(s, now: now).betterLabel, 'down');
    });
  });

  test('day parts split at noon and 5pm', () {
    expect(dayPartOf(DateTime(2026, 9, 15, 11, 59)), DayPart.morning);
    expect(dayPartOf(DateTime(2026, 9, 15, 12)), DayPart.afternoon);
    expect(dayPartOf(DateTime(2026, 9, 15, 16, 59)), DayPart.afternoon);
    expect(dayPartOf(DateTime(2026, 9, 15, 17)), DayPart.evening);
  });

  test('returns only the strongest finding, never a list', () {
    final s = [
      ..._samples(6, hour: 9, valence: 2),
      ..._samples(6, hour: 21, valence: -2, startDaysAgo: 6),
    ];
    final i = findInsight(s, now: now);
    expect(i.kind, isNot(InsightKind.notEnoughData));
    expect(i.delta, isNotNull);
  });
}
