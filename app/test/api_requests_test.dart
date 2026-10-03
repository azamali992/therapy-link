// Tests for the care link request models and CareLink JSON parsing.
// The clinician RequestsScreen is a v3 forward (not yet built), so these
// tests focus on the shared model layer that both patient and clinician views use.

import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/api/models.dart';

CareLink _careLink(String id, String status, {bool shareAssessments = false}) =>
    CareLink.fromJson({
      'id': id,
      'patient_uid': 'p1',
      'clinician_uid': 'c1',
      'status': status,
      'share_assessments': shareAssessments,
      'share_mood_trend': false,
      'share_summaries': false,
      'share_journal': false,
    });

LinkRequest _request(String id, String name) => LinkRequest.fromJson({
  'link_id': id,
  'patient': {'uid': 'p-$id', 'display_name': name, 'role': 'patient', 'locale': 'en', 'clinician_verified': false},
  'requested_at': '2026-09-20T10:00:00Z',
});

void main() {
  group('LinkRequest', () {
    test('parses the patient and when they asked', () {
      final r = _request('l1', 'Ayesha');
      expect(r.linkId, 'l1');
      expect(r.patient.displayName, 'Ayesha');
      expect(r.patient.uid, 'p-l1');
      expect(r.requestedAt, isNotNull);
    });

    test('requestedAt is null when absent', () {
      final r = LinkRequest.fromJson({
        'link_id': 'l2',
        'patient': {'uid': 'p2', 'role': 'patient', 'locale': 'en', 'clinician_verified': false},
      });
      expect(r.requestedAt, isNull);
    });
  });

  group('CareLink', () {
    test('parses status correctly', () {
      expect(_careLink('a', 'pending').status, LinkStatus.pending);
      expect(_careLink('b', 'active').status, LinkStatus.active);
      expect(_careLink('c', 'revoked').status, LinkStatus.revoked);
    });

    test('unknown status falls back to pending', () {
      expect(_careLink('d', 'unknown').status, LinkStatus.pending);
    });

    test('share flags default to false', () {
      final link = _careLink('a', 'active');
      expect(link.shareAssessments, isFalse);
      expect(link.shareMoodTrend, isFalse);
      expect(link.shareJournal, isFalse);
    });

    test('share flags respect the server values', () {
      expect(_careLink('a', 'active', shareAssessments: true).shareAssessments, isTrue);
    });

    test('clinician name parsed from clinician_name or nested clinician object', () {
      final flat = CareLink.fromJson({
        'id': 'l1', 'patient_uid': 'p1', 'clinician_uid': 'c1', 'status': 'active',
        'clinician_name': 'Dr Sana',
        'share_assessments': false, 'share_mood_trend': false, 'share_summaries': false, 'share_journal': false,
      });
      expect(flat.clinicianName, 'Dr Sana');

      final nested = CareLink.fromJson({
        'id': 'l2', 'patient_uid': 'p1', 'clinician_uid': 'c1', 'status': 'active',
        'clinician': {'display_name': 'Dr Ahmed', 'clinician_verified': true},
        'share_assessments': false, 'share_mood_trend': false, 'share_summaries': false, 'share_journal': false,
      });
      expect(nested.clinicianName, 'Dr Ahmed');
      expect(nested.clinicianVerified, isTrue);
    });

    test('blank clinician name is treated as absent', () {
      final link = CareLink.fromJson({
        'id': 'l1', 'patient_uid': 'p1', 'clinician_uid': 'c1', 'status': 'active',
        'clinician_name': '   ',
        'share_assessments': false, 'share_mood_trend': false, 'share_summaries': false, 'share_journal': false,
      });
      expect(link.clinicianName, isNull);
    });
  });
}
