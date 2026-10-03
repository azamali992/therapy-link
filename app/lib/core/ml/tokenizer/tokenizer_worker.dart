import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'sentencepiece.dart';

/// The Guardian's tokenizer in an isolate of its own.
///
/// Parsing the 9 MB vocabulary and running the Unigram search over a long message both take long
/// enough on a phone to drop frames, so neither happens on the UI isolate. The worker reads the
/// vocabulary from disk itself, keeps the tokenizer for its lifetime, and answers one message at a
/// time with the token windows for it.
class TokenizerWorker {
  TokenizerWorker._(this._isolate, this._inbox);

  final Isolate _isolate;
  final SendPort _inbox;

  /// Starts the worker on the vocabulary JSON at [vocabPath]. Throws if it can't be read or parsed.
  static Future<TokenizerWorker> spawn(String vocabPath) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(_main, (port.sendPort, vocabPath), debugName: 'guardian-tokenizer');
    final first = await port.first;
    port.close();
    if (first is SendPort) return TokenizerWorker._(isolate, first);
    isolate.kill(priority: Isolate.immediate);
    throw StateError('guardian tokenizer failed to load: $first');
  }

  /// Token ids for [text] in model-sized windows (see [SentencePieceTokenizer.encodeWindows]).
  Future<List<List<int>>> encodeWindows(String text) async {
    final reply = ReceivePort();
    try {
      _inbox.send((text, reply.sendPort));
      final out = await reply.first;
      if (out is List<List<int>>) return out;
      throw StateError('guardian tokenizer failed: $out');
    } finally {
      reply.close();
    }
  }

  void close() => _isolate.kill(priority: Isolate.immediate);

  static void _main((SendPort, String) args) {
    final (out, path) = args;
    final SentencePieceTokenizer tok;
    try {
      tok = SentencePieceTokenizer.fromJson(File(path).readAsStringSync());
    } catch (e) {
      out.send('$e');
      return;
    }
    final inbox = ReceivePort();
    out.send(inbox.sendPort);
    inbox.listen((message) {
      final (text, reply) = message as (String, SendPort);
      try {
        reply.send(tok.encodeWindows(text));
      } catch (e) {
        reply.send('$e');
      }
    });
  }
}
