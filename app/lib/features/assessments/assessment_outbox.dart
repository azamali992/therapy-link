import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models.dart';
import '../../core/settings/settings.dart';

const _kPending = 'pendingAssessments';

/// Whether the answers say the person has thought of being better off dead or of hurting
/// themselves: item 9 of PHQ-9, answered above "not at all". Checked on the phone,
/// so help does not wait on the server, and does not vanish when the network does.
bool itemNineFlagged(Instrument instrument, List<int?> answers) =>
    instrument == Instrument.phq9 && answers.length > 8 && (answers[8] ?? 0) > 0;

/// Assessments that could not be sent, kept on the phone and sent the next time one goes through.
class AssessmentOutbox {
  AssessmentOutbox(this._prefs);

  final SharedPreferences _prefs;

  List<Map<String, dynamic>> _read() {
    final raw = _prefs.getString(_kPending);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> items) =>
      items.isEmpty ? _prefs.remove(_kPending) : _prefs.setString(_kPending, jsonEncode(items));

  List<({String id, Instrument instrument, List<int> answers})> get pending => [
    for (final j in _read())
      (
        id: j['id'] as String,
        instrument: Instrument.values.firstWhere((i) => i.name == j['instrument'], orElse: () => Instrument.phq9),
        answers: List<int>.from(j['answers'] as List),
      ),
  ];

  /// Queues [answers] and returns the id to [remove] it by if a retry goes through first.
  Future<String> add(Instrument instrument, List<int> answers) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _write([..._read(), {'id': id, 'instrument': instrument.name, 'answers': answers, 'taken_at': DateTime.now().toIso8601String()}]);
    return id;
  }

  Future<void> remove(String id) => _write(_read().where((j) => j['id'] != id).toList());

  /// Sends what is queued, oldest first, and stops at the first failure. Returns how many went.
  Future<int> flush(ApiClient api) async {
    var sent = 0;
    for (final p in pending) {
      try {
        await api.submitAssessment(p.instrument, p.answers);
      } catch (e) {
        debugPrint('assessment retry deferred: $e');
        break;
      }
      await remove(p.id);
      sent++;
    }
    return sent;
  }
}

final assessmentOutboxProvider = Provider<AssessmentOutbox>((ref) => AssessmentOutbox(ref.watch(sharedPreferencesProvider)));
