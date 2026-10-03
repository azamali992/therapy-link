// Unit tests for the pure routeRedirect function.
// No Flutter framework, no Riverpod, no Firebase — just logic.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/app/router.dart';
import 'package:therapylink/core/api/models.dart';

/// Shortcuts so each test stays readable.
const _signingIn = AsyncLoading<Object?>();
final _user = AsyncData<Object?>(_FakeUser());
const _loading = AsyncLoading<Me?>();
Me _me({bool clinician = false}) => Me(
  uid: 'u1',
  displayName: 'Test',
  role: clinician ? Role.clinician : Role.patient,
  locale: 'en',
  clinicianVerified: clinician,
);

class _FakeUser {}

AsyncValue<Me?> _meData({bool clinician = false}) => AsyncData<Me?>(_me(clinician: clinician));

String? _redirect(
  String path, {
  bool consented = true,
  bool onboarded = true,
  AsyncValue<Object?> auth = const AsyncData<Object?>(null),
  AsyncValue<Me?> me = const AsyncData<Me?>(null),
}) => routeRedirect(
  Uri.parse(path),
  consented: consented,
  onboarded: onboarded,
  auth: auth,
  me: me,
);

void main() {
  group('not consented', () {
    test('first launch goes to /welcome', () {
      expect(_redirect('/welcome', consented: false, onboarded: false), isNull);
      expect(_redirect('/', consented: false, onboarded: false), '/welcome');
    });

    test('returning user (onboarded) goes to /consent', () {
      expect(_redirect('/', consented: false, onboarded: true), '/consent');
      expect(_redirect('/consent', consented: false, onboarded: true), isNull);
    });

    test('/welcome is always allowed even when onboarded', () {
      expect(_redirect('/welcome', consented: false, onboarded: true), isNull);
    });
  });

  group('consented, not signed in', () {
    test('first launch without an account goes to /welcome', () {
      expect(_redirect('/welcome', onboarded: false), isNull);
      expect(_redirect('/', onboarded: false), '/welcome');
    });

    test('signed-out returning user goes to /sign-in', () {
      expect(_redirect('/', onboarded: true), '/sign-in');
      expect(_redirect('/sign-in', onboarded: true), isNull);
    });

    test('/welcome always allowed', () {
      expect(_redirect('/welcome', onboarded: true), isNull);
    });
  });

  group('auth loading', () {
    test('stays on the current path while auth resolves', () {
      expect(_redirect('/welcome', auth: _signingIn), isNull);
      expect(_redirect('/eve', auth: _signingIn), isNull);
    });
  });

  group('signed in, patient', () {
    test('auth pages redirect to /eve', () {
      expect(_redirect('/welcome', auth: _user, me: _meData()), '/eve');
      expect(_redirect('/sign-in', auth: _user, me: _meData()), '/eve');
      expect(_redirect('/', auth: _user, me: _meData()), '/eve');
    });

    test('/eve and patient pages stay put', () {
      expect(_redirect('/eve', auth: _user, me: _meData()), isNull);
      expect(_redirect('/today', auth: _user, me: _meData()), isNull);
      expect(_redirect('/journal', auth: _user, me: _meData()), isNull);
      expect(_redirect('/you', auth: _user, me: _meData()), isNull);
    });

    test('clinician pages redirect to /eve', () {
      expect(_redirect('/clinic', auth: _user, me: _meData()), '/eve');
    });
  });

  group('signed in, clinician', () {
    test('auth pages and root redirect to /clinic', () {
      expect(_redirect('/welcome', auth: _user, me: _meData(clinician: true)), '/clinic');
      expect(_redirect('/', auth: _user, me: _meData(clinician: true)), '/clinic');
    });

    test('/clinic and sub-pages stay put', () {
      expect(_redirect('/clinic', auth: _user, me: _meData(clinician: true)), isNull);
      expect(_redirect('/clinic/requests', auth: _user, me: _meData(clinician: true)), isNull);
    });

    test('patient pages redirect to /clinic', () {
      expect(_redirect('/eve', auth: _user, me: _meData(clinician: true)), '/clinic');
      expect(_redirect('/today', auth: _user, me: _meData(clinician: true)), '/clinic');
    });
  });

  group('me loading', () {
    test('stays put while me resolves after sign-in', () {
      expect(_redirect('/eve', auth: _user, me: _loading), isNull);
    });
  });

  group('instrument path validation', () {
    test('known instruments pass through', () {
      expect(_redirect('/today/assess/phq9', auth: _user, me: _meData()), isNull);
      expect(_redirect('/today/assess/gad7', auth: _user, me: _meData()), isNull);
    });

    test('unknown instrument is turned away', () {
      expect(_redirect('/today/assess/bdi2', auth: _user, me: _meData()), '/today');
      expect(_redirect('/today/assess/unknown', auth: _user, me: _meData()), '/today');
    });
  });

  group('instrumentFromPath', () {
    test('parses known names', () {
      expect(instrumentFromPath('phq9'), Instrument.phq9);
      expect(instrumentFromPath('gad7'), Instrument.gad7);
    });

    test('returns null for anything else', () {
      expect(instrumentFromPath('bdi2'), isNull);
      expect(instrumentFromPath(null), isNull);
      expect(instrumentFromPath('PHQ9'), isNull);
    });
  });
}
