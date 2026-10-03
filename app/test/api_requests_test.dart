// Tests for the care link request models and the wired RequestsScreen.
// Model tests ported from the original v3 stub; widget tests restored from
// v2 api_requests_test.dart and adapted for the v3 provider model.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/api/api_client.dart';
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/features/clinician/requests_screen.dart';

import 'platform_harness.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

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
      'patient': {
        'uid': 'p-$id',
        'display_name': name,
        'role': 'patient',
        'locale': 'en',
        'clinician_verified': false,
      },
      'requested_at': '2026-09-20T10:00:00Z',
    });

/// Fake ApiClient that tracks accept/decline calls and mutates its own list.
class _FakeApi extends ApiClient {
  _FakeApi(List<LinkRequest> initial)
      : _pending = List.of(initial),
        super(Dio());

  final List<LinkRequest> _pending;
  final accepted = <String>[];
  final declined = <String>[];

  @override
  Future<List<LinkRequest>> clinicianRequests() async => List.of(_pending);

  @override
  Future<CareLink> acceptRequest(String linkId) async {
    accepted.add(linkId);
    _pending.removeWhere((r) => r.linkId == linkId);
    return _careLink(linkId, 'active');
  }

  @override
  Future<CareLink> declineRequest(String linkId) async {
    declined.add(linkId);
    _pending.removeWhere((r) => r.linkId == linkId);
    return _careLink(linkId, 'revoked');
  }
}

// ── Model tests ────────────────────────────────────────────────────────────

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
        'patient': {
          'uid': 'p2',
          'role': 'patient',
          'locale': 'en',
          'clinician_verified': false
        },
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
      expect(
          _careLink('a', 'active', shareAssessments: true).shareAssessments,
          isTrue);
    });

    test('clinician name parsed from clinician_name or nested clinician object',
        () {
      final flat = CareLink.fromJson({
        'id': 'l1',
        'patient_uid': 'p1',
        'clinician_uid': 'c1',
        'status': 'active',
        'clinician_name': 'Dr Sana',
        'share_assessments': false,
        'share_mood_trend': false,
        'share_summaries': false,
        'share_journal': false,
      });
      expect(flat.clinicianName, 'Dr Sana');

      final nested = CareLink.fromJson({
        'id': 'l2',
        'patient_uid': 'p1',
        'clinician_uid': 'c1',
        'status': 'active',
        'clinician': {'display_name': 'Dr Ahmed', 'clinician_verified': true},
        'share_assessments': false,
        'share_mood_trend': false,
        'share_summaries': false,
        'share_journal': false,
      });
      expect(nested.clinicianName, 'Dr Ahmed');
      expect(nested.clinicianVerified, isTrue);
    });

    test('blank clinician name is treated as absent', () {
      final link = CareLink.fromJson({
        'id': 'l1',
        'patient_uid': 'p1',
        'clinician_uid': 'c1',
        'status': 'active',
        'clinician_name': '   ',
        'share_assessments': false,
        'share_mood_trend': false,
        'share_summaries': false,
        'share_journal': false,
      });
      expect(link.clinicianName, isNull);
    });
  });

  // ── Widget tests ──────────────────────────────────────────────────────────

  group('requests screen', () {
    Future<_FakeApi> pump(
        WidgetTester tester, List<LinkRequest> initial) async {
      tester.view.physicalSize = const Size(720, 1520);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = _FakeApi(initial);
      await pumpApp(
        tester,
        const RequestsScreen(),
        overrides: [
          apiClientProvider.overrideWithValue(api),
          clinicianRequestsProvider
              .overrideWith((ref) => api.clinicianRequests()),
        ],
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('shows empty state when no one is waiting', (tester) async {
      await pump(tester, []);
      expect(
        find.text(
          'No one is waiting. When a patient adds your invite code, they appear here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows patient name and Accept / Decline buttons',
        (tester) async {
      await pump(tester, [_request('l1', 'Ayesha')]);
      expect(find.text('Ayesha'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Decline'), findsOneWidget);
    });

    testWidgets(
        'accepting sends the link id and the request leaves the list',
        (tester) async {
      final api = await pump(tester, [_request('l1', 'Ayesha')]);
      expect(find.text('Ayesha'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pumpAndSettle();

      expect(api.accepted, ['l1']);
      expect(api.declined, isEmpty);
      expect(find.text('Ayesha'), findsNothing);
      // Empty state should show once the last request is removed.
      expect(
        find.text(
            'No one is waiting. When a patient adds your invite code, they appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('declining sends that link id and keeps the others',
        (tester) async {
      final api = await pump(
          tester, [_request('l1', 'Ayesha'), _request('l2', 'Bilal')]);
      // Decline the last entry in the list.
      final declineButtons = find.widgetWithText(TextButton, 'Decline');
      await tester.tap(declineButtons.last);
      await tester.pumpAndSettle();

      expect(api.declined, ['l2']);
      expect(api.accepted, isEmpty);
      expect(find.text('Ayesha'), findsOneWidget);
      expect(find.text('Bilal'), findsNothing);
    });

    testWidgets('clinician pages leave out the patient help action',
        (tester) async {
      await pump(tester, [_request('l1', 'Ayesha')]);
      // Neither the "Get help now" text nor the tooltip should appear.
      expect(find.text('Get help now'), findsNothing);
      expect(find.byTooltip('Get help now'), findsNothing);
    });
  });
}
