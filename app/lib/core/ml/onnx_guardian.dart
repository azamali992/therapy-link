import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'guardian.dart';
import 'sha256.dart';
import 'tokenizer/sentencepiece.dart';

/// Where the trained Guardian lives. Filled in once ml/ publishes runs/guardian → Hugging Face.
const guardianRepoBase = String.fromEnvironment('TL_GUARDIAN_URL', defaultValue: '');
const _files = ['guardian.int8.onnx', 'spm_vocab.json', 'config.json', 'thresholds.json'];

/// SHA-256 of each published Guardian file. Filled in by ml/ with the release; until then every
/// download fails verification, because a model nobody can vouch for must not decide who sees a
/// helpline. Supplied at build time as `--dart-define=TL_GUARDIAN_SHA256=<file>:<hex>,<file>:<hex>…`.
const _hashesDefine = String.fromEnvironment('TL_GUARDIAN_SHA256', defaultValue: '');

Map<String, String> _parseHashes(String define) => {
  for (final pair in define.split(',').where((p) => p.contains(':')))
    pair.substring(0, pair.indexOf(':')).trim(): pair.substring(pair.indexOf(':') + 1).trim().toLowerCase(),
};

final guardianFileHashes = _parseHashes(_hashesDefine);

/// Written next to the files once every hash has matched. Startup trusts the files only if this
/// holds the hashes the build expects, so a partial or swapped file never counts as installed.
const _verifiedMarker = 'verified.json';

@immutable
sealed class GuardianStatus {
  const GuardianStatus();
}

class GuardianHeuristic extends GuardianStatus {
  const GuardianHeuristic();
}

class GuardianDownloading extends GuardianStatus {
  const GuardianDownloading(this.percent);

  final int percent;
}

class GuardianReady extends GuardianStatus {
  const GuardianReady();
}

class GuardianFailed extends GuardianStatus {
  const GuardianFailed(this.message);

  final String message;
}

/// Where the Guardian's files are kept. Behind an interface so install and verification can be
/// tested without a network or a disk.
abstract class GuardianFiles {
  Future<String> dir();
  Future<void> download(String url, String path, void Function(int got, int total) onProgress);
  Stream<List<int>> read(String path);
  Future<bool> exists(String path);
  Future<void> rename(String from, String to);
  Future<void> delete(String path);
  Future<String> readString(String path);
  Future<void> writeString(String path, String content);
}

class DiskGuardianFiles implements GuardianFiles {
  @override
  Future<String> dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/guardian');
    await d.create(recursive: true);
    return d.path;
  }

  @override
  Future<void> download(String url, String path, void Function(int got, int total) onProgress) =>
      Dio().download(url, path, onReceiveProgress: onProgress);

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
    for (final f in _files) {
      if (recorded[f] == null || recorded[f] != hashes[f] || !await files.exists('$dir/$f')) return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Downloads each file to `<name>.part`, checks its SHA-256 against [hashes], and only then moves
/// it into place. An interrupted or tampered download never sits at the path the loader reads.
/// Throws on any failure, leaving no marker behind.
Future<void> installGuardian(
  GuardianFiles files, {
  required String base,
  required Map<String, String> hashes,
  void Function(int percent)? onProgress,
}) async {
  final missing = [for (final f in _files) if ((hashes[f] ?? '').isEmpty) f];
  if (missing.isNotEmpty) throw StateError('no published checksum for ${missing.join(', ')}');
  final dir = await files.dir();
  await files.delete('$dir/$_verifiedMarker');
  for (var i = 0; i < _files.length; i++) {
    final f = _files[i];
    final part = '$dir/$f.part';
    await files.delete(part);
    await files.download('$base/$f', part, (got, total) {
      if (total > 0) onProgress?.call(((i + got / total) / _files.length * 100).round());
    });
    final actual = await Sha256.ofStream(files.read(part));
    if (actual != hashes[f]) {
      await files.delete(part);
      throw StateError('checksum mismatch for $f');
    }
    await files.delete('$dir/$f');
    await files.rename(part, '$dir/$f');
  }
  await files.writeString('$dir/$_verifiedMarker', jsonEncode({for (final f in _files) f: hashes[f]}));
}

/// Sentences the loaded model must get right before it is trusted. A model that loads but reads
/// nothing (a dtype mismatch, a wrong tokenizer) would otherwise pass silently with every verdict
/// 'none'. English only: Guardian v0 has no Roman Urdu, which the keyword check covers.
const guardianCanaries = [
  (text: 'I want to end my life tonight', crisis: true),
  (text: "I don't see any reason to keep living anymore", crisis: true),
  (text: 'I had lunch with my sister and we watched a film', crisis: false),
];

/// Throws unless [model] gives the expected verdict on every canary.
Future<void> checkCanaries(Guardian model) async {
  for (final c in guardianCanaries) {
    final v = await model.classify(c.text);
    if (v.crisis != c.crisis) throw StateError('canary failed: "${c.text}" read as crisis=${v.crisis}');
  }
}

class GuardianModelManager extends Notifier<GuardianStatus> {
  GuardianModelManager([GuardianFiles? files]) : _files = files ?? DiskGuardianFiles();

  final GuardianFiles _files;

  @override
  GuardianStatus build() {
    if (!kIsWeb) {
      guardianInstalled(_files, guardianFileHashes).then((ok) {
        if (ok && ref.mounted && state is GuardianHeuristic) state = const GuardianReady();
      }).catchError((Object e) {
        if (ref.mounted) state = GuardianFailed('$e');
      });
    }
    return const GuardianHeuristic();
  }

  bool get available => guardianRepoBase.isNotEmpty && !kIsWeb;

  Future<void> download() async {
    if (!available || state is GuardianDownloading) return;
    state = const GuardianDownloading(0);
    try {
      await installGuardian(_files, base: guardianRepoBase, hashes: guardianFileHashes, onProgress: (p) => state = GuardianDownloading(p));
      state = const GuardianReady();
    } catch (e) {
      debugPrint('guardian install failed: $e');
      state = GuardianFailed('$e');
    }
  }

  /// The model loaded but failed to run or failed its canaries. Keywords carry on alone, and the
  /// failure is shown rather than hidden behind "Trained model installed".
  void fail(Object error) {
    debugPrint('guardian failed: $error');
    if (ref.mounted) state = GuardianFailed('$error');
  }
}

final guardianModelManagerProvider = NotifierProvider<GuardianModelManager, GuardianStatus>(GuardianModelManager.new);

/// Whether Eve may chat. In a release build the trained Guardian must be installed and working:
/// keywords alone caught 2 of 17 crisis probes. Debug and profile builds keep the keyword check so
/// the app stays usable while the model is unpublished.
bool guardianGateOpen(GuardianStatus status, {bool release = kReleaseMode}) => !release || status is GuardianReady;

/// Runs the exported multi-task encoder from ml/therapylink_ml/train/guardian.py.
class OnnxGuardian implements Guardian {
  OnnxGuardian._(this._session, this._tok, this._labels, this._thresholds, this._multi);

  final OrtSession _session;
  final SentencePieceTokenizer _tok;
  final Map<String, List<String>> _labels;
  final Map<String, List<double>> _thresholds;
  final Set<String> _multi;

  static Future<OnnxGuardian> load([GuardianFiles? files]) async {
    final store = files ?? DiskGuardianFiles();
    final dir = await store.dir();
    Future<String> read(String f) => store.readString('$dir/$f');
    final config = jsonDecode(await read('config.json')) as Map<String, dynamic>;
    final thresholds = (jsonDecode(await read('thresholds.json')) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List).map((x) => (x as num).toDouble()).toList()));
    final labels = (config['tasks'] as Map<String, dynamic>).map((k, v) => MapEntry(k, List<String>.from(v)));
    final multi = Set<String>.from(config['multi_label'] ?? const []);
    final session = await OnnxRuntime().createSession('$dir/guardian.int8.onnx');
    return OnnxGuardian._(session, SentencePieceTokenizer.fromJson(await read('spm_vocab.json')), labels, thresholds, multi);
  }

  /// Loads the model and runs the canaries; throws if either fails.
  static Future<OnnxGuardian> loadChecked() async {
    final model = await load();
    await checkCanaries(model);
    return model;
  }

  /// Long text is read in overlapping windows and the verdicts merged, so risk past the first
  /// ~126 tokens is still seen.
  @override
  Future<GuardianVerdict> classify(String text) async =>
      mergeVerdicts([for (final ids in _tok.encodeWindows(text)) await _classifyIds(ids)]);

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
      final crisisLabel = _topOverThreshold('crisis', crisisScores);
      final emotionScores = await scores('emotion');
      final condition = await scores('condition');

      return GuardianVerdict(
        crisis: crisisLabel != null,
        crisisScores: crisisScores,
        valence: _valence(condition, emotionScores),
        emotion: emotionScores.isEmpty ? null : emotionScores.entries.reduce((a, b) => a.value >= b.value ? a : b).key,
        kind: CrisisKind.fromLabel(crisisLabel),
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

  /// The highest-scoring label over its threshold, other than 'none'; null if there is none.
  String? _topOverThreshold(String task, Map<String, double> probs) {
    final labels = _labels[task];
    final thr = _thresholds[task];
    if (labels == null || probs.isEmpty) return null;
    String? best;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] == 'none') continue;
      final p = probs[labels[i]] ?? 0;
      if (p >= (thr != null && i < thr.length ? thr[i] : 0.5) && (best == null || p > probs[best]!)) best = labels[i];
    }
    return best;
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

/// Runs the trained model *and* the keyword check, and treats either firing as a crisis.
///
/// Measured on the hand-written probes, the model beats keywords overall (53% vs 12%) but scores
/// **0% on Roman Urdu, where keywords get 25%** — it has no Roman Urdu in its training data. A
/// union is therefore strictly safer than either alone. The cost is asymmetric by design: a false
/// positive shows someone a helpline, a false negative shows them nothing.
///
/// If the model fails to load, fails its canaries or fails to run, the keyword verdict stands for
/// this message and [onFailure] reports it, so the failure is visible instead of swallowed.
class UnionGuardian implements Guardian {
  UnionGuardian(this._model, this._keywords, {void Function(Object error)? onFailure}) : _onFailure = onFailure {
    // The load starts before the first message; a failure before then is handled at that message,
    // not reported as an uncaught error.
    _model.then<void>((_) {}, onError: (Object _) {});
  }

  final Future<Guardian> _model;
  final Guardian _keywords;
  final void Function(Object error)? _onFailure;
  Guardian? _ready;

  @override
  Future<GuardianVerdict> classify(String text) async {
    final keyword = await _keywords.classify(text);
    GuardianVerdict? model;
    try {
      _ready ??= await _model;
      model = await _ready!.classify(text);
    } catch (e) {
      debugPrint('onnx guardian unavailable, keyword result stands: $e');
      _onFailure?.call(e);
    }
    if (model == null) return keyword;
    final crisis = model.crisis || keyword.crisis;
    return GuardianVerdict(
      crisis: crisis,
      crisisScores: {...keyword.crisisScores, ...model.crisisScores},
      // The model's valence is better calibrated than counting keywords, so prefer it.
      valence: model.valence,
      emotion: model.emotion ?? keyword.emotion,
      // Keywords name abuse and child risk that Guardian v0 has no labels for.
      kind: keyword.crisis ? keyword.kind : model.kind,
    );
  }
}

final guardianProvider = Provider<Guardian>((ref) {
  final status = ref.watch(guardianModelManagerProvider);
  final keywords = HeuristicGuardian();
  if (status is! GuardianReady) return keywords;
  final manager = ref.read(guardianModelManagerProvider.notifier);
  return UnionGuardian(OnnxGuardian.loadChecked(), keywords, onFailure: manager.fail);
});
