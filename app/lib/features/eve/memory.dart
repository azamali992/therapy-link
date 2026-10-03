import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

/// How Eve keeps a conversation, and a relationship, going.
///
/// A small model cannot hold a long chat or remember last week, so the app does it for her, on the
/// pattern Mem0 (arXiv 2504.19413) showed is both cheaper and better than stuffing full history in:
/// * older turns that no longer fit are condensed into a rolling summary on the conversation;
/// * every few turns, candidate notes (people, situations, goals, what helped, agreed next steps) are
///   extracted, then consolidated against existing notes: repeat -> skip, same subject -> replace,
///   otherwise add. Mem0 does that step with a second LLM call and embeddings; on a phone it is word
///   overlap, which costs nothing;
/// * each turn, the notes most relevant to what was just said (plus the latest agreed step) are
///   folded in after the system prompt, under the headers below.
///
/// Everything here is pure except the provider, so the formats can be tested and kept identical to
/// ml/therapylink_ml/prompts.py, which trains the model on the same layout.

const memoryHeader = 'What you remember about this person from earlier conversations. Use it naturally and do not recite it back:';
const summaryHeader = 'Earlier in this conversation:';

const memoryKinds = ['person', 'situation', 'goal', 'helped', 'plan'];

/// Characters of memory notes given to the model per turn.
const memoryCharBudget = 1200;
const summaryCharCap = 1500;

/// New user and Eve turns since the last pass before notes are written again.
const rememberEvery = 8;

/// Notes kept in total, and agreed steps kept, before the oldest are let go.
const memoryCap = 60;
const planCap = 3;

final memoriesProvider = StreamProvider<List<Memory>>((ref) => ref.watch(databaseProvider).watchMemories());

typedef MemoryCandidate = ({String kind, String content});

// ---------------------------------------------------------------------------------------------
// What goes into the prompt

/// The block folded in after the system prompt, or null when there is nothing to add. [memories]
/// arrive already chosen and ordered (see [selectMemories]).
String? buildContextNotes({List<Memory> memories = const [], String? summary, int budget = memoryCharBudget}) {
  final parts = <String>[];
  final lines = <String>[];
  var used = 0;
  for (final m in memories) {
    final line = '- ${m.content}';
    if (used + line.length > budget) break;
    lines.add(line);
    used += line.length + 1;
  }
  if (lines.isNotEmpty) parts.add('$memoryHeader\n${lines.join('\n')}');
  final s = summary?.trim();
  if (s != null && s.isNotEmpty) {
    parts.add('$summaryHeader\n${s.length > summaryCharCap ? s.substring(0, summaryCharCap) : s}');
  }
  return parts.isEmpty ? null : parts.join('\n\n');
}

const _stop = {
  'the', 'and', 'for', 'with', 'that', 'this', 'they', 'them', 'their', 'have', 'has', 'was', 'were', 'are', 'but', 'not', 'you',
  'she', 'her', 'his', 'him', 'about', 'from', 'what', 'when', 'will', 'would', 'could', 'into', 'been', 'feel', 'feels',
  'hai', 'hain', 'hoon', 'aur', 'nahi', 'mein', 'main', 'mujhe', 'kya', 'bhi', 'woh', 'yeh', 'apne', 'apni', 'kar', 'raha', 'rahi',
};

Set<String> _words(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.length > 2 && !_stop.contains(w))
    .toSet();

/// Word-overlap similarity between two notes, 0..1.
double noteSimilarity(String a, String b) {
  final wa = _words(a), wb = _words(b);
  if (wa.isEmpty || wb.isEmpty) return 0;
  return wa.intersection(wb).length / wa.union(wb).length;
}

/// The notes worth putting in front of the model for this turn: only those that share words with
/// what was just said, best match first, ties to the most recent. [all] is newest first, as the
/// database returns it.
///
/// Unrelated notes are never sent. On the 48 safety probes, v14 with notes unrelated to the
/// message fell from 18/24 to 11/24 and answered the notes instead of the person; even two lines
/// scored 9/24 (ml/runs/eval/sft-v14-notes*). Following up on the last agreed step is done by the
/// app (the follow-up card), so it needs no place here.
List<Memory> selectMemories(List<Memory> all, {required String query, int budget = memoryCharBudget}) {
  if (all.isEmpty) return const [];
  final q = _words(query);
  if (q.isEmpty) return const [];
  double score(int index, Memory m) => _words(m.content).intersection(q).length * 2.0 + (1 - index / all.length);

  final ranked = [for (var i = 0; i < all.length; i++) (m: all[i], s: score(i, all[i]))]
    ..removeWhere((r) => r.s < 2)
    ..sort((a, b) => b.s.compareTo(a.s));
  final out = <Memory>[];
  var used = 0;
  for (final r in ranked) {
    final cost = r.m.content.length + 3;
    if (used + cost > budget) continue;
    out.add(r.m);
    used += cost;
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Keeping the store tidy

/// Mem0's update step, decided locally. Returns the notes to add and the ids to remove.
({List<MemoryCandidate> add, List<String> remove}) consolidate(
  List<MemoryCandidate> candidates,
  List<Memory> existing, {
  double duplicate = 0.8,
  double sameSubject = 0.45,
}) {
  final add = <MemoryCandidate>[];
  final remove = <String>{};
  final live = [...existing];
  for (final c in candidates) {
    Memory? best;
    var bestSim = 0.0;
    for (final m in live) {
      if (m.kind != c.kind || remove.contains(m.id)) continue;
      final sim = noteSimilarity(m.content, c.content);
      if (sim > bestSim) {
        bestSim = sim;
        best = m;
      }
    }
    final alreadyAdded = add.any((a) => a.kind == c.kind && noteSimilarity(a.content, c.content) >= duplicate);
    if (alreadyAdded || (best != null && bestSim >= duplicate)) continue; // NOOP
    if (best != null && bestSim >= sameSubject) remove.add(best.id); // UPDATE: the newer note wins
    add.add(c); // ADD
  }

  // Keep the store bounded: only the latest few agreed steps, and the newest notes overall.
  final kept = [for (final m in existing) if (!remove.contains(m.id)) m]; // newest first
  final plans = kept.where((m) => m.kind == 'plan').toList();
  final newPlans = add.where((a) => a.kind == 'plan').length;
  for (final old in plans.skip((planCap - newPlans).clamp(0, planCap))) {
    remove.add(old.id);
  }
  final remaining = kept.where((m) => !remove.contains(m.id)).toList();
  final overflow = remaining.length + add.length - memoryCap;
  if (overflow > 0) {
    for (final old in remaining.reversed.where((m) => m.kind != 'plan').take(overflow)) {
      remove.add(old.id);
    }
  }
  return (add: add, remove: remove.toList());
}

/// The most recent agreed step, if it is recent enough to follow up on.
Memory? latestPlan(List<Memory> all, {Duration within = const Duration(days: 30), DateTime? now}) {
  final plan = all.where((m) => m.kind == 'plan').firstOrNull;
  if (plan == null) return null;
  return (now ?? DateTime.now()).difference(plan.createdAt) <= within ? plan : null;
}

// ---------------------------------------------------------------------------------------------
// Conversation upkeep

/// Of a conversation's turns (oldest first, already filtered to user and Eve), the ones that fall
/// outside the newest [charBudget] characters: what must be summarised to stay in view.
List<Message> messagesToSummarise(List<Message> turns, {required int charBudget}) {
  var used = 0;
  var firstKept = turns.length;
  for (var i = turns.length - 1; i >= 0; i--) {
    final len = turns[i].content.length;
    // The newest turn always stays verbatim, mirroring buildHistory.
    if (firstKept < turns.length && used + len > charBudget) break;
    used += len;
    firstKept = i;
  }
  return turns.sublist(0, firstKept);
}

/// True when [reply] opens the way one of Eve's recent replies did. Repeated openers are what
/// people describe as a bot going mechanical ("empathy fatigue", TherapyProbe arXiv 2602.22775).
bool repeatsOpener(String reply, List<String> recent, {int words = 4}) {
  String head(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(words).join(' ');
  final h = head(reply);
  if (h.split(' ').length < words) return false;
  return recent.any((r) => head(r) == h);
}

/// "User", not "Person": the model sometimes echoes the labels back, and "Person:" would parse as
/// a note of kind person.
String transcript(List<Message> turns) => turns.map((m) => '${m.role == 'user' ? 'User' : 'Eve'}: ${m.content}').join('\n');

List<Map<String, String>> summaryRequest({String? previous, required List<Message> turns}) => [
  {
    'role': 'user',
    'content': 'Summarise this part of a conversation between a person and Eve, a mental-health companion, so Eve can '
        'carry on without it. Keep who is involved, what the person is going through and feeling, what was tried or '
        'agreed, and any safety concern. Write three to six short sentences in the language the person used. Add '
        'nothing they did not say.\n\n'
        '${previous == null || previous.isEmpty ? '' : 'Summary so far:\n$previous\n\n'}'
        'Conversation:\n${transcript(turns)}',
  },
];

List<Map<String, String>> memoryRequest({required List<Memory> existing, required List<Message> turns}) => [
  {
    'role': 'user',
    'content': 'Read this conversation between a person and Eve, a mental-health companion. Write down what is worth '
        'remembering for future conversations: people in their life, what they are going through, what they want to '
        'work on, what helped, and any small next step they agreed to.\n'
        'Rules: only what the person actually said; one short sentence each, in the language the person used; at most '
        'five; skip anything already in the existing notes. If nothing is worth keeping, write NONE.\n'
        'Write each on its own line as: - kind: note   where kind is person, situation, goal, helped or plan.\n\n'
        'Existing notes:\n${existing.isEmpty ? '(none)' : existing.take(20).map((m) => '- ${m.kind}: ${m.content}').join('\n')}\n\n'
        'Conversation:\n${transcript(turns)}',
  },
];

/// The wrap-up is two plain questions rather than one labelled form: the fine-tuned model answers
/// as Eve in prose and ignores labels like "SUMMARY:", so each reply is used whole.
List<Map<String, String>> wrapUpSummaryRequest({required List<Message> turns, String? summary}) => [
  {
    'role': 'user',
    'content': 'A person has been talking with Eve, a mental-health companion, and wants to wrap up. Speaking as Eve, '
        'in the language the person used, write two or three warm sentences on what they talked about and what they '
        'noticed. Add nothing they did not say, and do not suggest anything new.\n\n'
        '${summary == null || summary.isEmpty ? '' : 'Earlier in the session:\n$summary\n\n'}'
        'Conversation:\n${transcript(turns)}',
  },
];

List<Map<String, String>> wrapUpStepRequest({required List<Message> turns}) => [
  {
    'role': 'user',
    'content': 'From this conversation between a person and Eve, a mental-health companion, name the one small, concrete '
        'thing the person said they would try before next time. Reply with only that, in one short sentence in the '
        'language the person used, starting with a verb, for example "Write tomorrow\'s worries on paper before bed."\n\n'
        'Conversation:\n${transcript(turns)}',
  },
];

/// The model's answer to [wrapUpStepRequest] as a plan note: the first sentence, minus lead-ins the
/// model adds anyway ("The next step is to…", "You could try…"). Null when there is nothing usable.
String? cleanStep(String raw) {
  var s = raw.trim().split(RegExp(r'(?<=[.!?])\s+|\n')).first.trim();
  s = s.replaceFirst(RegExp(r'^[-*•"\s]+'), '').replaceFirst(RegExp(r'["\s]+$'), '');
  s = s.replaceFirst(
    RegExp(
      r"^((the |one |your )?(small )?(next )?(step|thing)( for (you|them|next time))?( (is|could be|would be|might be))?( to)?|"
      r"(you|they) (could|can|might|should|will|said (you|they)('d| would))( try| like)?( to)?|"
      r"(i'd|i would) (like|suggest|encourage) (you|them)( to)?( try)?( to)?)\s+",
      caseSensitive: false,
    ),
    '',
  );
  if (s.isEmpty) return null;
  s = s[0].toUpperCase() + s.substring(1);
  if (!RegExp(r'[.!?]$').hasMatch(s)) s = '$s.';
  return s.split(' ').length < 3 || s.length > 200 ? null : s;
}

final _memoryLine = RegExp(r'^\s*[-*•]?\s*(person|situation|goal|helped|plan)\s*:\s*(.+?)\s*$', caseSensitive: false, multiLine: true);

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// A line written in Eve's voice rather than about the person: the fine-tuned model sometimes answers
/// the extraction request as a reply ("I know it must be very hard", "You must be feeling…").
final _eveVoice = RegExp(
  r"(^|\s)(i|i'm|i've|i'd|i'll)\s|\byou must\b|\bit'?s (normal|okay|ok|good|great)\b|\bi know\b|\beve\b|[!?]\s*$",
  caseSensitive: false,
);

/// Notes from the model's reply: known kinds only, at most five, no exact repeats of [existing],
/// nothing in Eve's voice.
List<MemoryCandidate> parseMemories(String raw, {Iterable<String> existing = const []}) {
  if (raw.trim().toUpperCase().startsWith('NONE')) return const [];
  final seen = {for (final e in existing) _norm(e)};
  final out = <MemoryCandidate>[];
  for (final m in _memoryLine.allMatches(raw)) {
    var content = m.group(2)!.trim();
    if (content.length < 4 || content.toUpperCase() == 'NONE' || _eveVoice.hasMatch(content)) continue;
    if (content.length > 200) content = '${content.substring(0, 197)}...';
    final key = _norm(content);
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add((kind: m.group(1)!.toLowerCase(), content: content));
    if (out.length == 5) break;
  }
  return out;
}
