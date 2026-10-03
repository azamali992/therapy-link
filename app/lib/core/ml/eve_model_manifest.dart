import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'eve_engine.dart';
import 'sha256.dart';

/// In v3 Eve runs server-side. This file keeps the prompt-parity machinery (EveTrainingPrompt,
/// evePromptMismatch, promptSha256) so test_prompt_parity.py can check the served prompt hash.
/// The on-device model registry (GemmaEveEngine, EveModelSpec, eveModelSpecs) is dropped.

/// SHA-256 of the file at [path], read in chunks off the UI isolate.
Future<String> sha256OfFile(String path) => compute(_hashFile, path);

Future<String> _hashFile(String path) => Sha256.ofStream(File(path).openRead());

/// [hex] the way this app compares digests: trimmed and lowercase, as Sha256 prints them.
String normalizeSha256(String hex) => hex.trim().toLowerCase();

/// Which system prompt a fine-tuned model was trained with: the `training_prompt.json` that
/// ml/therapylink_ml/train/eve_sft.py writes next to every adapter and export/merge.py carries
/// into the served checkpoint.
@immutable
class EveTrainingPrompt {
  const EveTrainingPrompt({required this.version, required this.sha256});

  /// Reads `{"prompt": "v2", "sha256": "<hex>"}` as ml writes it.
  factory EveTrainingPrompt.fromJson(Map<String, dynamic> json) => EveTrainingPrompt(
        version: json['prompt'] as String? ?? '',
        sha256: normalizeSha256(json['sha256'] as String? ?? ''),
      );

  /// The label ml gives the prompt: v1, v2 or custom.
  final String version;

  /// SHA-256 of the prompt's UTF-8 bytes, lowercase hex.
  final String sha256;
}

/// SHA-256 of [prompt] the way ml hashes it: its UTF-8 bytes, lowercase hex.
String promptSha256(String prompt) => Sha256.of(utf8.encode(prompt));

/// Checks that [served] matches what v16-clean was trained on. Returns a problem string, or null.
///
/// The prompt is part of the model: v14 with the wrong prompt dropped from 18/24 to 12/24 on
/// safety probes. So the served prompt must match the training record exactly.
String? evePromptMismatch(EveTrainingPrompt trained, {String served = eveSystemPrompt}) {
  final actual = promptSha256(served);
  if (trained.sha256 != actual) {
    return 'The Eve model was trained with prompt ${trained.version} (${_short(trained.sha256)}), '
        'but this app serves a different one (${_short(actual)}).';
  }
  return null;
}

String _short(String hex) => hex.length > 12 ? hex.substring(0, 12) : hex;
