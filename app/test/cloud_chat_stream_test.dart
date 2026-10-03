// Tests for ApiClient.cloudChatStream — the Eve-wire SSE parser.
//
// Verifies that the client correctly parses the server's normalised SSE
// contract: delta events, done events, error events, keep-alive lines, and
// multi-byte UTF-8 sequences (Urdu) split across chunk boundaries.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/api/api_client.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A Dio [HttpClientAdapter] that serves a streaming SSE response from the
/// given byte chunks.
class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this._chunks);

  final List<Uint8List> _chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream.fromIterable(_chunks),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Encode [text] as the server's normalised SSE bytes (UTF-8).
Uint8List sseBytes(String text) => Uint8List.fromList(utf8.encode(text));

/// Build a complete normalised SSE response for the given delta strings.
String sseResponse(List<String> deltas, {String finishReason = 'stop'}) {
  final buf = StringBuffer();
  for (final d in deltas) {
    buf.write('data: ${jsonEncode({'delta': d})}\n\n');
  }
  buf.write('data: ${jsonEncode({'done': true, 'finish_reason': finishReason})}\n\n');
  return buf.toString();
}

/// Create an [ApiClient] whose HTTP adapter returns the given SSE [chunks].
ApiClient _clientWith(List<Uint8List> chunks) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  dio.httpClientAdapter = _SseAdapter(chunks);
  return ApiClient(dio);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('cloudChatStream — Eve-wire SSE parser', () {
    final messages = [
      {'role': 'user', 'content': 'hello'}
    ];

    // -----------------------------------------------------------------------
    // Happy path
    // -----------------------------------------------------------------------

    test('yields delta text from delta events', () async {
      final raw = sseResponse(['Hello', ' world']);
      final client = _clientWith([sseBytes(raw)]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens, ['Hello', ' world']);
    });

    test('ends stream on done event', () async {
      final raw = 'data: {"delta":"hi"}\n\n'
          'data: {"done":true,"finish_reason":"stop"}\n\n'
          'data: {"delta":"ignored"}\n\n'; // must not be yielded
      final client = _clientWith([sseBytes(raw)]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens, ['hi']);
    });

    test('ends stream on legacy [DONE] marker', () async {
      final raw = 'data: {"delta":"tok"}\n\n'
          'data: [DONE]\n\n'
          'data: {"delta":"ignored"}\n\n';
      final client = _clientWith([sseBytes(raw)]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens, ['tok']);
    });

    test('ignores lines that do not start with data:', () async {
      final raw = ': keep-alive\n\n'
          'data: {"delta":"ok"}\n\n'
          ': another comment\n\n'
          'data: {"done":true,"finish_reason":"stop"}\n\n';
      final client = _clientWith([sseBytes(raw)]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens, ['ok']);
    });

    test('ignores malformed JSON in data lines', () async {
      final raw = 'data: not-json\n\n'
          'data: {"delta":"real"}\n\n'
          'data: {"done":true,"finish_reason":"stop"}\n\n';
      final client = _clientWith([sseBytes(raw)]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens, ['real']);
    });

    test('does not yield empty delta strings', () async {
      final raw = 'data: {"delta":""}\n\n'
          'data: {"delta":"word"}\n\n'
          'data: {"done":true,"finish_reason":"stop"}\n\n';
      final client = _clientWith([sseBytes(raw)]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens, ['word']);
    });

    // -----------------------------------------------------------------------
    // Error path
    // -----------------------------------------------------------------------

    test('throws EveRestingException on error event', () async {
      final raw = 'data: {"error":"eve_resting"}\n\n';
      final client = _clientWith([sseBytes(raw)]);
      expect(
        () => client.cloudChatStream(messages).toList(),
        throwsA(isA<EveRestingException>()),
      );
    });

    // -----------------------------------------------------------------------
    // UTF-8 multi-byte decoding
    // -----------------------------------------------------------------------

    test('decodes Urdu correctly from a single chunk', () async {
      const urdu = 'آپ کیسے ہیں'; // "How are you?" — each char is 2–3 UTF-8 bytes
      final raw = sseResponse([urdu]);
      final client = _clientWith([sseBytes(raw)]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens.join(), urdu);
    });

    test('decodes Urdu split across chunk boundaries correctly', () async {
      /// This is the parallel of the API-side test.
      ///
      /// The server emits:
      ///   data: {"delta":"آپ"}\n\n
      ///   data: {"done":true,"finish_reason":"stop"}\n\n
      ///
      /// We split the raw bytes in the middle of the UTF-8 encoding of "آپ" to
      /// confirm that utf8.decoder + LineSplitter reassembles the character
      /// correctly, whereas String.fromCharCodes would corrupt it.
      const urdu = 'آپ'; // U+0622 U+067E → \xd8\xa2 \xd9\xbe
      final raw = sseBytes(
        'data: ${jsonEncode({'delta': urdu})}\n\n'
        'data: {"done":true,"finish_reason":"stop"}\n\n',
      );
      // Split right in the middle of the Urdu UTF-8 bytes.
      final mid = raw.length ~/ 2;
      final chunk1 = Uint8List.sublistView(raw, 0, mid);
      final chunk2 = Uint8List.sublistView(raw, mid);

      final client = _clientWith([chunk1, chunk2]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens.join(), urdu);
    });

    test('decodes emoji (multi-byte) split across chunks', () async {
      const emoji = '😊💙'; // each is 4 UTF-8 bytes
      final raw = sseBytes(
        'data: ${jsonEncode({'delta': emoji})}\n\n'
        'data: {"done":true,"finish_reason":"stop"}\n\n',
      );
      final mid = raw.length ~/ 2;
      final client = _clientWith([
        Uint8List.sublistView(raw, 0, mid),
        Uint8List.sublistView(raw, mid),
      ]);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens.join(), emoji);
    });

    // -----------------------------------------------------------------------
    // Chunk-boundary line reassembly
    // -----------------------------------------------------------------------

    test('reassembles lines split across many small chunks', () async {
      final raw = sseBytes(sseResponse(['token1', 'token2']));
      // Split into 3-byte pieces to force many partial-line chunks.
      final chunks = <Uint8List>[];
      for (var i = 0; i < raw.length; i += 3) {
        chunks.add(Uint8List.sublistView(raw, i, (i + 3).clamp(0, raw.length)));
      }
      final client = _clientWith(chunks);
      final tokens = await client.cloudChatStream(messages).toList();
      expect(tokens, ['token1', 'token2']);
    });
  });
}
