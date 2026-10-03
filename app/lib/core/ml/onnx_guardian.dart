import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'guardian.dart';
import 'sha256.dart';
import 'tokenizer/tokenizer_worker.dart';

/// Where the trained Guardian is served from: the API's `GET /guardian/<file>` route
/// (`--dart-define=TL_GUARDIAN_URL=https://<domain>/guardian/`). Debug and profile builds may give a
/// local directory instead (an absolute path or a file:// URI) to test a bundle without a server;
/// release builds ignore one (see [guardianSource]).
const guardianRepoBase = String.fromEnvironment('TL_GUARDIAN_URL', defaultValue: '');

/// The four files every Guardian bundle has. A new release (v1c, say) keeps these names, so moving
/// to it is a change of build flags and served files, not of code.
const guardianFileNames = ['guardian.int8.onnx', 'spm_vocab.json', 'config.json', 'thresholds.json'];

/// SHA-256 of each published Guardian file, from the release's report.json `dart_define`. Without
/// them every download fails verification, because a model nobody can vouch for must not decide who
/// sees a helpline. Supplied at build time as `--dart-define=TL_GUARDIAN_SHA256=<file>:<hex>,...`.
const _hashesDefine = String.fromEnvironment('TL_GUARDIAN_SHA256', defaultValue: '');

/// What the bundle weighs, for the size shown before a download when the server can't say.
/// Guardian v1b's four files: 287,093,575 bytes. Set it with the new release's total when swapping.
const guardianBundleBytesHint = int.fromEnvironment('TL_GUARDIAN_BYTES', defaultValue: 287093575);

/// Free space kept on top of the bundle itself, so the download never fills the phone.
const _spaceMargin = 64 * 1024 * 1024;

Map<String, String> parseGuardianHashes(String define) => {
  for (final pair in define.split(',').where((p) => p.contains(':')))
    pair.substring(0, pair.indexOf(':')).trim(): pair.substring(pair.indexOf(':') + 1).trim().toLowerCase(),
};

final guardianFileHashes = parseGuardianHashes(_hashesDefine);

/// Whether [source] names a directory on this machine rather than a web address.
bool isLocalSource(String source) =>
    source.startsWith('file://') || source.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source);

String _localPath(String source) => source.startsWith('file://') ? Uri.parse(source).toFilePath() : source;

/// The source to install from, without a trailing slash. Empty when there is none, or when a release
/// build is given a local directory: a patient's phone only ever installs the published files.
String guardianSource(String configured, {bool release = kReleaseMode}) {
  final s = configured.trim().replaceAll(RegExp(r'[\\/]+$'), '');
  if (release && isLocalSource(s)) return '';
  return s;
}

/// Written next to the files once every hash has matched. Startup trusts the files only if this
/// holds the hashes the build expects, so a partial or swapped file never counts as installed.
const _verifiedMarker = 'verified.json';

@immutable
sealed class GuardianStatus {
  const GuardianStatus();
}

/// The keyword check alone: nothing installed yet, or no published model in this build.
class GuardianHeuristic extends GuardianStatus {
  const GuardianHeuristic();
}

/// The phone is on mobile data, so the download waits for Wi-Fi unless the person says otherwise.
class GuardianWaitingForWifi extends GuardianStatus {
  const GuardianWaitingForWifi(this.bytes);

  final int bytes;
}

class GuardianDownloading extends GuardianStatus {
  const GuardianDownloading(this.percent);

  final int percent;
}

/// Not enough free space for the bundle; [bytes] is what it needs.
class GuardianNoSpace extends GuardianStatus {
  const GuardianNoSpace(this.bytes);

  final int bytes;
}

class GuardianReady extends GuardianStatus {
  const GuardianReady();
}

class GuardianFailed extends GuardianStatus {
  const GuardianFailed(this.message);

  final String message;
}

/// Thrown by [installGuardian] before anything is fetched when the phone lacks the space.
class GuardianSpaceException implements Exception {
  const GuardianSpaceException(this.needed, this.free);

  final int needed;
  final int free;

  @override
  String toString() => 'not enough space for the safety model: needs $needed bytes, $free free';
}

/// Where the Guardian's files are kept and fetched from. Behind an interface so install,
/// verification and resume can be tested without a network or a disk.
abstract class GuardianFiles {
  Future<String> dir();

  /// Fetches [url] to [path]. If [path] already holds the start of the file (an earlier attempt
  /// that was cut off), only the rest is fetched and appended.
  Future<void> download(String url, String path, void Function(int got, int total) onProgress);

  /// The size of the file at [url], or null if the server doesn't say.
  Future<int?> remoteSize(String url);

  /// Free bytes on the disk holding [dir], or null where the platform can't tell.
  Future<int?> freeBytes(String dir);

  /// The size of the local file at [path]; 0 if there is none.
  Future<int> length(String path);
  Stream<List<int>> read(String path);
  Future<bool> exists(String path);
  Future<void> rename(String from, String to);
  Future<void> delete(String path);
  Future<String> readString(String path);
  Future<void> writeString(String path, String content);
}

const _storageChannel = MethodChannel('com.therapylink/storage');

class DiskGuardianFiles implements GuardianFiles {
  DiskGuardianFiles([Dio? dio])
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 60)));

  final Dio _dio;

  @override
  Future<String> dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/guardian');
    await d.create(recursive: true);
    return d.path;
  }

  @override
  Future<void> download(String url, String path, void Function(int got, int total) onProgress) async {
    if (isLocalSource(url)) {
      final src = File(_localPath(url));
      await src.copy(path);
      final n = await src.length();
      onProgress(n, n);
      return;
    }
    final file = File(path);
    final have = await file.exists() ? await file.length() : 0;
    final res = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: have > 0 ? {'range': 'bytes=$have-'} : null,
        validateStatus: (s) => s == 200 || s == 206 || s == 416,
      ),
    );
    final body = res.data!;
    if (res.statusCode == 416) {
      // Nothing past what is already here. The checksum decides whether it is the whole file.
      await body.stream.drain<void>();
      onProgress(have, have);
      return;
    }
    // 206: the server resumed where the part file ends. 200: it sent the whole file again.
    final resumed = res.statusCode == 206;
    final length = int.tryParse(res.headers.value(Headers.contentLengthHeader) ?? '') ?? -1;
    final total = length < 0 ? -1 : (resumed ? have + length : length);
    var got = resumed ? have : 0;
    final sink = file.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    try {
      await for (final chunk in body.stream) {
        sink.add(chunk);
        got += chunk.length;
        onProgress(got, total);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  @override
  Future<int?> remoteSize(String url) async {
    try {
      if (isLocalSource(url)) return await File(_localPath(url)).length();
      final res = await _dio.head<void>(url);
      return int.tryParse(res.headers.value(Headers.contentLengthHeader) ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int?> freeBytes(String dir) async {
    try {
      return await _storageChannel.invokeMethod<int>('freeBytes', {'path': dir});
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> length(String path) async {
    final f = File(path);
    return await f.exists() ? f.length() : 0;
  }

  @override
  Stream<List<int>> read(String path) => File(path).openRead();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> rename(String from, String to) => File(from).rename(to);

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<String> readString(String path) => File(path).readAsString();

  @override
  Future<void> writeString(String path, String content) => File(path).writeAsString(content, flush: true);
}

/// Whether the files in [files] were installed and verified against [hashes].
Future<bool> guardianInstalled(GuardianFiles files, Map<String, String> hashes) async {
  if (hashes.isEmpty) return false;
  final dir = await files.dir();
  final marker = '$dir/$_verifiedMarker';
  if (!await files.exists(marker)) return false;
  try {
    final recorded = Map<String, String>.from(jsonDecode(await files.readString(marker)) as Map);
    for (final f in guardianFileNames) {
      if (recorded[f] == null || recorded[f] != hashes[f] || !await files.exists('$dir/$f')) return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Fetches each file to `<name>.part`, checks its SHA-256 against [hashes], and only then moves it
/// into place. An interrupted or tampered download never sits at the path the loader reads.
///
/// A part file left by an attempt that was cut off is resumed rather than started again, and a file
/// already in place with the right hash is kept, so a dropped connection costs only what was not yet
/// fetched. A part that fails its checksum is deleted, so the next attempt starts it clean. Before
/// fetching anything the free space is checked against what is left to fetch.
///
/// Throws on any failure, leaving no marker behind.
Future<void> installGuardian(
  GuardianFiles files, {
  required String base,
  required Map<String, String> hashes,
  void Function(int percent)? onProgress,
}) async {
  final missing = [for (final f in guardianFileNames) if ((hashes[f] ?? '').isEmpty) f];
  if (missing.isNotEmpty) throw StateError('no published checksum for ${missing.join(', ')}');
  final src = base.replaceAll(RegExp(r'[\\/]+$'), '');
  final dir = await files.dir();
  await files.delete('$dir/$_verifiedMarker');

  final todo = <String>[];
  for (final f in guardianFileNames) {
    if (await files.exists('$dir/$f') && await Sha256.ofStream(files.read('$dir/$f')) == hashes[f]) continue;
    todo.add(f);
  }

  final free = await files.freeBytes(dir);
  if (free != null) {
    var needed = _spaceMargin;
    for (final f in todo) {
      final size = await files.remoteSize('$src/$f');
      if (size != null) needed += math.max(0, size - await files.length('$dir/$f.part'));
    }
    if (free < needed) throw GuardianSpaceException(needed, free);
  }

  for (var i = 0; i < todo.length; i++) {
    final f = todo[i];
    final part = '$dir/$f.part';
    await files.download('$src/$f', part, (got, total) {
      if (total > 0) onProgress?.call(((i + got / total) / todo.length * 100).clamp(0, 100).round());
    });
    final actual = await Sha256.ofStream(files.read(part));
    if (actual != hashes[f]) {
      await files.delete(part);
      throw StateError('checksum mismatch for $f');
    }
    await files.delete('$dir/$f');
    await files.rename(part, '$dir/$f');
  }
  await files.writeString('$dir/$_verifiedMarker', jsonEncode({for (final f in guardianFileNames) f: hashes[f]}));
}

/// The hashes to verify against: the build's, or in a debug or profile build installing from a
/// local directory that has none, the `verified.json` the release ships next to its files. That
/// lets a developer try a bundle with only `--dart-define=TL_GUARDIAN_URL=<dir>`; the copy is still
/// checked byte for byte against what the release recorded.
Future<Map<String, String>> resolveGuardianHashes(
  GuardianFiles files, {
  required String source,
  required Map<String, String> built,
  bool release = kReleaseMode,
}) async {
  if (built.isNotEmpty || release || !isLocalSource(source)) return built;
  try {
    final path = '${_localPath(source)}/verified.json';
    if (!await files.exists(path)) return built;
    return Map<String, String>.from(jsonDecode(await files.readString(path)) as Map).map((k, v) => MapEntry(k, v.toLowerCase()));
  } catch (_) {
    return built;
  }
}

/// A sentence the loaded model must read right before it is trusted, and the route it must give.
typedef GuardianCanary = ({String text, bool crisis, CrisisKind? kind});

/// Sentences the loaded model must get right before it is trusted. A model that loads but reads
/// nothing (a dtype mismatch, a wrong tokenizer) would otherwise pass silently with every verdict
/// 'none'. Guardian v1b reads English, Roman Urdu and Urdu script, so each language has a crisis and
/// a calm canary (ml/releases/guardian-v1b/canaries.json, all passed at export).
const List<GuardianCanary> guardianCanaries = [
  (text: 'I want to end my life tonight', crisis: true, kind: CrisisKind.suicide),
  (text: "I don't see any reason to keep living anymore", crisis: true, kind: CrisisKind.suicide),
  (text: 'I had lunch with my sister and we watched a film', crisis: false, kind: null),
  (text: 'main ab aur jeena nahi chahti, sab khatam karna hai', crisis: true, kind: CrisisKind.suicide),
  (text: 'aaj ammi ke saath bazaar gaye, bohat maza aaya', crisis: false, kind: null),
  (text: 'میں اب زندہ نہیں رہنا چاہتا', crisis: true, kind: CrisisKind.suicide),
  (text: 'آج موسم بہت اچھا ہے، ہم پارک گئے', crisis: false, kind: null),
];

/// Throws unless [model] gives the expected verdict on every canary: crisis or not, and for a
/// crisis the route.
Future<void> checkCanaries(Guardian model) async {
  for (final c in guardianCanaries) {
    final v = await model.classify(c.text);
    if (v.crisis != c.crisis) throw StateError('canary failed: "${c.text}" read as crisis=${v.crisis}');
    if (c.crisis && c.kind != null && v.kind != c.kind) throw StateError('canary failed: "${c.text}" routed to ${v.kind}');
  }
}

/// Whether the phone is on Wi-Fi (or a wire), where a large download costs nothing per megabyte.
abstract class GuardianNetwork {
  Future<bool> unmetered();
  Stream<bool> unmeteredChanges();
}

class ConnectivityGuardianNetwork implements GuardianNetwork {
  static bool _free(List<ConnectivityResult> r) => r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);

  @override
  Future<bool> unmetered() async {
    try {
      return _free(await Connectivity().checkConnectivity());
    } catch (_) {
      // A platform without the plugin: don't hold the download back.
      return true;
    }
  }

  @override
  Stream<bool> unmeteredChanges() => Connectivity().onConnectivityChanged.map(_free);
}

/// Installs the trained Guardian and reports where that stands.
///
/// It starts by itself when the build has a source and the files aren't installed, but only on
/// Wi-Fi: on mobile data it waits ([GuardianWaitingForWifi]) and picks up when Wi-Fi comes back,
/// unless the person chooses to download on mobile data. A dropped download resumes where it
/// stopped. The keyword check guards every message the whole time.
class GuardianModelManager extends Notifier<GuardianStatus> {
  GuardianModelManager({GuardianFiles? files, GuardianNetwork? network, String? source, Map<String, String>? hashes, bool release = kReleaseMode})
      : _files = files ?? DiskGuardianFiles(),
        _network = network ?? ConnectivityGuardianNetwork(),
        _source = guardianSource(source ?? guardianRepoBase, release: release),
        _builtHashes = hashes ?? guardianFileHashes,
        _release = release;

  final GuardianFiles _files;
  final GuardianNetwork _network;
  final String _source;
  final Map<String, String> _builtHashes;
  final bool _release;
  StreamSubscription<bool>? _wifi;

  @override
  GuardianStatus build() {
    ref.onDispose(() => _wifi?.cancel());
    if (!kIsWeb) unawaited(_startup());
    return const GuardianHeuristic();
  }

  bool get available => _source.isNotEmpty && !kIsWeb;

  Future<Map<String, String>> _hashes() => resolveGuardianHashes(_files, source: _source, built: _builtHashes, release: _release);

  Future<void> _startup() async {
    try {
      if (await guardianInstalled(_files, await _hashes())) {
        if (ref.mounted && state is GuardianHeuristic) state = const GuardianReady();
        return;
      }
      if (available && ref.mounted && state is GuardianHeuristic) await download();
    } catch (e) {
      if (ref.mounted) state = GuardianFailed('$e');
    }
  }

  Future<int> _bundleBytes() async {
    var total = 0;
    for (final f in guardianFileNames) {
      final n = await _files.remoteSize('$_source/$f');
      if (n == null) return guardianBundleBytesHint;
      total += n;
    }
    return total;
  }

  /// Installs the model. On mobile data it waits for Wi-Fi unless [allowMetered] is true.
  Future<void> download({bool allowMetered = false}) async {
    if (!available || state is GuardianDownloading || !ref.mounted) return;
    await _wifi?.cancel();
    _wifi = null;
    if (!allowMetered && !isLocalSource(_source) && !await _network.unmetered()) {
      final bytes = await _bundleBytes();
      if (!ref.mounted) return;
      state = GuardianWaitingForWifi(bytes);
      _wifi = _network.unmeteredChanges().where((free) => free).take(1).listen((_) {
        _wifi = null;
        if (ref.mounted && state is GuardianWaitingForWifi) unawaited(download());
      });
      return;
    }
    state = const GuardianDownloading(0);
    try {
      await installGuardian(_files, base: _source, hashes: await _hashes(), onProgress: (p) {
        if (ref.mounted) state = GuardianDownloading(p);
      });
      if (ref.mounted) state = const GuardianReady();
    } on GuardianSpaceException catch (e) {
      debugPrint('guardian install: $e');
      if (ref.mounted) state = GuardianNoSpace(e.needed);
    } catch (e) {
      debugPrint('guardian install failed: $e');
      if (ref.mounted) state = GuardianFailed('$e');
    }
  }

  /// The model loaded but failed to run, failed its canaries or kept running out of time. Keywords
  /// carry on alone, and the failure is shown rather than hidden behind "Trained model installed".
  void fail(Object error) {
    debugPrint('guardian failed: $error');
    if (ref.mounted) state = GuardianFailed('$error');
  }
}

final guardianModelManagerProvider = NotifierProvider<GuardianModelManager, GuardianStatus>(GuardianModelManager.new);

/// Whether Eve may chat. In a release build the trained Guardian must be installed and working: on
/// Guardian v1b's 1,242 held-out messages keywords alone caught 30% of crises, the model 97%. Debug
/// and profile builds keep the keyword check so the app stays usable without it.
bool guardianGateOpen(GuardianStatus status, {bool release = kReleaseMode}) => !release || status is GuardianReady;

/// Runs the exported multi-task encoder from ml/therapylink_ml/train/guardian.py.
///
/// Nothing heavy runs on the UI isolate: the vocabulary is parsed and every message tokenized in a
/// [TokenizerWorker] isolate, and inference goes through the ONNX Runtime plugin's asynchronous
/// API, which runs it natively. What stays here is a few small JSON files and the softmax over
/// eight scores.
class OnnxGuardian implements Guardian {
  OnnxGuardian._(this._session, this._tok, this._labels, this._thresholds, this._multi, this._routeConfidence);

  final OrtSession _session;
  final TokenizerWorker _tok;
  final Map<String, List<String>> _labels;
  final Map<String, List<double>> _thresholds;
  final Set<String> _multi;
  final double _routeConfidence;

  static Future<OnnxGuardian> load([GuardianFiles? files]) async {
    final store = files ?? DiskGuardianFiles();
    final dir = await store.dir();
    Future<String> read(String f) => store.readString('$dir/$f');
    final config = jsonDecode(await read('config.json')) as Map<String, dynamic>;
    final thresholds = (jsonDecode(await read('thresholds.json')) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List).map((x) => (x as num).toDouble()).toList()));
    final labels = (config['tasks'] as Map<String, dynamic>).map((k, v) => MapEntry(k, List<String>.from(v)));
    final multi = Set<String>.from(config['multi_label'] ?? const []);
    final confident = (config['route_confidence'] as num?)?.toDouble() ?? defaultRouteConfidence;
    final tok = await TokenizerWorker.spawn('$dir/spm_vocab.json');
    try {
      final session = await OnnxRuntime().createSession('$dir/guardian.int8.onnx');
      return OnnxGuardian._(session, tok, labels, thresholds, multi, confident);
    } catch (_) {
      tok.close();
      rethrow;
    }
  }

  /// Loads the model and runs the canaries; throws if either fails.
  static Future<OnnxGuardian> loadChecked() async {
    final model = await load();
    try {
      await checkCanaries(model);
    } catch (_) {
      await model.close();
      rethrow;
    }
    return model;
  }

  Future<void> close() async {
    _tok.close();
    await _session.close();
  }

  /// Long text is read in overlapping windows and the verdicts merged, so risk past the first
  /// ~126 tokens is still seen.
  @override
  Future<GuardianVerdict> classify(String text) async =>
      mergeVerdicts([for (final ids in await _tok.encodeWindows(text)) await _classifyIds(ids)], confident: _routeConfidence);

  Future<GuardianVerdict> _classifyIds(List<int> ids) async {
    final shape = [1, ids.length];
    final inputs = {
      'input_ids': await OrtValue.fromList(ids, shape),
      'attention_mask': await OrtValue.fromList(List<int>.filled(ids.length, 1), shape),
    };
    Map<String, OrtValue> outputs = const {};
    try {
      outputs = await _session.run(inputs);

      Future<Map<String, double>> scores(String task) async {
        final raw = outputs['${task}_logits'];
        if (raw == null) return {};
        return _probabilities(task, raw);
      }

      final crisisScores = await scores('crisis');
      final fired = _overThreshold('crisis', crisisScores);
      final emotionScores = await scores('emotion');
      final condition = await scores('condition');

      return GuardianVerdict(
        crisis: fired.isNotEmpty,
        crisisScores: crisisScores,
        valence: _valence(condition, emotionScores),
        emotion: emotionScores.isEmpty ? null : emotionScores.entries.reduce((a, b) => a.value >= b.value ? a : b).key,
        kind: routeCrisis(fired, crisisScores, confident: _routeConfidence),
        labels: fired,
      );
    } finally {
      // Native tensors are not garbage collected; one leak per message adds up over a conversation.
      for (final v in [...inputs.values, ...outputs.values]) {
        await v.dispose();
      }
    }
  }

  Future<Map<String, double>> _probabilities(String task, OrtValue raw) async {
    final logits = (await raw.asFlattenedList()).map((x) => (x as num).toDouble()).toList();
    final labels = _labels[task]!;
    if (_multi.contains(task)) {
      return {for (var i = 0; i < labels.length; i++) labels[i]: 1 / (1 + math.exp(-logits[i]))};
    }
    final m = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - m)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return {for (var i = 0; i < labels.length; i++) labels[i]: exps[i] / sum};
  }

  /// Every label over its threshold, other than 'none'.
  Set<String> _overThreshold(String task, Map<String, double> probs) {
    final labels = _labels[task];
    final thr = _thresholds[task];
    if (labels == null || probs.isEmpty) return const {};
    return {
      for (var i = 0; i < labels.length; i++)
        if (labels[i] != 'none' && (probs[labels[i]] ?? 0) >= (thr != null && i < thr.length ? thr[i] : 0.5)) labels[i],
    };
  }

  static int _valence(Map<String, double> condition, Map<String, double> emotion) {
    if (condition.isNotEmpty) {
      final normal = condition['normal'] ?? 0;
      final low = (condition['depression'] ?? 0) + (condition['anxiety'] ?? 0) + (condition['suicidal'] ?? 0);
      if (low > 0.75) return -2;
      if (low > 0.5) return -1;
      if (normal > 0.85 && (emotion['joy'] ?? emotion['gratitude'] ?? 0) > 0.4) return 1;
      return 0;
    }
    return 0;
  }
}

/// How long a message waits for the trained model before the keyword verdict stands on its own.
/// Guardian v1b takes 24 to 63 ms per window on a laptop CPU; a slow phone is several times that,
/// and the first message also waits for the model to load. Past this a send goes ahead.
const guardianModelBudget = Duration(seconds: 3);

/// After this many messages in a row that the model didn't answer in time, it is reported as not
/// working on this phone, rather than left installed while it never reads anything.
const guardianTimeoutsBeforeFailure = 5;

/// Runs the trained model *and* the keyword check, and treats either firing as a crisis.
///
/// On Guardian v1b's 1,242 held-out messages (English, Roman Urdu, Urdu script and mixed) the model
/// caught 97.2% of crises and keywords 29.6%; together they caught 97.5%, Urdu script being where
/// keywords still add the most. The cost is asymmetric by design: a false positive shows someone a
/// helpline, a false negative shows them nothing.
///
/// The keyword check always runs first and always counts. The model gets [budget] per message: if
/// it is still loading, slow, or fails to load, run or pass its canaries, the keyword verdict stands
/// for this message, so a send is never held up by the model and never goes out without the floor.
/// A failure, or [guardianTimeoutsBeforeFailure] timeouts in a row, is reported through
/// [onFailure] so it is visible instead of swallowed.
class UnionGuardian implements Guardian {
  UnionGuardian(this._model, this._keywords, {void Function(Object error)? onFailure, this.budget = guardianModelBudget})
      : _onFailure = onFailure {
    // The load starts before the first message; a failure before then is handled at that message,
    // not reported as an uncaught error.
    _model.then<void>((_) {}, onError: (Object _) {});
  }

  final Future<Guardian> _model;
  final Guardian _keywords;
  final void Function(Object error)? _onFailure;
  final Duration budget;
  int _timeouts = 0;
  bool _failed = false;

  @override
  Future<GuardianVerdict> classify(String text) async {
    final keyword = await _keywords.classify(text);
    if (_failed) return keyword;
    GuardianVerdict? model;
    try {
      model = await _model.then((m) => m.classify(text)).timeout(budget);
      _timeouts = 0;
    } on TimeoutException catch (e) {
      debugPrint('onnx guardian took longer than $budget, keyword result stands');
      if (++_timeouts >= guardianTimeoutsBeforeFailure) _report(e);
    } catch (e) {
      debugPrint('onnx guardian unavailable, keyword result stands: $e');
      _report(e);
    }
    if (model == null) return keyword;
    return union(keyword, model);
  }

  void _report(Object e) {
    if (_failed) return;
    _failed = true;
    _onFailure?.call(e);
  }

  /// Closes the model if it loaded.
  Future<void> close() async {
    try {
      final m = await _model;
      if (m is OnnxGuardian) await m.close();
    } catch (_) {}
  }
}

/// The keyword and model verdicts as one: a crisis if either says so, every label either fired,
/// each score its higher, and the route chosen again from all of them by [crisisPriority]. A
/// keyword hit scores 0.9, so it always takes part in the priority.
GuardianVerdict union(GuardianVerdict keyword, GuardianVerdict model, {double confident = defaultRouteConfidence}) {
  final crisis = model.crisis || keyword.crisis;
  final labels = {if (keyword.crisis) ...keyword.labels, if (model.crisis) ...model.labels};
  final scores = maxScores([keyword.crisisScores, model.crisisScores]);
  return GuardianVerdict(
    crisis: crisis,
    crisisScores: scores,
    // The model's valence is better calibrated than counting keywords, so prefer it.
    valence: model.valence,
    emotion: model.emotion ?? keyword.emotion,
    kind: crisis ? (routeCrisis(labels, scores, confident: confident) ?? (keyword.crisis ? keyword.kind : model.kind)) : null,
    labels: labels,
  );
}

final guardianProvider = Provider<Guardian>((ref) {
  final status = ref.watch(guardianModelManagerProvider);
  final keywords = HeuristicGuardian();
  if (status is! GuardianReady) return NegationAwareGuardian(keywords);
  final manager = ref.read(guardianModelManagerProvider.notifier);
  final union = UnionGuardian(OnnxGuardian.loadChecked(), keywords, onFailure: manager.fail);
  ref.onDispose(union.close);
  return NegationAwareGuardian(union);
});
