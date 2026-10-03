import '../../core/ml/guardian.dart';

/// One place a person in danger can be sent. Every number the app shows comes from [helplines];
/// translated strings and model replies never carry a number of their own.
class Helpline {
  const Helpline({required this.name, required this.number, required this.display, required this.kinds, this.verifiedOn});

  final String name;

  /// What the dialer gets.
  final String number;

  /// How the number is written for people to read and copy.
  final String display;

  /// The kinds of crisis this line is shown for.
  final Set<CrisisKind> kinds;

  /// When a named person last confirmed the number, hours and scope with the service. Null until
  /// someone has, and debug builds label such a line 'unverified' wherever it is shown.
  final DateTime? verifiedOn;

  bool get verified => verifiedOn != null;
}

const _all = {CrisisKind.suicide, CrisisKind.abuse, CrisisKind.child, CrisisKind.sexualViolence};

/// PENDING HUMAN VERIFICATION: none of these has been confirmed with the service yet (see
/// docs/ship-review/crisis-safety.md, "What needs a human"). Hours and cost are left out on
/// purpose until they are; the app must not promise "free" or "24/7" on a guess.
const helplines = [
  Helpline(
    name: 'Umang',
    number: '03117786264',
    display: '0311 7786264',
    kinds: {CrisisKind.suicide, CrisisKind.abuse, CrisisKind.sexualViolence},
  ),
  Helpline(name: 'Madadgaar', number: '1098', display: '1098', kinds: {CrisisKind.abuse, CrisisKind.child, CrisisKind.sexualViolence}),
  Helpline(name: 'Rescue', number: '1122', display: '1122', kinds: _all),
];

/// The lines for [kind], most specific first. Rescue fits every kind, so it always comes last; for
/// abuse, child and sexual violence Madadgaar, the line made for those, leads.
List<Helpline> helplinesFor(CrisisKind kind) {
  int rank(Helpline h) => h.kinds.length == _all.length ? 2 : (h.number == '1098' && kind != CrisisKind.suicide ? 0 : 1);
  return [for (final h in helplines) if (h.kinds.contains(kind)) h]..sort((a, b) => rank(a).compareTo(rank(b)));
}

/// Digits only, with Pakistan's +92 / 0092 written as a leading 0, so '+92 311 7786264' and
/// '0311-7786264' compare equal.
String normaliseNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0092')) digits = '0${digits.substring(4)}';
  if (digits.startsWith('92') && digits.length == 12) digits = '0${digits.substring(2)}';
  return digits;
}

/// Whether [raw] is one of the lines in [helplines].
bool isKnownHelpline(String raw) {
  final n = normaliseNumber(raw);
  return helplines.any((h) => h.number == n);
}
