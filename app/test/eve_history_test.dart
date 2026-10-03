import 'package:flutter_test/flutter_test.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/core/ml/eve_engine.dart';
import 'package:therapylink/features/eve/eve_controller.dart';

import 'crisis_fakes.dart';

var _clock = DateTime(2026, 9, 15, 17);

Message _m(String role, String content) {
  _clock = _clock.add(const Duration(minutes: 1));
  return Message(id: '${_clock.millisecondsSinceEpoch}', conversationId: 'default', role: role, content: content, flagged: false, createdAt: _clock);
}

void main() {
  test('failure placeholders are shown in the chat but never sent back as Eve', () {
    final history = buildHistory([
      _m('user', 'Hii'),
      _m('assistant', eveFailureReply),
      _m('user', 'Hey'),
      _m('assistant', 'Hi, I am here. How are you feeling?'),
      _m('user', 'Stressed'),
    ]);
    expect(history.map((m) => m['content']), isNot(contains(eveFailureReply)));
    // The two user turns around the dropped placeholder merge, keeping strict alternation.
    expect(history.first, {'role': 'user', 'content': 'Hii\nHey'});
    expect(history.map((m) => m['role']).toList(), ['user', 'assistant', 'user']);
  });

  test('the budget keeps the newest messages and drops the oldest', () {
    final rows = [for (var i = 0; i < 10; i++) _m(i.isEven ? 'user' : 'assistant', '$i ${'x' * 998}')];
    final history = buildHistory(rows, charBudget: 4500);
    final text = history.map((m) => m['content']).join('\n');
    expect(text, contains('9 '));
    expect(text, isNot(contains('0 ')));
    expect(history.first['role'], 'user');
  });

  test('a short conversation is sent whole, well past the old 12-message limit', () {
    final rows = [for (var i = 0; i < 30; i++) _m(i.isEven ? 'user' : 'assistant', 'turn $i')];
    expect(buildHistory(rows).length, 30);
  });

  test('the newest message is kept even if it alone exceeds the budget', () {
    final history = buildHistory([_m('user', 'y' * 6000)], charBudget: 4500);
    expect(history.single['content']!.length, 6000);
  });

  test('memory and summary notes are sent to the model because v16-clean was trained on them', () async {
    expect(eveUnderstandsNotes, isTrue);
    final h = await Harness.create();
    addTearDown(h.dispose);
    await h.db.upsertConversation(h.conversation);
    await h.db.setSummary(h.conversation, 'They talked about exams.', DateTime(2020));
    await h.db.applyMemoryChanges(
      add: [MemoriesCompanion.insert(id: 'm1', kind: 'situation', content: 'Exams in November are causing panic', createdAt: DateTime(2020))],
      remove: const [],
    );

    await h.eve.send('my exams are making me panic again');

    expect(h.engine.replies, hasLength(1));
    expect(h.engine.replies.single.notes, isNotNull);
  });
}
