import 'dart:convert';
import 'dart:math' as math;

/// Unigram SentencePiece tokenizer (the XLM-RoBERTa flavour), reimplemented in Dart because no
/// SentencePiece runtime exists for Flutter. Loads the JSON written by
/// ml/therapylink_ml/export/tokenizer_json.py and reproduces the ids XLM-R's HF tokenizer emits.
class SentencePieceTokenizer {
  SentencePieceTokenizer._({
    required List<String> pieces,
    required List<double> scores,
    required this.fairseqOffset,
    required this.bosId,
    required this.eosId,
    required this.unkId,
    required this.padId,
    required this.maxLen,
  })  : _scores = scores,
        _index = {for (var i = 0; i < pieces.length; i++) pieces[i]: i},
        _maxPieceChars = pieces.fold(0, (m, p) => math.max(m, p.length)),
        _unkScore = scores.reduce(math.min) - 10.0;

  factory SentencePieceTokenizer.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final special = data['special'] as Map<String, dynamic>;
    return SentencePieceTokenizer._(
      pieces: List<String>.from(data['pieces']),
      scores: (data['scores'] as List).map((s) => (s as num).toDouble()).toList(),
      fairseqOffset: data['fairseq_offset'] as int? ?? 1,
      bosId: special['bos'] as int,
      eosId: special['eos'] as int,
      unkId: special['unk'] as int,
      padId: special['pad'] as int,
      maxLen: data['max_len'] as int? ?? 128,
    );
  }

  final Map<String, int> _index;
  final List<double> _scores;
  final int _maxPieceChars;
  final double _unkScore;
  final int fairseqOffset;
  final int bosId;
  final int eosId;
  final int unkId;
  final int padId;
  final int maxLen;

  static const _space = '▁';

  /// SentencePiece pieces (before the fairseq id shift) for [text].
  List<String> pieces(String text) {
    final norm = _normalise(text);
    if (norm.isEmpty) return const [];
    final chars = norm.runes.map(String.fromCharCode).toList();
    final n = chars.length;
    final best = List<double>.filled(n + 1, double.negativeInfinity);
    final back = List<int>.filled(n + 1, -1);
    final backPiece = List<String?>.filled(n + 1, null);
    best[0] = 0;

    final prefix = List<String>.filled(n + 1, '');
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + chars[i];
    }

    for (var i = 0; i < n; i++) {
      if (best[i] == double.negativeInfinity) continue;
      final limit = math.min(n, i + _maxPieceChars);
      var matched = false;
      for (var j = i + 1; j <= limit; j++) {
        final piece = prefix[j].substring(prefix[i].length);
        final id = _index[piece];
        if (id == null) continue;
        matched = true;
        final score = best[i] + _scores[id];
        if (score > best[j]) {
          best[j] = score;
          back[j] = i;
          backPiece[j] = piece;
        }
      }
      if (!matched) {
        final score = best[i] + _unkScore;
        if (score > best[i + 1]) {
          best[i + 1] = score;
          back[i + 1] = i;
          backPiece[i + 1] = chars[i];
        }
      }
    }

    final out = <String>[];
    var pos = n;
    while (pos > 0) {
      out.add(backPiece[pos]!);
      pos = back[pos];
    }
    return out.reversed.toList();
  }

  /// Token ids in XLM-R's id space: `<s> … </s>`, truncated to [maxLen].
  List<int> encode(String text) {
    final ids = <int>[bosId];
    for (final p in pieces(text)) {
      final raw = _index[p];
      ids.add(raw == null ? unkId : raw + fairseqOffset);
      if (ids.length >= maxLen - 1) break;
    }
    ids.add(eosId);
    return ids;
  }

  /// Token ids for [text] in overlapping windows of at most [maxLen], each wrapped `<s> … </s>`.
  ///
  /// [encode] keeps only the head, so a crisis sentence after the first ~126 tokens of a long
  /// message was never seen by the model. Classifying every window and ORing the results closes
  /// that. [overlap] keeps a phrase that falls on a boundary whole in one window; past
  /// [maxWindows] the last window is moved to the end, since what was said last matters most.
  List<List<int>> encodeWindows(String text, {int overlap = 32, int maxWindows = 8}) {
    final body = [for (final p in pieces(text)) _index[p] == null ? unkId : _index[p]! + fairseqOffset];
    final size = maxLen - 2;
    if (body.length <= size) return [[bosId, ...body, eosId]];
    final stride = math.max(1, size - overlap);
    final out = <List<int>>[];
    var end = 0;
    for (var start = 0; out.length < maxWindows && end < body.length; start += stride) {
      end = math.min(start + size, body.length);
      out.add([bosId, ...body.sublist(start, end), eosId]);
    }
    if (end < body.length) out[out.length - 1] = [bosId, ...body.sublist(body.length - size), eosId];
    return out;
  }

  String _normalise(String text) {
    final collapsed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';
    return _space + collapsed.replaceAll(' ', _space);
  }
}
