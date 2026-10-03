import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/tokenizer/sentencepiece.dart';

// Fixtures come from ml/: `tokenizer_json dump` and `tokenizer_reference dump`, copied into
// test/fixtures/ (gitignored — 8 MB). The test skips when they are absent so CI stays green.
void main() {
  final vocab = File('test/fixtures/spm_vocab.json');
  final reference = File('test/fixtures/tokenizer_reference.json');
  final available = vocab.existsSync() && reference.existsSync();

  test('Dart unigram tokenizer matches Hugging Face XLM-R ids on eval probes', () {
    final tok = SentencePieceTokenizer.fromJson(vocab.readAsStringSync());
    final cases = (jsonDecode(reference.readAsStringSync()) as Map<String, dynamic>)['cases'] as List;
    var mismatches = <String>[];
    for (final c in cases) {
      final expected = List<int>.from(c['ids']);
      final got = tok.encode(c['text'] as String);
      if (got.join(',') != expected.join(',')) {
        mismatches.add('${c['text']}\n  expected $expected\n  got      $got');
      }
    }
    expect(mismatches, isEmpty, reason: '${mismatches.length}/${cases.length} mismatches:\n${mismatches.take(5).join('\n')}');
  }, skip: available ? false : 'fixtures missing — run the ml/ export commands first');
}
