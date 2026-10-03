import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/tokenizer/sentencepiece.dart';

SentencePieceTokenizer _toy() {
  // Tiny unigram vocab. Higher score = more likely. '▁' marks a word start, as in SentencePiece.
  final pieces = ['<unk>', '▁', '▁i', '▁feel', '▁fee', 'l', '▁low', '▁lo', 'w', 'mujhe', '▁mujhe', '▁udaas', 'a', 's'];
  final scores = [-20.0, -5.0, -2.0, -1.0, -6.0, -3.0, -1.5, -7.0, -4.0, -8.0, -2.5, -2.0, -6.0, -6.0];
  return SentencePieceTokenizer.fromJson(jsonEncode({
    'fairseq_offset': 1,
    'special': {'bos': 0, 'eos': 2, 'unk': 3, 'pad': 1},
    'pieces': pieces,
    'scores': scores,
    'max_len': 16,
  }));
}

void main() {
  final tok = _toy();

  test('viterbi prefers whole-word pieces over fragments', () {
    expect(tok.pieces('i feel low'), ['▁i', '▁feel', '▁low']);
  });

  test('splits Roman Urdu into known pieces', () {
    expect(tok.pieces('mujhe udaas'), ['▁mujhe', '▁udaas']);
  });

  test('unknown characters become single-char unk pieces rather than failing', () {
    final p = tok.pieces('feel ☃');
    expect(p.first, '▁feel');
    expect(p.last, '☃');
  });

  test('encode wraps with bos/eos and applies the fairseq offset', () {
    final ids = tok.encode('i feel');
    expect(ids.first, 0);
    expect(ids.last, 2);
    expect(ids.sublist(1, ids.length - 1), [2 + 1, 3 + 1]);
  });

  test('encode truncates to max_len', () {
    final ids = tok.encode(List.filled(40, 'low').join(' '));
    expect(ids.length, lessThanOrEqualTo(16));
    expect(ids.last, 2);
  });

  group('windows over long text', () {
    test('short text is one window, the same as encode', () {
      expect(tok.encodeWindows('i feel low'), [tok.encode('i feel low')]);
    });

    test('long text is covered to the end, each window wrapped and within max_len', () {
      // 40 content tokens with max_len 16: the head-only encode never sees 'udaas' at the end.
      final text = '${List.filled(39, 'low').join(' ')} udaas';
      expect(tok.encode(text), isNot(contains(11 + 1)));
      final windows = tok.encodeWindows(text, overlap: 4);
      expect(windows.length, greaterThan(1));
      for (final w in windows) {
        expect(w.length, lessThanOrEqualTo(16));
        expect(w.first, 0);
        expect(w.last, 2);
      }
      expect(windows.last, contains(11 + 1));
    });

    test('past the window cap the last window still ends at the end of the text', () {
      final text = '${List.filled(200, 'low').join(' ')} udaas';
      final windows = tok.encodeWindows(text, overlap: 4, maxWindows: 3);
      expect(windows, hasLength(3));
      expect(windows.last[windows.last.length - 2], 11 + 1);
    });
  });
}
