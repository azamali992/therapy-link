import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/db/database.dart';
import '../../ui/components/week_trend.dart';
import '../shared/mood_chart.dart';
import 'insights.dart';

final assessmentsProvider =
    FutureProvider<List<Assessment>>((ref) => ref.watch(apiClientProvider).assessments());

/// Mood trend from the device's own queue — works offline and needs no server round-trip.
final localMoodTrendProvider = FutureProvider<List<MoodPoint>>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 30));
  final rows = await ref.watch(databaseProvider).localMoodSince(since);
  final byDay = <DateTime, List<int>>{};
  for (final r in rows) {
    final d = DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day);
    byDay.putIfAbsent(d, () => []).add(r.valence);
  }
  return [
    for (final e in byDay.entries)
      MoodPoint(e.key, e.value.reduce((a, b) => a + b) / e.value.length)
  ];
});

/// Computed on the device from the local mood queue — the raw readings never leave the phone.
final moodInsightProvider = FutureProvider<MoodInsight>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 30));
  final rows = await ref.watch(databaseProvider).localMoodSince(since);
  return findInsight(
      [for (final r in rows) MoodSample(r.recordedAt, r.valence)]);
});

/// 7-day rolling trend ending today, ready for [WeekTrend].
///
/// DB valence is -2..+2; picker/WeekDay valence is 0..4 (adds 2).
final weekTrendProvider = FutureProvider<List<WeekDay>>((ref) async {
  final now = DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);
  final firstDay = todayDate.subtract(const Duration(days: 6));

  final rows = await ref.watch(databaseProvider).localMoodSince(firstDay);

  // Average valence per day, converted to 0..4 picker scale.
  final byDay = <DateTime, List<int>>{};
  for (final r in rows) {
    final d =
        DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day);
    byDay.putIfAbsent(d, () => []).add(r.valence + 2);
  }

  // Single letters M T W T F S S (weekday 1=Mon .. 7=Sun).
  const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  return List.generate(7, (i) {
    final day = firstDay.add(Duration(days: i));
    final isToday = day == todayDate;
    final entries = byDay[day];
    final avgValence = entries == null
        ? null
        : (entries.reduce((a, b) => a + b) / entries.length)
            .round()
            .clamp(0, 4);
    return WeekDay(
      label: dayLetters[day.weekday - 1],
      isToday: isToday,
      valence: avgValence,
    );
  });
});

/// Today's check-in in picker scale (0..4), or null if nothing logged yet today.
final todayMoodProvider = FutureProvider<int?>((ref) async {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final rows = await ref.watch(databaseProvider).localMoodSince(todayStart);
  if (rows.isEmpty) return null;
  final sum = rows.map((r) => r.valence).reduce((a, b) => a + b);
  return (sum / rows.length + 2).round().clamp(0, 4);
});

/// Total individual check-ins in the last 90 days. Used to decide when to hide
/// the mood-scale hint ("Empty moon: hardest / Full: best").
final moodCheckInCountProvider = FutureProvider<int>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 90));
  final rows = await ref.watch(databaseProvider).localMoodSince(since);
  return rows.length;
});

Future<void> recordManualMood(WidgetRef ref, int valence) async {
  final db = ref.read(databaseProvider);
  await db.queueMood(valence: valence, source: 'manual');
  ref.invalidate(localMoodTrendProvider);
  ref.invalidate(moodInsightProvider);
  ref.invalidate(weekTrendProvider);
  ref.invalidate(todayMoodProvider);
  ref.invalidate(moodCheckInCountProvider);
  try {
    final pending = await db.pendingMood();
    await ref
        .read(apiClientProvider)
        .uploadMood([for (final p in pending) moodUploadOf(p)]);
    await db.markUploaded(pending.map((p) => p.id));
  } catch (_) {
    // Offline is normal here; the queue keeps the reading and the next upload picks it up.
  }
}
