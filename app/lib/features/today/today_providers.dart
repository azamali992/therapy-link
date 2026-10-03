import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/db/database.dart';
import '../shared/mood_chart.dart';
import 'insights.dart';

final assessmentsProvider = FutureProvider<List<Assessment>>((ref) => ref.watch(apiClientProvider).assessments());

/// Mood trend from the device's own queue — works offline and needs no server round-trip.
final localMoodTrendProvider = FutureProvider<List<MoodPoint>>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 30));
  final rows = await ref.watch(databaseProvider).localMoodSince(since);
  final byDay = <DateTime, List<int>>{};
  for (final r in rows) {
    final d = DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day);
    byDay.putIfAbsent(d, () => []).add(r.valence);
  }
  return [for (final e in byDay.entries) MoodPoint(e.key, e.value.reduce((a, b) => a + b) / e.value.length)];
});

/// Computed on the device from the local mood queue — the raw readings never leave the phone.
final moodInsightProvider = FutureProvider<MoodInsight>((ref) async {
  final since = DateTime.now().subtract(const Duration(days: 30));
  final rows = await ref.watch(databaseProvider).localMoodSince(since);
  return findInsight([for (final r in rows) MoodSample(r.recordedAt, r.valence)]);
});

Future<void> recordManualMood(WidgetRef ref, int valence) async {
  final db = ref.read(databaseProvider);
  await db.queueMood(valence: valence, source: 'manual');
  ref.invalidate(localMoodTrendProvider);
  ref.invalidate(moodInsightProvider);
  try {
    final pending = await db.pendingMood();
    await ref.read(apiClientProvider).uploadMood([for (final p in pending) moodUploadOf(p)]);
    await db.markUploaded(pending.map((p) => p.id));
  } catch (_) {
    // Offline is normal here; the queue keeps the reading and the next upload picks it up.
  }
}
