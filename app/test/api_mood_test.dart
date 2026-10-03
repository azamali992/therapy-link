import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/api/api_client.dart';
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/core/api/time_zone.dart';
import 'package:therapylink/core/db/database.dart';

import 'api_harness.dart';

void main() {
  group('mood upload', () {
    test('1,203 queued points go as 500, 500 and 203, each with a client_id, and the replies are summed', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      for (var i = 0; i < 1203; i++) {
        await db.queueMood(valence: i % 5 - 2, source: 'manual');
      }
      final pending = await db.pendingMood();
      expect(pending, hasLength(1203));

      final dio = fakeDio((o) {
        final n = (o.data as List).length;
        // Pretend the server already had the first three points of each batch.
        return reply(201, {'accepted': n - 3, 'duplicates': 3});
      });
      final result = await ApiClient(dio, timeZone: () => 'Asia/Karachi').uploadMood([for (final p in pending) moodUploadOf(p)]);

      final posts = adapterOf(dio).requests;
      expect(posts.map((o) => o.method), everyElement('POST'));
      expect(posts.map((o) => o.path), everyElement('/mood/batch'));
      expect(posts.map((o) => (o.data as List).length), [500, 500, 203]);
      final ids = [
        for (final o in posts)
          for (final p in (o.data as List).cast<Map<String, dynamic>>()) p['client_id'] as String?,
      ];
      expect(ids, hasLength(1203));
      expect(ids, everyElement(isA<String>().having((s) => s.length, 'length', inInclusiveRange(1, 64))));
      expect(ids.toSet(), hasLength(1203), reason: 'every queued row has its own id');
      expect(result.accepted, 1203 - 9);
      expect(result.duplicates, 9);
    });

    test('an empty queue sends nothing', () async {
      final dio = fakeDio((_) => reply(201, {'accepted': 0, 'duplicates': 0}));
      final result = await ApiClient(dio).uploadMood(const []);
      expect(adapterOf(dio).requests, isEmpty);
      expect(result.accepted, 0);
    });

    test('the client id is the row id plus its timestamp, stable for a row and new for a recreated database', () {
      final at = DateTime.utc(2026, 9, 25, 1, 30);
      expect(moodClientId(7, at), moodClientId(7, at));
      expect(moodClientId(7, at), isNot(moodClientId(7, at.add(const Duration(seconds: 1)))));
      final json = MoodPointUpload(valence: 1, source: 'manual', recordedAt: at, clientId: moodClientId(7, at)).toJson();
      expect(json['client_id'], '7-${at.millisecondsSinceEpoch}');
      expect(MoodPointUpload(valence: 1, source: 'manual', recordedAt: at).toJson().containsKey('client_id'), isFalse);
    });
  });

  group('time zone', () {
    test('moodTrend and patientOverview send the device zone as tz', () async {
      final dio = fakeDio((o) => o.path == '/mood/trend'
          ? reply(200, [])
          : reply(200, {
              'patient': {'uid': 'p1', 'role': 'patient', 'locale': 'en'},
              'consent': {'id': 'l1', 'patient_uid': 'p1', 'clinician_uid': 'c1', 'status': 'active'},
            }));
      final api = ApiClient(dio, timeZone: () => 'Asia/Karachi');
      await api.moodTrend(days: 14);
      await api.patientOverview('p1');
      final reqs = adapterOf(dio).requests;
      expect(reqs[0].queryParameters, {'days': 14, 'tz': 'Asia/Karachi'});
      expect(reqs[1].path, '/clinician/patients/p1');
      expect(reqs[1].queryParameters['tz'], 'Asia/Karachi');
    });

    test('offsets map to IANA zones the server accepts', () {
      expect(zoneForOffset(const Duration(hours: 5)), 'Asia/Karachi');
      expect(zoneForOffset(const Duration(hours: 5, minutes: 30)), 'Asia/Kolkata');
      expect(zoneForOffset(Duration.zero), 'UTC');
      expect(zoneForOffset(const Duration(hours: 1)), 'Etc/GMT-1');
      expect(zoneForOffset(const Duration(hours: -5)), 'Etc/GMT+5');
      expect(zoneForOffset(const Duration(hours: 9, minutes: 30)), 'UTC');
      expect(deviceTimeZone(), isNotEmpty);
    });
  });
}
