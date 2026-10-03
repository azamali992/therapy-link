import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/ml/eve_engine.dart';
import '../../core/ml/guardian.dart';
import '../../core/ml/onnx_guardian.dart';
import '../../core/settings/settings.dart';
import '../shared/crisis_copy.dart';
import 'conversations_repository.dart';
import 'crisis_mode.dart';
import 'exercise_cards.dart';
import 'memory.dart';
import 'output_guard.dart';

const kConversationId = 'default';
const _uuid = Uuid();

/// The open conversation's id; switching it is how 'New conversation' works.
final conversationIdProvider = Provider<String>((ref) => ref.watch(settingsProvider.select((s) => s.conversationId)));

final eveMessagesProvider = StreamProvider<List<Message>>((ref) => ref.watch(databaseProvider).watchMessages(ref.watch(conversationIdProvider)));

/// The step agreed last time, offered as a way back in when a new conversation opens.
final followUpProvider = Provider<Memory?>((ref) {
  if (!ref.watch(settingsProvider.select((s) => s.memoryEnabled))) return null;
  return latestPlan(ref.watch(memoriesProvider).value ?? const []);
});

/// A crisis card in the transcript. It is rendered from crisis_copy.dart and helplines.dart and is
/// never sent to the model.
const crisisRole = 'crisis';

String crisisContent(CrisisKind kind, CrisisLanguage language) => '${kind.label}|${language.name}';

({CrisisKind kind, CrisisLanguage language}) parseCrisis(String content) {
  final parts = content.split('|');
  return (
    kind: CrisisKind.fromLabel(parts.first) ?? CrisisKind.suicide,
    language: parts.length > 1 && parts[1] == CrisisLanguage.romanUrdu.name ? CrisisLanguage.romanUrdu : CrisisLanguage.en,
  );
}

@immutable
class EveState {
  const EveState({
    this.generating = false,
    this.partial = '',
    this.crisisPending = false,
    this.crisisKind = CrisisKind.suicide,
    this.crisisLanguage = CrisisLanguage.en,
    this.suggestGrounding = false,
    this.suggestBreak = false,
  });

  final bool generating;
  final String partial;

  /// The crisis sheet should open. [crisisKind] and [crisisLanguage] say which lines and words.
  final bool crisisPending;
  final CrisisKind crisisKind;
  final CrisisLanguage crisisLanguage;

  /// Offer a breathing exercise inline. Set after a run of low turns, cleared for the rest of the
  /// session the moment it is dismissed — a suggestion that keeps returning is nagging.
  final bool suggestGrounding;

  /// A once-per-session nudge toward a break or a real person after a long stretch of talking.
  final bool suggestBreak;

  EveState copyWith({
    bool? generating,
    String? partial,
    bool? crisisPending,
    CrisisKind? crisisKind,
    CrisisLanguage? crisisLanguage,
    bool? suggestGrounding,
    bool? suggestBreak,
  }) => EveState(
    generating: generating ?? this.generating,
    partial: partial ?? this.partial,
    crisisPending: crisisPending ?? this.crisisPending,
    crisisKind: crisisKind ?? this.crisisKind,
    crisisLanguage: crisisLanguage ?? this.crisisLanguage,
    suggestGrounding: suggestGrounding ?? this.suggestGrounding,
    suggestBreak: suggestBreak ?? this.suggestBreak,
  );
}

/// Shown in the chat when a reply fails. It is saved so the person can see what happened, but never
/// sent back to the model as something Eve said — one real conversation held eight of them.
const eveFailureReply = "I'm having trouble replying right now. I'm still here — try again in a moment.";

/// How much conversation the model is given verbatim, in characters, newest first. Anything older
/// reaches it through the rolling summary instead.
///
/// On-device Gemma runs with 4,096 tokens for prompt and reply together: the system prompt takes
/// ~250–400, memory and summary notes up to ~900, a reply up to 450, which leaves ~2,300 for
/// history. Gemma's tokenizer averages about three characters per token on English and Roman Urdu
/// chat, so 6,000 characters keeps a margin.
const historyCharBudget = 6000;

/// The history sent to the model: newest messages that fit the budget, failure placeholders left
/// out, then normalised to strict user/assistant alternation starting with the user.
@visibleForTesting
List<Map<String, String>> buildHistory(List<Message> rows, {int charBudget = historyCharBudget}) {
  final kept = <Message>[];
  var used = 0;
  for (final m in rows.reversed) {
    if (!_isTurn(m)) continue;
    // The newest message always goes in, even alone over budget: dropping what was just said is worse.
    if (kept.isNotEmpty && used + m.content.length > charBudget) break;
    kept.add(m);
    used += m.content.length;
  }
  return EveController.normalise(kept.reversed.toList());
}

bool _isTurn(Message m) => m.role == 'user' || (m.role == 'assistant' && m.content != eveFailureReply);

/// Turns the summary and memory notes may be written from. A message Guardian flagged is left out:
/// what someone said in crisis should not become a standing note that follows them into later
/// conversations. Crisis cards are not turns at all, so they never get this far.
bool _isNoteworthy(Message m) => _isTurn(m) && !m.flagged;

/// Consecutive low turns before grounding is offered. Three is enough to be a run rather than one
/// bad sentence, and few enough to arrive while it is still useful.
const _groundingAfter = 3;

/// Messages sent in one sitting before Eve suggests a pause. Heavy daily use of chatbots for emotional
/// support tracks with loneliness and dependence (OpenAI and MIT Media Lab, 2025), so a long session
/// ends with a gentle pointer outward, once.
const _breakAfter = 40;

/// How far back earlier messages count toward a crisis read. Risk often only shows across messages
/// ("I lost my job" … "which bridges are tallest"), which single-message checks miss.
const _crisisWindow = Duration(minutes: 20);

/// Longest passage the cross-turn check builds. The trained Guardian reads long text in windows
/// (onnx_guardian.dart), so this only bounds the work, and the current message always comes first.
const _crossTurnChars = 2000;

/// While crisis mode repeats the card on every turn, the sheet interrupts at most this often.
const _sheetEvery = Duration(minutes: 10);

class EveController extends Notifier<EveState> {
  int _lowStreak = 0;
  bool _groundingDeclined = false;
  int _sentThisSession = 0;
  bool _breakShown = false;
  DateTime? _lastSheet;

  /// Set synchronously as a turn or a wrap-up starts, before anything awaits, so a double tap can't
  /// start a second one in the gap before [EveState.generating] is seen.
  bool _busy = false;

  /// The crisis reading of the message being sent, taken before anything is saved.
  ({CrisisKind kind, CrisisLanguage language})? _earlyCrisis;

  /// Every engine call, replies, summaries, memory notes and wrap-ups, runs through this queue one
  /// at a time: on the phone there is a single model, and two calls into it at once is a crash.
  Future<void> _queue = Future.value();

  /// Conversations deleted this session. Upkeep for one may already be queued or halfway through a
  /// model call when it goes; it checks here before writing anything, so nothing new is remembered
  /// from a conversation the person has deleted.
  final _deleted = <String>{};

  DateTime? _lastStamp;

  /// A timestamp for the next row. Drift stores times to the second, and rows that share a second
  /// can come back in either order, so each row written here is at least a second after the last:
  /// a crisis card must never sort above the message that raised it.
  DateTime _stamp() {
    final now = DateTime.now();
    final last = _lastStamp;
    final next = last == null || now.difference(last) >= const Duration(seconds: 1) ? now : last.add(const Duration(seconds: 1));
    return _lastStamp = next;
  }

  @override
  EveState build() => const EveState();

  String get _conversation => ref.read(conversationIdProvider);

  /// Puts an exercise card into the chat. Exercise rows never reach the model.
  Future<void> startExercise(String id) async {
    final db = ref.read(databaseProvider);
    await db.upsertConversation(_conversation);
    await db.addMessage(MessagesCompanion.insert(id: _uuid.v4(), conversationId: _conversation, role: exerciseRole, content: exerciseContent(id), createdAt: _stamp()));
  }

  Future<void> finishExercise(String messageId, String id) =>
      ref.read(databaseProvider).setMessageContent(messageId, exerciseContent(id, done: true));

  /// Opens a fresh thread. A conversation with nothing in it is reused rather than stacked. What is
  /// worth keeping from the old one is written down on the way out.
  Future<void> newConversation() async {
    // Mid-reply the old thread is still being written to; switching now would strand that reply
    // and queue a closing pass on top of it.
    if (_busy) return;
    final previous = _conversation;
    if (await ref.read(databaseProvider).countMessages(previous) == 0) return;
    _lowStreak = 0;
    _groundingDeclined = false;
    state = const EveState();
    await ref.read(settingsProvider.notifier).setConversationId(_uuid.v4());
    _schedule(() => _maintain(previous, closing: true));
  }

  /// Switches to an earlier conversation from the list. Refused (false) while Eve is mid-reply,
  /// for the same reason as [newConversation]. The one being left is read for memories on the way.
  Future<bool> openConversation(String id) async {
    if (_busy) return false;
    final previous = _conversation;
    if (id == previous) return true;
    _lowStreak = 0;
    _groundingDeclined = false;
    state = const EveState();
    await ref.read(settingsProvider.notifier).setConversationId(id);
    _schedule(() => _maintain(previous, closing: true));
    return true;
  }

  /// Deletes one conversation and its messages; memory notes already made from it stay, and no new
  /// ones are made. If it was the open one, a fresh conversation takes its place. Deleting the open
  /// one mid-reply is refused (false): the reply would be written into a thread that no longer exists.
  Future<bool> deleteConversation(String id) async {
    final open = id == _conversation;
    if (open && _busy) return false;
    // Marked before anything awaits, so an upkeep pass that is mid model call sees it on its way back.
    _deleted.add(id);
    await ref.read(conversationsRepositoryProvider).delete(id);
    if (open) {
      _lowStreak = 0;
      _groundingDeclined = false;
      state = const EveState();
      await ref.read(settingsProvider.notifier).setConversationId(_uuid.v4());
    }
    return true;
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    _busy = true;
    _earlyCrisis = null;
    state = state.copyWith(generating: true, partial: '');
    try {
      await _turn(trimmed);
    } catch (e) {
      debugPrint('eve turn failed: $e');
      // The message was classified before anything was saved. If saving failed afterwards (a locked
      // or unopenable database), the person still gets the crisis sheet: help cannot depend on storage.
      final early = _earlyCrisis;
      if (early != null && ref.mounted) {
        state = state.copyWith(crisisPending: true, crisisKind: early.kind, crisisLanguage: early.language);
      }
    } finally {
      _busy = false;
      if (ref.mounted) state = state.copyWith(generating: false, partial: '');
    }
  }

  Future<void> _turn(String trimmed) async {
    final db = ref.read(databaseProvider);
    final guardian = ref.read(guardianProvider);
    final crisisMode = ref.read(crisisModeProvider.notifier);
    final language = crisisLanguageOf(trimmed);

    // Classified before any write, so a storage failure cannot hide a crisis (see send). A classifier
    // failure still saves what the person wrote, then ends the turn: no reply goes out unchecked.
    GuardianVerdict verdict = GuardianVerdict.none;
    Object? guardianError;
    try {
      verdict = await guardian.classify(trimmed);
    } catch (e) {
      guardianError = e;
    }
    if (verdict.kind case final kind?) _earlyCrisis = (kind: kind, language: language);

    final conversation = _conversation;
    await db.upsertConversation(conversation);
    final userId = _uuid.v4();
    final now = _stamp();
    await db.addMessage(MessagesCompanion.insert(id: userId, conversationId: conversation, role: 'user', content: trimmed, createdAt: now));
    _sentThisSession++;
    if (guardianError != null) throw guardianError;

    final sticky = crisisMode.active;
    final recent = await db.recentMessages(conversation, limit: 120);
    final kind = verdict.kind ?? await _crisisAcrossTurns(recent, userId, now, includeFlagged: sticky);
    // Valence and emotion stay on the message, on the phone. Chat-derived mood is not uploaded:
    // only check-ins the person makes themselves reach the server.
    await db.setMessageAnalysis(userId, valence: verdict.valence, emotion: verdict.emotion, flagged: kind != null);

    if (kind != null) {
      // Crisis has its own path and the model is never asked; a breathing suggestion here would be
      // trivialising.
      _lowStreak = 0;
      await crisisMode.activate(kind, now: now);
      await _addCrisisCard(conversation, kind, language);
      final sheet = _lastSheet == null || now.difference(_lastSheet!) >= _sheetEvery;
      if (sheet) _lastSheet = now;
      state = state.copyWith(crisisPending: sheet, crisisKind: kind, crisisLanguage: language);
      return;
    }

    _lowStreak = verdict.valence <= -1 ? _lowStreak + 1 : 0;
    final offer = _lowStreak >= _groundingAfter && !_groundingDeclined && !sticky;
    final nudge = !_breakShown && _sentThisSession >= _breakAfter;
    if (nudge) _breakShown = true;

    final context = await _context(conversation, recent, query: trimmed, severe: verdict.valence <= -2 || sticky);
    final engine = ref.read(eveEngineProvider);

    final removedNote = CrisisCopy.of(language).numberRemoved;
    var reply = await _serial(() => _generate(engine, context.history, context.notes, removedNote));
    // One retry when the reply opens the way a recent one did: identical openers are what makes a
    // companion feel mechanical. The second answer is kept whatever it says.
    if (reply != eveFailureReply && repeatsOpener(reply, context.recentReplies)) {
      final second = await _serial(() => _generate(engine, context.history, context.notes, removedNote));
      if (second != eveFailureReply) reply = second;
    }
    final guarded = guardReplyNumbers(reply, replacement: removedNote);
    if (guarded.text.isNotEmpty) {
      await db.addMessage(MessagesCompanion.insert(id: _uuid.v4(), conversationId: conversation, role: 'assistant', content: guarded.text, createdAt: _stamp()));
    }
    // In crisis mode every reply is followed by the lines, whatever Eve said; and a reply that
    // reached for a number of its own gets the real ones next to it.
    if (sticky || guarded.removed > 0) {
      await _addCrisisCard(conversation, sticky ? ref.read(crisisModeProvider).kind : CrisisKind.suicide, language);
    }
    state = EveState(suggestGrounding: offer, suggestBreak: nudge || state.suggestBreak, generating: true);
    _schedule(() => _maintain(conversation));
  }

  Future<void> _addCrisisCard(String conversation, CrisisKind kind, CrisisLanguage language) => ref.read(databaseProvider).addMessage(
    MessagesCompanion.insert(id: _uuid.v4(), conversationId: conversation, role: crisisRole, content: crisisContent(kind, language), createdAt: _stamp()),
  );

  /// Closes the session the way a counsellor would: what was talked about, and one small step to try.
  /// The step is kept so the next conversation can start from it. False if there was too little to
  /// wrap up or the model did not answer in the expected shape.
  Future<bool> wrapUp({required String Function(String step) nextStepLabel}) async {
    if (_busy) return false;
    _busy = true;
    try {
      return await _wrapUp(nextStepLabel);
    } finally {
      _busy = false;
    }
  }

  Future<bool> _wrapUp(String Function(String step) nextStepLabel) async {
    final db = ref.read(databaseProvider);
    final conversation = _conversation;
    final recent = await db.recentMessages(conversation, limit: 120);
    if (recent.where((m) => m.role == 'user').length < 2) return false;
    // A "small step to try" is the wrong note to end on within the hour after a crisis.
    final sticky = ref.read(crisisModeProvider.notifier).active;

    state = state.copyWith(generating: true, partial: '');
    try {
      final convo = await db.conversationById(conversation);
      final turns = _unsummarised(recent, convo);
      // Flagged turns stay out, as they do for the summary and memory passes: the wrap-up is saved
      // as an ordinary reply that those passes then read, and its step is kept as a plan note, so
      // anything it repeated from a crisis turn would become a standing note one step removed.
      final window = turns.sublist(messagesToSummarise(turns, charBudget: historyCharBudget).length).where(_isNoteworthy).toList();
      if (!window.any((m) => m.role == 'user')) return false;
      final engine = ref.read(eveEngineProvider);
      // The wrap-up is Eve talking too, so it gets the same number guard as a reply.
      final lastUser = recent.lastWhere((m) => m.role == 'user').content;
      final language = crisisLanguageOf(lastUser);
      final removedNote = CrisisCopy.of(language).numberRemoved;
      final raw = (await _serial(() => engine.complete(wrapUpSummaryRequest(turns: window, summary: convo?.summary), maxTokens: 200))).trim();
      if (raw.isEmpty) return false;
      final summary = guardReplyNumbers(raw, replacement: removedNote);
      state = state.copyWith(partial: summary.text);
      final rawStep = sticky ? null : cleanStep(await _serial(() => engine.complete(wrapUpStepRequest(turns: window), maxTokens: 60)));
      final step = rawStep == null ? null : guardReplyNumbers(rawStep, replacement: removedNote);
      await db.addMessage(MessagesCompanion.insert(
        id: _uuid.v4(),
        conversationId: conversation,
        role: 'assistant',
        content: step == null ? summary.text : '${summary.text}\n\n${nextStepLabel(step.text)}',
        createdAt: _stamp(),
      ));
      if (sticky || summary.removed + (step?.removed ?? 0) > 0) {
        await _addCrisisCard(conversation, sticky ? ref.read(crisisModeProvider).kind : CrisisKind.suicide, language);
      }
      if (step != null && ref.read(settingsProvider).memoryEnabled) {
        await _remember([(kind: 'plan', content: step.text)], conversation);
      }
      _schedule(() => _maintain(conversation, closing: true));
      return true;
    } catch (e) {
      debugPrint('wrap-up failed: $e');
      return false;
    } finally {
      if (ref.mounted) state = const EveState();
    }
  }

  void crisisShown() => state = state.copyWith(crisisPending: false);

  void dismissBreak() => state = state.copyWith(suggestBreak: false);

  /// Dismissed by the user. Stays gone for the rest of the session.
  void declineGrounding() {
    _groundingDeclined = true;
    _lowStreak = 0;
    state = state.copyWith(suggestGrounding: false);
  }

  /// Accepted: the exercise opens right here in the chat instead of on another tab.
  Future<void> groundingTaken() async {
    _lowStreak = 0;
    state = state.copyWith(suggestGrounding: false);
    await startExercise('sigh');
  }

  /// Chat templates need user/assistant alternation starting with user; merge runs and trim leading assistant turns.
  static List<Map<String, String>> normalise(List<Message> rows) {
    final out = <Map<String, String>>[];
    for (final m in rows) {
      if (m.role != 'user' && m.role != 'assistant') continue;
      if (out.isEmpty && m.role != 'user') continue;
      if (out.isNotEmpty && out.last['role'] == m.role) {
        out.last['content'] = '${out.last['content']}\n${m.content}';
      } else {
        out.add({'role': m.role, 'content': m.content});
      }
    }
    return out;
  }

  // -------------------------------------------------------------------------------------------

  /// Re-reads the last few minutes of what the person said as one passage, so risk spread across
  /// messages is caught. Messages already flagged are left out, or one crisis would re-trigger on
  /// every message after it, except in crisis mode, where that is the point.
  ///
  /// The current message goes first: the trained Guardian reads the head of a long passage, and
  /// the old order put what was just said at the tail, where a long earlier message pushed it out.
  Future<CrisisKind?> _crisisAcrossTurns(List<Message> recent, String currentId, DateTime now, {bool includeFlagged = false}) async {
    final earlier = recent
        .where((m) => m.role == 'user' && m.id != currentId && (includeFlagged || !m.flagged) && now.difference(m.createdAt) <= _crisisWindow)
        .toList();
    if (earlier.isEmpty) return null;
    final current = recent.firstWhere((m) => m.id == currentId);
    final last = earlier.skip(earlier.length > 2 ? earlier.length - 2 : 0);
    var joined = [current.content, ...last.toList().reversed.map((m) => m.content)].join('\n');
    if (joined.length > _crossTurnChars) joined = joined.substring(0, _crossTurnChars);
    try {
      return (await ref.read(guardianProvider).classify(joined)).kind;
    } catch (e) {
      debugPrint('context crisis check skipped: $e');
      return null;
    }
  }

  List<Message> _unsummarised(List<Message> rows, Conversation? convo) {
    final through = convo?.summarizedThrough;
    return [for (final m in rows) if (_isTurn(m) && (through == null || m.createdAt.isAfter(through))) m];
  }

  Future<({List<Map<String, String>> history, String? notes, List<String> recentReplies})> _context(
    String conversation,
    List<Message> recent, {
    required String query,
    bool severe = false,
  }) async {
    final db = ref.read(databaseProvider);
    final convo = await db.conversationById(conversation);
    final replies = [for (final m in recent.reversed) if (m.role == 'assistant' && m.content != eveFailureReply) m.content].take(3).toList();
    // On a severely low turn the model gets plain history: with notes present v14 still named a
    // helpline less often on crisis probes (9/14 vs 12/14), and this is where that matters most.
    // Without notes the summary cannot stand in for older turns, so the window is history only.
    if (!eveUnderstandsNotes || severe) {
      return (history: buildHistory(recent), notes: null, recentReplies: replies);
    }
    final turns = _unsummarised(recent, convo);
    final memories = ref.read(settingsProvider).memoryEnabled ? selectMemories(await db.allMemories(), query: query) : const <Memory>[];
    return (history: buildHistory(turns), notes: buildContextNotes(memories: memories, summary: convo?.summary), recentReplies: replies);
  }

  /// Streams a reply into [EveState.partial]. What is shown is guarded as it arrives, so a foreign
  /// number is never on screen, not even before the finished reply is guarded and saved.
  Future<String> _generate(EveEngine engine, List<Map<String, String>> history, String? notes, String removedNote) async {
    final buffer = StringBuffer();
    state = state.copyWith(partial: '');
    try {
      await for (final token in engine.reply(history, notes: notes)) {
        buffer.write(token);
        state = state.copyWith(partial: guardStreamingText(buffer.toString(), replacement: removedNote));
      }
    } catch (e) {
      debugPrint('eve reply failed: $e');
      if (buffer.isEmpty) return eveFailureReply;
    }
    return buffer.toString().trim();
  }

  /// Runs [task] after every engine call queued before it.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _schedule(Future<void> Function() task) {
    _serial(task).onError((Object e, StackTrace _) => debugPrint('eve upkeep deferred: $e'));
  }

  /// Keeps a conversation within reach of a small model: condenses what has scrolled out of the
  /// window into the rolling summary, then writes down what is worth remembering. [closing] means the
  /// conversation is ending, so even a short stretch is read for memories.
  Future<void> _maintain(String conversation, {bool closing = false}) async {
    final db = ref.read(databaseProvider);
    final engine = ref.read(eveEngineProvider);
    bool gone() => _deleted.contains(conversation) || !ref.mounted;
    final convo = await db.conversationById(conversation);
    if (convo == null || gone()) return;
    final rows = await db.recentMessages(conversation, limit: 200);
    if (gone()) return;

    // Summarise a few turns at a time, and before they leave the window rather than after, so
    // nothing falls between the summary and the verbatim history.
    final unsummarised = _unsummarised(rows, convo);
    final older = messagesToSummarise(unsummarised, charBudget: historyCharBudget * 3 ~/ 4);
    // Flagged turns are dropped from what the model reads, not from the span, so the summary still
    // covers through the same point and they leave the verbatim window on schedule.
    final quoted = older.where(_isNoteworthy).toList();
    if (older.length >= 4 && quoted.isNotEmpty) {
      final summary = (await engine.complete(summaryRequest(previous: convo.summary, turns: quoted), maxTokens: 300)).trim();
      if (gone()) return;
      if (summary.isNotEmpty) await db.setSummary(conversation, summary, older.last.createdAt);
    }

    if (!ref.read(settingsProvider).memoryEnabled) return;
    final through = convo.rememberedThrough;
    final unread = [for (final m in rows) if (_isTurn(m) && (through == null || m.createdAt.isAfter(through))) m];
    if (unread.length < (closing ? 2 : rememberEvery)) return;
    final window = unread.sublist(messagesToSummarise(unread, charBudget: 5000).length).where(_isNoteworthy).toList();
    if (window.isNotEmpty) {
      final existing = await db.allMemories();
      if (gone()) return;
      final raw = await engine.complete(memoryRequest(existing: existing, turns: window), maxTokens: 250);
      if (gone()) return;
      await _remember(parseMemories(raw, existing: existing.map((m) => m.content)), conversation, existing: existing);
    }
    await db.setRememberedThrough(conversation, unread.last.createdAt);
  }

  Future<void> _remember(List<MemoryCandidate> candidates, String conversation, {List<Memory>? existing}) async {
    if (candidates.isEmpty) return;
    final db = ref.read(databaseProvider);
    final change = consolidate(candidates, existing ?? await db.allMemories());
    // Checked with nothing awaited between here and the write.
    if (_deleted.contains(conversation)) return;
    final now = DateTime.now();
    await db.applyMemoryChanges(
      add: [
        for (final c in change.add)
          MemoriesCompanion.insert(id: _uuid.v4(), kind: c.kind, content: c.content, conversationId: Value(conversation), createdAt: now),
      ],
      remove: change.remove,
    );
  }
}

final eveControllerProvider = NotifierProvider<EveController, EveState>(EveController.new);