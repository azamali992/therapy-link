// Ported from v2 app/test/api_errors_test.dart "cloud chat fits the server limits".
//
// Verifies that ServerEveEngine and trimChatHistory keep every request within
// the API's hard limits (cloudChatMaxMessages / cloudChatMaxChars) and that the
// system prompt is always folded into the first user turn before sending.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/api/api_client.dart';
import 'package:therapylink/core/ml/eve_engine.dart';

// ---------------------------------------------------------------------------
// Minimal ApiClient stub — captures what the engine sends without network I/O.
// ---------------------------------------------------------------------------

class _ChatApi extends ApiClient {
  _ChatApi() : super(Dio(BaseOptions(baseUrl: 'http://test.invalid')));

  /// Messages captured from cloudChatStream calls (ServerEveEngine.reply).
  final List<List<Map<String, String>>> sentStream = [];

  /// Messages captured from cloudChat calls (ServerEveEngine.complete).
  final List<List<Map<String, String>>> sentComplete = [];

  @override
  Stream<String> cloudChatStream(
    List<Map<String, String>> messages, {
    int maxTokens = 450,
  }) async* {
    sentStream.add(List.unmodifiable(messages));
    yield 'I hear you.';
  }

  @override
  Future<String> cloudChat(
    List<Map<String, String>> messages, {
    int maxTokens = 450,
  }) async {
    sentComplete.add(List.unmodifiable(messages));
    return 'I hear you.';
  }

  /// complete() goes through the background path (long timeout, never blocks chat).
  @override
  Future<String?> cloudChatBackground(
    List<Map<String, String>> messages, {
    int maxTokens = 300,
  }) async {
    sentComplete.add(List.unmodifiable(messages));
    return 'I hear you.';
  }
}

// ---------------------------------------------------------------------------
// Helpers (mirror the v2 test helpers).
// ---------------------------------------------------------------------------

/// Build a conversation of [n] alternating user/assistant turns, each with
/// [charsEach] characters of content.
List<Map<String, String>> _history(int n, int charsEach) => [
  for (var i = 0; i < n; i++)
    {'role': i.isEven ? 'user' : 'assistant', 'content': '$i:'.padRight(charsEach, 'x')},
];

/// Total character count across all message content strings.
int _chars(List<Map<String, String>> m) =>
    m.fold(0, (s, e) => s + (e['content']?.length ?? 0));

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------

void main() {
  group('cloud chat fits the server limits', () {
    test('80 messages, 20k characters: at most 60 messages and 16k characters, newest kept', () {
      final history = _history(80, 250);
      // Confirm input size so the test documents its own preconditions.
      expect(_chars(history), 20000);
      final out = trimChatHistory(history);
      expect(out.length, lessThanOrEqualTo(cloudChatMaxMessages));
      expect(_chars(out), lessThanOrEqualTo(cloudChatMaxChars));
      // Newest turn is preserved.
      expect(out.last, history.last);
    });

    test('Eve reply: the folded request, system prompt included, stays within both limits', () async {
      final api = _ChatApi();
      // 79 messages (ends on a user turn — index 78 is even → user).
      final history = _history(79, 250);
      await ServerEveEngine(api).reply(history).toList();

      final sent = api.sentStream.single;
      expect(sent.length, lessThanOrEqualTo(cloudChatMaxMessages));
      expect(_chars(sent), lessThanOrEqualTo(cloudChatMaxChars));
      // System prompt is folded into the first user turn.
      expect(sent.first['role'], 'user');
      expect(sent.first['content'], startsWith(eveSystemPrompt));
      // Newest user turn content is preserved at the tail.
      expect(sent.last['content'], history.last['content']);
    });

    test('a short conversation goes as it is', () async {
      final api = _ChatApi();
      final history = _history(3, 40); // 3 turns, well within limits
      await ServerEveEngine(api).reply(history).toList();
      // Short history is sent as-is (just folded); nothing is trimmed.
      expect(api.sentStream.single, foldSystemIntoFirstUser(history));
    });

    test('a single message longer than the limit keeps its start', () async {
      final api = _ChatApi();
      // complete() uses the background path, not cloudChatStream.
      await ServerEveEngine(api).complete([
        {'role': 'user', 'content': 'Summarise:'.padRight(20000, 'y')},
      ]);
      final sent = api.sentComplete.single;
      expect(_chars(sent), cloudChatMaxChars);
      expect(sent.single['content'], startsWith('Summarise:'));
    });
  });
}
