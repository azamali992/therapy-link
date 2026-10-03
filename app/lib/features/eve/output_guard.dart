import 'package:flutter/foundation.dart';

import '../shared/helplines.dart';

/// A run of digits with the separators people write in phone numbers, or a 1-800 vanity number.
/// The vanity form goes first, or '1-800-4-A-CHILD' would stop at the first letter; it needs the
/// seven characters a US number has after 800, so "the 1800-1900 era" is not one.
final _phoneLike = RegExp(r'(\b1-?800-?(?:[A-Z0-9]-?){7,}|\+?\(?\d[\d\s().\-]{1,18}\d\)?)', caseSensitive: false);

final _tollFree = RegExp(r'^1-?800');

/// "2019-2020", "1990 - 95": years, not a number to dial.
final _yearRange = RegExp(r'^(1[89]|20)\d\d\s*-\s*((1[89]|20)\d\d|\d\d)$');

/// "12-05-2024", "3.4.25": a date.
final _date = RegExp(r'^\d{1,2}[-./]\d{1,2}[-./](\d\d|\d{4})$');

/// A digit or a trailing run of digits and separators at the end of streamed text, which may still
/// grow into a number, so it is held back until the next word arrives.
final _trailingNumber = RegExp(r'(\b1-?800-?[A-Z0-9-]*|\+?\(?\d[\d\s().\-]*)$', caseSensitive: false);

/// Short codes that are crisis lines somewhere else. A model trained on English web text reaches for
/// these; in Pakistan they connect to nothing, or to the wrong service.
const _foreignShortCodes = {'988', '911', '999', '111', '112', '116123', '741741'};

/// How many numbers the guard has taken out since the app started, for debugging.
int outputGuardHits = 0;

/// Takes out of Eve's reply any phone number that is not in the helplines table, replacing it with
/// [replacement]. v14 with the V2 prompt told a person asking for "the most painless way" to call
/// 800-273-8255, a US line; another run gave a 14-year-old Childhelp's 1-800 number.
///
/// Numbers under seven digits are left alone unless they are a known foreign crisis code, so
/// "5-4-3-2-1 grounding", "10 minutes" and a year pass through, and so do year ranges, dates and
/// counting ("1 2 3 4 5 6 7 8").
({String text, int removed}) guardReplyNumbers(String reply, {required String replacement}) {
  final out = _guard(reply, replacement);
  if (out.removed > 0) {
    outputGuardHits += out.removed;
    debugPrint('output guard removed ${out.removed} number(s) from a reply (total $outputGuardHits)');
  }
  return out;
}

/// What the transcript may show of a reply still being generated: the finished part guarded the same
/// way as a whole reply, and a number still being written held back until it is complete, so a
/// foreign line is never on screen, even for the seconds before the reply ends.
String guardStreamingText(String partial, {required String replacement}) {
  final tail = _trailingNumber.firstMatch(partial);
  final settled = tail == null ? partial : partial.substring(0, tail.start);
  return _guard(settled, replacement).text;
}

({String text, int removed}) _guard(String reply, String replacement) {
  var removed = 0;
  String keep(String span) {
    if (!_isPhone(span) || isKnownHelpline(span)) return span;
    removed++;
    return replacement;
  }

  final text = reply.replaceAllMapped(_phoneLike, (m) {
    final span = m[0]!;
    if (isKnownHelpline(span)) return span;
    // Two lines written side by side ("1122 1098") read as one long number; if any piece is a line
    // in the table, each piece is judged on its own.
    final pieces = span.split(RegExp(r'(?<=\d)\s+(?=\d)'));
    if (pieces.length > 1 && pieces.any(isKnownHelpline)) {
      return span.splitMapJoin(RegExp(r'\S+'), onMatch: (p) => keep(p[0]!), onNonMatch: (s) => s);
    }
    return keep(span);
  });
  return (text: text, removed: removed);
}

bool _isPhone(String span) {
  final trimmed = span.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (_foreignShortCodes.contains(digits)) return true;
  if (_yearRange.hasMatch(trimmed) || _date.hasMatch(trimmed)) return false;
  if (_tollFree.hasMatch(trimmed)) return true;
  if (digits.length < 7) return false;
  // Every group a single digit is counting, not a number: nobody writes a phone number that way.
  final groups = trimmed.split(RegExp(r'[\s().\-]+')).where((g) => g.isNotEmpty);
  if (groups.every((g) => g.length == 1)) return false;
  return true;
}
