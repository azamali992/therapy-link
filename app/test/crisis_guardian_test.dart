import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/core/ml/onnx_guardian.dart';
import 'package:therapylink/core/ml/sha256.dart';

/// Files in memory. [served] is what the "network" returns for each URL; [failAfter] cuts a
/// download short, the way a dropped connection does. A download onto a part file that is already
/// there gets only the rest, the way an HTTP Range request does.
class FakeFiles implements GuardianFiles {
  FakeFiles(this.served);

  final Map<String, List<int>> served;
  final files = <String, List<int>>{};
  String? failAfter;

  /// Free space to report; null is a platform that can't tell.
  int? free;

  /// Every URL fetched, and where in the file each fetch started.
  final fetched = <(String, int)>[];

  @override
  Future<String> dir() async => '/guardian';

  @override
  Future<void> download(String url, String path, void Function(int got, int total) onProgress) async {
    final body = served[url]!;
    final have = files[path]?.length ?? 0;
    fetched.add((url, have));
    if (failAfter != null && url.endsWith(failAfter!)) {
      files[path] = body.sublist(0, body.length ~/ 2);
      throw StateError('connection dropped');
    }
    files[path] = [...?files[path], ...body.sublist(have.clamp(0, body.length))];
    onProgress(body.length, body.length);
  }

  @override
  Future<int?> remoteSize(String url) async => served[url]?.length;

  @override
  Future<int?> freeBytes(String dir) async => free;

  @override
  Future<int> length(String path) async => files[path]?.length ?? 0;

  @override
  Stream<List<int>> read(String path) => Stream.fromIterable([files[path]!]);

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<void> rename(String from, String to) async => files[to] = files.remove(from)!;

  @override
  Future<void> delete(String path) async => files.remove(path);

  @override
  Future<String> readString(String path) async => utf8.decode(files[path]!);

  @override
  Future<void> writeString(String path, String content) async => files[path] = utf8.encode(content);
}

const _names = ['guardian.int8.onnx', 'spm_vocab.json', 'config.json', 'thresholds.json'];

({FakeFiles fs, Map<String, String> hashes}) _published() {
  final served = {for (final n in _names) 'https://hf/$n': utf8.encode('contents of $n')};
  return (fs: FakeFiles(served), hashes: {for (final n in _names) n: Sha256.of(utf8.encode('contents of $n'))});
}

class _Model implements Guardian {
  _Model(this.crisis, {this.delay = Duration.zero, this.kind});

  final bool Function(String) crisis;
  final Duration delay;
  final CrisisKind? kind;
  var calls = 0;

  @override
  Future<GuardianVerdict> classify(String text) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final c = crisis(text);
    return GuardianVerdict(crisis: c, crisisScores: const {}, valence: 0, kind: c ? kind : null, labels: {if (c && kind != null) kind!.label});
  }
}

/// A model that never answers, the way a stuck native call doesn't.
class _Hung implements Guardian {
  @override
  Future<GuardianVerdict> classify(String text) => Completer<GuardianVerdict>().future;
}

class _Throws implements Guardian {
  @override
  Future<GuardianVerdict> classify(String text) => Future.error(StateError('native call failed'));
}

/// A model verdict with these labels fired at these scores.
GuardianVerdict _verdict(Map<String, double> fired, {Map<String, double> others = const {}}) => GuardianVerdict(
  crisis: fired.isNotEmpty,
  crisisScores: {...others, ...fired},
  valence: fired.isEmpty ? 0 : -2,
  kind: routeCrisis(fired.keys, fired),
  labels: fired.keys.toSet(),
);

class _Network implements GuardianNetwork {
  _Network(this.wifi);

  bool wifi;
  final changes = StreamController<bool>.broadcast();

  void connect() {
    wifi = true;
    changes.add(true);
  }

  @override
  Future<bool> unmetered() async => wifi;

  @override
  Stream<bool> unmeteredChanges() => changes.stream;
}

/// Lets queued work and short timers run until [done] holds.
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(done(), isTrue, reason: 'condition never held');
}

void main() {
  group('SHA-256', () {
    test('matches the FIPS 180-4 test vectors', () {
      expect(Sha256.of([]), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(Sha256.of(utf8.encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(
        Sha256.of(utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('gives the same digest however the stream is chunked', () async {
      final bytes = List<int>.generate(10000, (i) => i * 7 % 256);
      final chunked = await Sha256.ofStream(Stream.fromIterable([bytes.sublist(0, 63), bytes.sublist(63, 64), bytes.sublist(64, 5000), bytes.sublist(5000)]));
      expect(chunked, Sha256.of(bytes));
    });
  });

  group('installing the trained Guardian', () {
    test('verified files are moved into place and recorded as installed', () async {
      final p = _published();
      await installGuardian(p.fs, base: 'https://hf', hashes: p.hashes);

      for (final n in _names) {
        expect(p.fs.files.containsKey('/guardian/$n'), isTrue);
        expect(p.fs.files.containsKey('/guardian/$n.part'), isFalse);
      }
      expect(await guardianInstalled(p.fs, p.hashes), isTrue);
    });

    test('a file that fails its checksum is never put where the loader reads', () async {
      final p = _published();
      p.fs.served['https://hf/guardian.int8.onnx'] = utf8.encode('tampered');

      await expectLater(installGuardian(p.fs, base: 'https://hf', hashes: p.hashes), throwsStateError);

      expect(p.fs.files.containsKey('/guardian/guardian.int8.onnx'), isFalse);
      expect(p.fs.files.keys.where((k) => k.endsWith('.part')), isEmpty);
      expect(await guardianInstalled(p.fs, p.hashes), isFalse);
    });

    test('an interrupted download leaves nothing that counts as installed', () async {
      final p = _published();
      p.fs.failAfter = 'spm_vocab.json';

      await expectLater(installGuardian(p.fs, base: 'https://hf', hashes: p.hashes), throwsStateError);

      expect(p.fs.files.containsKey('/guardian/spm_vocab.json'), isFalse);
      expect(await guardianInstalled(p.fs, p.hashes), isFalse);
    });

    test('with no published checksums nothing is downloaded at all', () async {
      final p = _published();
      await expectLater(installGuardian(p.fs, base: 'https://hf', hashes: const {}), throwsStateError);
      expect(p.fs.files, isEmpty);
      expect(await guardianInstalled(p.fs, const {}), isFalse);
    });

    test('files verified against another release do not count', () async {
      final p = _published();
      await installGuardian(p.fs, base: 'https://hf', hashes: p.hashes);
      final newer = {...p.hashes, 'guardian.int8.onnx': 'f' * 64};
      expect(await guardianInstalled(p.fs, newer), isFalse);
    });

    test('a download cut off halfway resumes from where it stopped', () async {
      final p = _published();
      p.fs.failAfter = 'spm_vocab.json';
      await expectLater(installGuardian(p.fs, base: 'https://hf', hashes: p.hashes), throwsStateError);
      final half = p.fs.files['/guardian/spm_vocab.json.part']!.length;
      expect(half, greaterThan(0), reason: 'the part file is kept for the next attempt');

      p.fs.failAfter = null;
      p.fs.fetched.clear();
      await installGuardian(p.fs, base: 'https://hf/', hashes: p.hashes);

      // The model file was already in place and verified, so it is not fetched again.
      expect(p.fs.fetched.map((f) => f.$1), isNot(contains('https://hf/guardian.int8.onnx')));
      expect(p.fs.fetched.first, ('https://hf/spm_vocab.json', half));
      expect(await guardianInstalled(p.fs, p.hashes), isTrue);
    });

    test('a resumed file that does not match its checksum is thrown away, not installed', () async {
      final p = _published();
      p.fs.files['/guardian/spm_vocab.json.part'] = utf8.encode('garbage from somewhere else');

      await expectLater(installGuardian(p.fs, base: 'https://hf', hashes: p.hashes), throwsStateError);

      expect(p.fs.files.containsKey('/guardian/spm_vocab.json'), isFalse);
      expect(p.fs.files.containsKey('/guardian/spm_vocab.json.part'), isFalse, reason: 'the next attempt starts it clean');
      expect(await guardianInstalled(p.fs, p.hashes), isFalse);
    });

    test('a phone without the space is told before anything is fetched', () async {
      final p = _published();
      p.fs.free = 1024;
      await expectLater(installGuardian(p.fs, base: 'https://hf', hashes: p.hashes), throwsA(isA<GuardianSpaceException>()));
      expect(p.fs.fetched, isEmpty);
    });

    test('the build flag from the release report parses into the four hashes', () {
      final h = parseGuardianHashes('guardian.int8.onnx:C95D,spm_vocab.json:5371,config.json:d33b,thresholds.json:95bd');
      expect(h.keys, unorderedEquals(guardianFileNames));
      expect(h['guardian.int8.onnx'], 'c95d');
    });
  });

  group('installing from a local bundle', () {
    test('only debug and profile builds may; a release build ignores a local directory', () {
      expect(guardianSource('https://api.example.org/guardian/', release: true), 'https://api.example.org/guardian');
      expect(guardianSource('/sdcard/Android/data/x/files/guardian', release: true), '');
      expect(guardianSource(r'D:\ml\bundle', release: true), '');
      expect(guardianSource('file:///tmp/bundle', release: true), '');
      expect(guardianSource('/sdcard/Android/data/x/files/guardian/', release: false), '/sdcard/Android/data/x/files/guardian');
    });

    test("a debug build checks the copy against the bundle's own verified.json", () async {
      final p = _published();
      final local = <String, List<int>>{
        for (final n in _names) '/bundle/$n': utf8.encode('contents of $n'),
        '/bundle/verified.json': utf8.encode(jsonEncode(p.hashes)),
      };
      final fs = FakeFiles(local)..files.addAll(local);
      final hashes = await resolveGuardianHashes(fs, source: '/bundle', built: const {}, release: false);
      expect(hashes, p.hashes);
      expect(await resolveGuardianHashes(fs, source: '/bundle', built: const {}, release: true), isEmpty);

      await installGuardian(fs, base: '/bundle', hashes: hashes);
      expect(await guardianInstalled(fs, hashes), isTrue);
    });
  });

  group('the download waits for Wi-Fi and reports where it stands', () {
    ProviderContainer container(FakeFiles fs, Map<String, String> hashes, GuardianNetwork net) {
      final c = ProviderContainer(
        overrides: [
          guardianModelManagerProvider.overrideWith(
            () => GuardianModelManager(files: fs, network: net, source: 'https://hf/', hashes: hashes, release: true),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(guardianModelManagerProvider, (_, _) {});
      return c;
    }

    test('on mobile data it waits, says how big it is, and starts by itself on Wi-Fi', () async {
      final p = _published();
      final net = _Network(false);
      final c = container(p.fs, p.hashes, net);

      await _until(() => c.read(guardianModelManagerProvider) is GuardianWaitingForWifi);
      final waiting = c.read(guardianModelManagerProvider) as GuardianWaitingForWifi;
      expect(waiting.bytes, p.fs.served.values.fold<int>(0, (a, b) => a + b.length));
      expect(p.fs.fetched, isEmpty);

      net.connect();
      await _until(() => c.read(guardianModelManagerProvider) is GuardianReady);
      expect(await guardianInstalled(p.fs, p.hashes), isTrue);
    });

    test('the person can choose mobile data', () async {
      final p = _published();
      final c = container(p.fs, p.hashes, _Network(false));
      await _until(() => c.read(guardianModelManagerProvider) is GuardianWaitingForWifi);

      await c.read(guardianModelManagerProvider.notifier).download(allowMetered: true);

      expect(c.read(guardianModelManagerProvider), isA<GuardianReady>());
    });

    test('too little space is its own state; a checksum mismatch is a failure, never Ready', () async {
      final p = _published()..fs.free = 10;
      final c = container(p.fs, p.hashes, _Network(true));
      await _until(() => c.read(guardianModelManagerProvider) is GuardianNoSpace);

      p.fs.free = null;
      p.fs.served['https://hf/config.json'] = utf8.encode('tampered');
      await c.read(guardianModelManagerProvider.notifier).download();
      expect(c.read(guardianModelManagerProvider), isA<GuardianFailed>());
      expect(guardianGateOpen(c.read(guardianModelManagerProvider), release: true), isFalse);
    });

    test('an installed, verified bundle is Ready at startup without a download', () async {
      final p = _published();
      await installGuardian(p.fs, base: 'https://hf', hashes: p.hashes);
      p.fs.fetched.clear();
      final c = container(p.fs, p.hashes, _Network(false));
      await _until(() => c.read(guardianModelManagerProvider) is GuardianReady);
      expect(p.fs.fetched, isEmpty);
    });
  });

  group('trusting a loaded model', () {
    test('a model that reads nothing fails its canaries', () async {
      await expectLater(checkCanaries(_Model((_) => false)), throwsStateError);
      await expectLater(checkCanaries(_Model((_) => true)), throwsStateError);
      await checkCanaries(_Model((t) => guardianCanaries.any((c) => c.crisis && c.text == t)));
    });

    test('the canaries cover English, Roman Urdu and Urdu script, calm and crisis', () {
      expect(guardianCanaries, hasLength(7));
      expect(guardianCanaries.where((c) => c.crisis), hasLength(4));
      expect(guardianCanaries.any((c) => c.text.contains('jeena nahi')), isTrue);
      expect(guardianCanaries.where((c) => RegExp('[\u0600-\u06FF]').hasMatch(c.text)), hasLength(2));
    });

    test('a model that reads a crisis canary as the wrong kind fails too', () async {
      await expectLater(
        checkCanaries(_Model((t) => guardianCanaries.any((c) => c.crisis && c.text == t), kind: CrisisKind.medical)),
        throwsStateError,
      );
      await checkCanaries(_Model((t) => guardianCanaries.any((c) => c.crisis && c.text == t), kind: CrisisKind.suicide));
    });

    test('when the model fails, keywords still decide and the failure is reported', () async {
      final errors = <Object>[];
      final union = UnionGuardian(Future.error(StateError('bad model')), HeuristicGuardian(), onFailure: errors.add);

      final v = await union.classify('marna chahti hoon');

      expect(v.crisis, isTrue);
      expect(errors, hasLength(1));
    });

    test('keywords name abuse the model does not see', () async {
      final union = UnionGuardian(Future.value(_Model((_) => false)), HeuristicGuardian());
      expect((await union.classify('my husband beats me')).kind, CrisisKind.abuse);
    });
  });

  group('the model never holds up a send, and the keyword floor always counts', () {
    test('a model that never answers: keyword matches still route, in time', () async {
      final union = UnionGuardian(Future.value(_Hung()), HeuristicGuardian(), budget: const Duration(milliseconds: 50));
      final sw = Stopwatch()..start();

      final v = await union.classify('main 12 saal ki hoon aur abbu mujhe maarte hain');

      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(v.crisis, isTrue);
      expect(v.kind, CrisisKind.child);
      expect((await union.classify('had chai with ammi')).crisis, isFalse);
    });

    test('a model still loading: the keyword verdict stands for this message', () async {
      final load = Completer<Guardian>();
      final union = UnionGuardian(load.future, HeuristicGuardian(), budget: const Duration(milliseconds: 30));

      expect((await union.classify('marna chahti hoon')).kind, CrisisKind.suicide);

      // Once loaded, the model is used.
      load.complete(_Model((t) => t.contains('roof'), kind: CrisisKind.suicide));
      expect((await union.classify('standing on the roof now')).crisis, isTrue);
    });

    test('a slow model is not a failure, but one that keeps timing out is reported once', () async {
      final errors = <Object>[];
      final model = _Model((_) => false, delay: const Duration(milliseconds: 200));
      final union = UnionGuardian(Future.value(model), HeuristicGuardian(), onFailure: errors.add, budget: const Duration(milliseconds: 10));

      for (var i = 0; i < guardianTimeoutsBeforeFailure - 1; i++) {
        await union.classify('hello');
      }
      expect(errors, isEmpty);
      await union.classify('hello');
      expect(errors, hasLength(1));
      expect(errors.single, isA<TimeoutException>());

      // After that the model is not asked again; keywords carry on.
      final calls = model.calls;
      expect((await union.classify('I want to kill myself')).crisis, isTrue);
      expect(model.calls, calls);
    });

    test('a model that throws while running: keywords decide and the failure is reported', () async {
      final errors = <Object>[];
      final union = UnionGuardian(Future.value(_Throws()), HeuristicGuardian(), onFailure: errors.add);
      final v = await union.classify('my husband beats me');
      expect(v.kind, CrisisKind.abuse);
      expect(errors, hasLength(1));
    });
  });

  group('keywords and model together', () {
    final keywords = HeuristicGuardian();

    test('a keyword hit on suicide and a sure medical reading route to Rescue first', () async {
      final kw = await keywords.classify('I took all the pills in the box');
      expect(kw.kind, CrisisKind.suicide);
      expect(union(kw, _verdict({'medical': 0.8, 'suicidal': 0.9})).kind, CrisisKind.medical);
    });

    test('the keyword floor keeps its route when the model reads nothing', () async {
      final kw = await keywords.classify('my husband beats me');
      final v = union(kw, _verdict({}));
      expect(v.crisis, isTrue);
      expect(v.kind, CrisisKind.abuse);
    });

    test('the model names a child the keywords could only call abuse', () async {
      final kw = await keywords.classify('my husband beats me');
      expect(union(kw, _verdict({'child': 0.7, 'abuse': 0.9})).kind, CrisisKind.child);
    });

    test('a model-only label routes even when keywords see nothing', () async {
      final kw = await keywords.classify('I want to hurt him so badly he never walks again');
      expect(kw.crisis, isFalse);
      expect(union(kw, _verdict({'harm_to_others': 0.66})).kind, CrisisKind.harmToOthers);
    });

    test('calm on both sides is no crisis', () async {
      final kw = await keywords.classify('had chai with ammi');
      final v = union(kw, _verdict({}, others: {'suicidal': 0.01}));
      expect(v.crisis, isFalse);
      expect(v.kind, isNull);
    });
  });

  test('a release build chats only once the trained Guardian is ready', () {
    expect(guardianGateOpen(const GuardianHeuristic(), release: true), isFalse);
    expect(guardianGateOpen(const GuardianFailed('x'), release: true), isFalse);
    expect(guardianGateOpen(const GuardianDownloading(40), release: true), isFalse);
    expect(guardianGateOpen(const GuardianWaitingForWifi(1), release: true), isFalse);
    expect(guardianGateOpen(const GuardianNoSpace(1), release: true), isFalse);
    expect(guardianGateOpen(const GuardianReady(), release: true), isTrue);
    expect(guardianGateOpen(const GuardianHeuristic(), release: false), isTrue);
  });

  test('verdicts from the windows of a long message merge: a crisis in any window is a crisis', () {
    final merged = mergeVerdicts([
      const GuardianVerdict(crisis: false, crisisScores: {'suicidal': 0.1}, valence: 0),
      const GuardianVerdict(crisis: true, crisisScores: {'suicidal': 0.8}, valence: -2),
    ]);
    expect(merged.crisis, isTrue);
    expect(merged.crisisScores['suicidal'], 0.8);
    expect(merged.valence, -2);
  });
}
