import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ml/guardian.dart';
import '../../core/settings/settings.dart';

/// How long the conversation stays in crisis mode after the last flagged turn. Dismissing the sheet
/// is not the same as being safe: "I already took them" rarely repeats the words that flagged the
/// first message, so the next hour is handled differently.
const crisisModeLength = Duration(minutes: 60);

const _kUntil = 'eveCrisisActiveUntil';
const _kKind = 'eveCrisisKind';

@immutable
class CrisisModeState {
  const CrisisModeState({this.until, this.kind = CrisisKind.suicide});

  final DateTime? until;

  /// The kind of the last flagged turn, so the cards that follow keep offering the lines that fit.
  final CrisisKind kind;

  bool activeAt(DateTime now) => until != null && now.isBefore(until!);

  bool get active => activeAt(DateTime.now());
}

/// Crisis mode, kept in its own preference so an app restart doesn't end it.
class CrisisMode extends Notifier<CrisisModeState> {
  @override
  CrisisModeState build() {
    final p = ref.read(sharedPreferencesProvider);
    final ms = p.getInt(_kUntil);
    return CrisisModeState(
      until: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
      kind: CrisisKind.fromLabel(p.getString(_kKind)) ?? CrisisKind.suicide,
    );
  }

  bool get active => state.active;

  Future<void> activate(CrisisKind kind, {DateTime? now}) async {
    final until = (now ?? DateTime.now()).add(crisisModeLength);
    state = CrisisModeState(until: until, kind: kind);
    final p = ref.read(sharedPreferencesProvider);
    await p.setInt(_kUntil, until.millisecondsSinceEpoch);
    await p.setString(_kKind, kind.label);
  }

  /// Ends crisis mode early, for a person who has said the danger it was raised for isn't there.
  Future<void> clear() async {
    state = CrisisModeState(kind: state.kind);
    final p = ref.read(sharedPreferencesProvider);
    await p.remove(_kUntil);
  }
}

final crisisModeProvider = NotifierProvider<CrisisMode, CrisisModeState>(CrisisMode.new);
