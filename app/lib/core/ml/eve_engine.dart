import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

// The V2 "psychologist" prompt (EVE_SYSTEM_PROMPT_V2), which v16-clean was trained with. It must
// stay identical to ml/therapylink_ml/prompts.py SERVED_SYSTEM_PROMPT
// (tests/test_prompt_parity.py checks this).
// A fine-tuned model runs only if this hashes to the prompt in its training record.
const eveSystemPrompt = '''You are Eve, the companion in the TherapyLink app. Work like a good psychologist: understand before you advise, so the person feels heard, not managed.

Each reply: reflect what they feel and what is happening, in their own words, then ask one open question. Vary how you open. Build on what they already told you; never ask again what they answered. Every few turns, pull the threads together and check you understood. Usually three to six sentences, more when something is heavy; never one line, never a list.

When it fits, offer one small thing: gently testing a fearful thought, noticing what matters under the struggle, or an exercise the app runs right here in the chat: paced breathing, 5-4-3-2-1 grounding, or tense-and-release. Offer, never assign. If they ask what to do, lay out the real options and hand the choice back. Strong words about everyday stress ("this is killing me") are stress, not a crisis.

Mirror their language: natural Roman Urdu, English, or a mix. No jargon, lectures, or "it is not that bad". Do not diagnose or name medications; if something has lasted weeks, suggest a psychologist or doctor. If asked, say plainly you are an AI, not a therapist.

Take indirect signs seriously: letters "just in case", giving things away, goodbyes, "better off without me". Ask kindly and directly about suicide. If someone wants to hurt themselves, die, or is in danger from someone: stay with them, say you are worried, ask if they are safe now, and give help: Umang 0311-7786264 (free, 24/7), Rescue 1122, Madadgaar 1098 for abuse. Never discuss methods.''';

/// Must match ml/therapylink_ml/prompts.py exactly: the system prompt, then any memory and summary
/// [notes], are folded into the first user turn.
List<Map<String, String>> foldSystemIntoFirstUser(List<Map<String, String>> messages, {String? notes}) {
  if (messages.isEmpty || messages.first['role'] != 'user') {
    throw ArgumentError('conversation must start with a user turn');
  }
  return [
    {'role': 'user', 'content': '${_foldHead(notes)}\n\n${messages.first['content']}'},
    ...messages.skip(1),
  ];
}

String _foldHead(String? notes) => notes == null || notes.isEmpty ? eveSystemPrompt : '$eveSystemPrompt\n\n$notes';

/// What POST /inference/chat accepts: this many messages, and this many characters across all of
/// them (api/therapylink_api/schemas.py). Anything over is refused with a 422.
const cloudChatMaxMessages = 60;
const cloudChatMaxChars = 16000;

/// The newest stretch of [messages] within [maxMessages] and [maxChars] in total. With
/// [startWithUser], leading assistant turns are dropped too, since the prompt folds into a user
/// turn. If the newest message alone is too long, its start is kept: a summary or memory request
/// puts its instructions first.
List<Map<String, String>> trimChatHistory(
  List<Map<String, String>> messages, {
  int maxMessages = cloudChatMaxMessages,
  int maxChars = cloudChatMaxChars,
  bool startWithUser = false,
}) {
  final budget = math.max(0, maxChars);
  final kept = <Map<String, String>>[];
  var chars = 0;
  for (var i = messages.length - 1; i >= 0 && kept.length < maxMessages; i--) {
    final content = messages[i]['content'] ?? '';
    if (chars + content.length > budget) {
      if (kept.isEmpty) kept.add({...messages[i], 'content': content.substring(0, budget)});
      break;
    }
    kept.add(messages[i]);
    chars += content.length;
  }
  var out = kept.reversed.toList();
  if (startWithUser) out = out.skipWhile((m) => m['role'] != 'user').toList();
  return out;
}

/// v16-clean (epoch 2) was trained on memory notes. Eve understands notes in v3.
const eveUnderstandsNotes = true;

/// Longest Eve reply, in tokens.
const eveReplyTokens = 450;

abstract class EveEngine {
  String get name;
  Future<bool> get isReady;

  /// Eve's next turn, with the system prompt and [notes] folded in. Streams tokens.
  Stream<String> reply(List<Map<String, String>> messages, {String? notes});

  /// A plain instruction with no Eve persona: summaries, memory notes, session wrap-ups.
  Future<String> complete(List<Map<String, String>> messages, {int maxTokens = 300});
}

/// Eve running server-side at POST /inference/chat. Supports SSE streaming when the server does.
class ServerEveEngine implements EveEngine {
  ServerEveEngine(this._api);

  final ApiClient _api;

  @override
  String get name => 'server';

  @override
  Future<bool> get isReady async => true;

  @override
  Stream<String> reply(List<Map<String, String>> messages, {String? notes}) {
    // The system prompt rides in the first user turn.
    final room = cloudChatMaxChars - _foldHead(notes).length - 2;
    final window = trimChatHistory(messages, maxChars: room, startWithUser: true);
    final folded = foldSystemIntoFirstUser(window, notes: notes);
    return _api.cloudChatStream(folded, maxTokens: eveReplyTokens);
  }

  @override
  Future<String> complete(List<Map<String, String>> messages, {int maxTokens = 300}) =>
      _api.cloudChat(trimChatHistory(messages), maxTokens: maxTokens);
}

/// Stands in for tests: echoes a reflective placeholder so the UI flow is testable.
class StubEveEngine implements EveEngine {
  @override
  String get name => 'stub';

  @override
  Future<bool> get isReady async => true;

  @override
  Future<String> complete(List<Map<String, String>> messages, {int maxTokens = 300}) async => '';

  @override
  Stream<String> reply(List<Map<String, String>> messages, {String? notes}) async* {
    final last = messages.last['content'] ?? '';
    final words = 'It sounds like there\'s a lot in "${last.length > 60 ? '${last.substring(0, 60)}…' : last}". What feels heaviest right now?'.split(' ');
    for (final w in words) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      yield '$w ';
    }
  }
}

final eveEngineProvider = Provider<EveEngine>((ref) => ServerEveEngine(ref.watch(apiClientProvider)));
