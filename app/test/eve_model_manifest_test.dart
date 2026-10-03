import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/ml/eve_engine.dart';
import 'package:therapylink/core/ml/eve_model_manifest.dart';

/// hashlib.sha256 of ml/therapylink_ml/prompts.py EVE_SYSTEM_PROMPT_V1 and _V2: what
/// eve_sft.trained_prompt_manifest writes into training_prompt.json for each.
const _v1Sha = 'efe956512c6fd444727276e18c6d44f31ac134aef950c2e8f572bc51f7fa6573';
const _v2Sha = '4ddd5346276cb9afd3d537ba7595353f7807c40f67011de53e7a3b34c135202c';

void main() {
  group('training prompt manifest', () {
    test('the served prompt is byte for byte the v2 prompt ml trained v16-clean on', () {
      // In v3 Eve runs server-side and SERVED_SYSTEM_PROMPT == EVE_SYSTEM_PROMPT_V2.
      // test_prompt_parity.py (in ml/) enforces this on every merge.
      expect(promptSha256(eveSystemPrompt), _v2Sha);
    });

    test('reads training_prompt.json as ml writes it', () {
      final json = jsonDecode('{"prompt": "v2", "sha256": "${_v2Sha.toUpperCase()}"}') as Map<String, dynamic>;
      final p = EveTrainingPrompt.fromJson(json);
      expect(p.version, 'v2');
      expect(p.sha256, _v2Sha);
    });

    test('a model trained on the served prompt passes the mismatch check', () {
      expect(evePromptMismatch(const EveTrainingPrompt(version: 'v2', sha256: _v2Sha)), isNull);
    });

    test('a model trained on the v1 prompt is refused, naming both', () {
      final reason = evePromptMismatch(const EveTrainingPrompt(version: 'v1', sha256: _v1Sha));
      expect(reason, isNotNull);
      expect(reason, contains('v1'));
      expect(reason, contains(_v1Sha.substring(0, 12)));
      expect(reason, contains(_v2Sha.substring(0, 12)));
    });

    test('a model is refused if the app serves a whitespace-modified prompt', () {
      final trained = const EveTrainingPrompt(version: 'v2', sha256: _v2Sha);
      expect(evePromptMismatch(trained, served: '$eveSystemPrompt '), isNotNull);
      expect(evePromptMismatch(trained, served: eveSystemPrompt.replaceAll('\n', '\r\n')), isNotNull);
    });

    test('normalizeSha256 trims whitespace and lowercases', () {
      expect(normalizeSha256('  ${_v2Sha.toUpperCase()}  '), _v2Sha);
    });
  });
}
