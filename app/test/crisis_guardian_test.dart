import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/core/ml/onnx_guardian.dart';
import 'package:therapylink/core/ml/sha256.dart';

/// Files in memory. [served] is what the "network" returns for each URL; [failAfter] cuts a
/// download short, the way a dropped connection does.
class FakeFiles implements GuardianFiles {
  FakeFiles(this.served);

  final Map<String, List<int>> served;
  final files = <String, List<int>>{};
  String? failAfter;

  @override
  Future<String> dir() async => '/guardian';

  @override
  Future<void> download(String url, String path, void Function(int got, int total) onProgress) async {
    final body = served[url]!;
    if (failAfter != null && url.endsWith(failAfter!)) {
      files[path] = body.sublist(0, body.length ~/ 2);
      throw StateError('connection dropped');
    }
    files[path] = body;
    onProgress(body.length, body.length);
  }

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
  _Model(this.crisis);

  final bool Function(String) crisis;

  @override
  Future<GuardianVerdict> classify(String text) async => GuardianVerdict(crisis: crisis(text), crisisScores: const {}, valence: 0);
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
  });

  group('trusting a loaded model', () {
    test('a model that reads nothing fails its canaries', () async {
      await expectLater(checkCanaries(_Model((_) => false)), throwsStateError);
      await expectLater(checkCanaries(_Model((_) => true)), throwsStateError);
      await checkCanaries(_Model((t) => guardianCanaries.any((c) => c.crisis && c.text == t)));
    });

    test('when the model fails, keywords still decide and the failure is reported', () async {
      final errors = <Object>[];
      final union = UnionGuardian(Future.error(StateError('bad model')), HeuristicGuardian(), onFailure: errors.add);

      final v = await union.classify('marna chahti hoon');

      expect(v.crisis, isTrue);
      expect(errors, hasLength(1));
    });

    test('keywords name abuse the model has no label for', () async {
      final union = UnionGuardian(Future.value(_Model((_) => false)), HeuristicGuardian());
      expect((await union.classify('my husband beats me')).kind, CrisisKind.abuse);
    });
  });

  test('a release build chats only once the trained Guardian is ready', () {
    expect(guardianGateOpen(const GuardianHeuristic(), release: true), isFalse);
    expect(guardianGateOpen(const GuardianFailed('x'), release: true), isFalse);
    expect(guardianGateOpen(const GuardianDownloading(40), release: true), isFalse);
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
