import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/api/api_client.dart';
import 'package:therapylink/core/api/models.dart';
import 'package:therapylink/core/auth/auth_providers.dart';
import 'package:therapylink/core/auth/auth_repository.dart';
import 'package:therapylink/features/you/access_log_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_harness.dart';
import 'platform_harness.dart';

class _Auth implements AuthRepository {
  bool signedIn = true;
  int refreshes = 0;
  int signOuts = 0;

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    if (forceRefresh) refreshes++;
    return signedIn ? 'token' : null;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    signedIn = false;
  }

  @override
  Stream<User?> get authState => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('busy and unavailable are not sign-in problems', () {
    late _Auth auth;
    late ProviderContainer container;

    Dio dioReplying(int status, [Map<String, List<String>> headers = const {}]) {
      auth = _Auth();
      container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(auth)]);
      addTearDown(container.dispose);
      final dio = container.read(dioProvider);
      dio.httpClientAdapter = FakeAdapter((_) => reply(status, {'detail': 'x'}, headers));
      return dio;
    }

    test('429 becomes RateLimitedException with Retry-After, and the person stays signed in', () async {
      final dio = dioReplying(429, {
        'retry-after': ['7'],
      });
      final api = ApiClient(dio);
      await expectLater(
        api.me(),
        throwsA(isA<RateLimitedException>().having((e) => e.retryAfter, 'retryAfter', 7).having((e) => e.response?.statusCode, 'status', 429)),
      );
      expect(auth.signOuts, 0);
      expect(auth.signedIn, isTrue);
      expect(auth.refreshes, 0, reason: 'a 429 is not a stale token');
    });

    test('503 becomes ServiceUnavailableException, and the person stays signed in', () async {
      final api = ApiClient(dioReplying(503));
      await expectLater(api.me(), throwsA(isA<ServiceUnavailableException>()));
      expect(auth.signOuts, 0);
      expect(auth.signedIn, isTrue);
      expect(auth.refreshes, 0);
    });

    test('both are still DioExceptions, so existing handlers keep catching them', () async {
      final api = ApiClient(dioReplying(429));
      await expectLater(api.me(), throwsA(allOf(isA<DioException>(), isNot(isA<ServiceUnavailableException>()))));
    });

    test('other errors pass through unchanged', () async {
      final api = ApiClient(dioReplying(500));
      await expectLater(
        api.me(),
        throwsA(allOf(isA<DioException>(), isNot(isA<RateLimitedException>()), isNot(isA<ServiceUnavailableException>()))),
      );
    });

    test('Retry-After is read as whole seconds', () {
      expect(retryAfterSeconds('30'), 30);
      expect(retryAfterSeconds(' 5 '), 5);
      expect(retryAfterSeconds('Wed, 21 Oct 2026 07:28:00 GMT'), isNull);
      expect(retryAfterSeconds(null), isNull);
      expect(retryAfterSeconds('-1'), isNull);
    });
  });

  group('who viewed my data', () {
    test('accessLog asks GET /me/access-log', () async {
      final dio = fakeDio((_) => reply(200, [
        {
          'clinician_uid': 'c1',
          'clinician_name': 'Dr Sana',
          'action': 'overview',
          'sections': ['assessments'],
          'at': '2026-09-20T10:00:00Z',
        },
      ]));
      final rows = await ApiClient(dio).accessLog();
      expect(adapterOf(dio).requests.single.path, '/me/access-log');
      expect(rows.single.clinicianName, 'Dr Sana');
      expect(rows.single.sections, ['assessments']);
    });

    testWidgets('the screen lists each view with who, what and what was shown', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rows = [
        AccessLogEntry(
          clinicianUid: 'c1',
          clinicianName: 'Dr Sana Malik',
          action: 'overview',
          sections: const ['assessments', 'mood_trend'],
          at: DateTime(2026, 9, 20, 10),
        ),
        AccessLogEntry(
          clinicianUid: 'c2',
          action: 'caseload',
          sections: const [],
          at: DateTime(2026, 9, 19, 9),
        ),
      ];
      await pumpApp(tester, const AccessLogScreen(), overrides: [accessLogProvider.overrideWithValue(AsyncData(rows))]);

      expect(find.text('Dr Sana Malik'), findsOneWidget);
      expect(find.text('Opened your page'), findsOneWidget);
      expect(find.text('Check-ins · Mood trend'), findsOneWidget);
      expect(find.text('A clinician'), findsOneWidget);
      expect(find.text('Saw you in their patient list'), findsOneWidget);
      expect(find.text('Nothing you share was shown'), findsOneWidget);
    });

    testWidgets('no views yet says so', (tester) async {
      await pumpApp(tester, const AccessLogScreen(), overrides: [accessLogProvider.overrideWithValue(const AsyncData([]))]);
      expect(find.text('No clinician has viewed your data.'), findsOneWidget);
    });
  });
}
