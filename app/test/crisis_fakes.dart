import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:therapylink/core/db/database.dart';
import 'package:therapylink/core/ml/eve_engine.dart';
import 'package:therapylink/core/ml/guardian.dart';
import 'package:therapylink/core/ml/onnx_guardian.dart';
import 'package:therapylink/core/settings/settings.dart';
import 'package:therapylink/features/eve/eve_controller.dart';

/// An engine that records every call. [gate], when set, holds each reply open until completed, so a
/// test can act while Eve is still generating.
class FakeEngine implements EveEngine {
  FakeEngine({this.replyText = 'That sounds hard. What happened?', this.failOnCall = false});

  String replyText;

  /// When set, the reply streams as these tokens instead of [replyText] in one piece.
  List<String>? tokens;
  String completionText = '';

  /// When set, the wrap-up's step request answers with this instead of [completionText].
  String? stepText;
  bool failOnCall;
  Completer<void>? gate;
  final replies = <({List<Map<String, String>> history, String? notes})>[];
  final completions = <List<Map<String, String>>>[];

  int get calls => replies.length + completions.length;

  /// Calls made while [failOnCall] was set. The controller swallows engine errors, so the test
  /// checks this count rather than relying on the throw.
  int violations = 0;

  /// The most engine calls ever running at once. On the phone anything over one is a crash.
  int maxInFlight = 0;
  int _inFlight = 0;

  void _enter() {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
  }

  @override
  String get name => 'fake';

  @override
  Future<bool> get isReady async => true;

  @override
  Stream<String> reply(List<Map<String, String>> messages, {String? notes}) async* {
    if (failOnCall) {
      violations++;
      throw StateError('the engine was called on a turn that must not reach it');
    }
    replies.add((history: messages, notes: notes));
    _enter();
    try {
      if (gate != null) await gate!.future;
      if (tokens == null) {
        yield replyText;
      } else {
        for (final t in tokens!) {
          yield t;
        }
      }
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<String> complete(List<Map<String, String>> messages, {int maxTokens = 300}) async {
    if (failOnCall) {
      violations++;
      throw StateError('the engine was called on a turn that must not reach it');
    }
    completions.add(messages);
    _enter();
    try {
      if (gate != null) await gate!.future;
      return maxTokens <= 60 && stepText != null ? stepText! : completionText;
    } finally {
      _inFlight--;
    }
  }
}

/// Flags whatever [isCrisis] says, and records every passage it was shown.
class FakeGuardian implements Guardian {
  FakeGuardian([bool Function(String text)? isCrisis, this.kind = CrisisKind.suicide, this.valence = 0]) : _isCrisis = isCrisis ?? ((t) => t.contains('CRISIS'));

  final bool Function(String text) _isCrisis;
  final CrisisKind kind;

  /// Valence for a message that is not a crisis (a crisis is always -2).
  final int valence;
  final seen = <String>[];

  @override
  Future<GuardianVerdict> classify(String text) async {
    seen.add(text);
    final crisis = _isCrisis(text);
    return GuardianVerdict(crisis: crisis, crisisScores: const {}, valence: crisis ? -2 : valence, kind: kind);
  }
}

class Harness {
  Harness._(this.container, this.db, this.engine, this.guardian, this.prefs);

  final ProviderContainer container;
  final AppDatabase db;
  final FakeEngine engine;
  final FakeGuardian guardian;
  final SharedPreferences prefs;

  static Future<Harness> create({FakeEngine? engine, FakeGuardian? guardian, Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final e = engine ?? FakeEngine();
    final g = guardian ?? FakeGuardian();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(p),
        databaseProvider.overrideWithValue(db),
        eveEngineProvider.overrideWithValue(e),
        guardianProvider.overrideWithValue(g),
      ],
    );
    return Harness._(container, db, e, g, p);
  }

  EveController get eve => container.read(eveControllerProvider.notifier);
  EveState get state => container.read(eveControllerProvider);
  String get conversation => container.read(conversationIdProvider);

  Future<List<Message>> messages() => db.recentMessages(conversation, limit: 500);

  Future<void> dispose() async {
    // Let scheduled upkeep settle before the database goes away.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    container.dispose();
    await db.close();
  }
}
