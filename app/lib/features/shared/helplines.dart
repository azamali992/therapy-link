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

  /// When the number and scope were last confirmed. See the verification basis above [helplines]:
  /// today that is a public-source check, not a call to the service. Null until then, and debug
  /// builds label such a line 'unverified' wherever it is shown.
  final DateTime? verifiedOn;

  bool get verified => verifiedOn != null;
}

final _all = CrisisKind.values.toSet();

/// Kinds where the danger is to a body now, so the emergency line leads instead of closing the list.
const _emergencyFirst = {CrisisKind.medical, CrisisKind.harmToOthers};

// Verification basis (docs/clinical/helplines.md has the sources and what each service offers):
// `verifiedOn` is the date a current public source (the operator's own site, WHO, UN Women, Child
// Helpline International or 2026 reporting) was checked and confirmed the number and who the line is
// for: "verified-by-public-source", ai-clinical-review 2026-10-03. Nobody has called these services
// yet; a licensed clinician or the owner still has to confirm each one with the service itself
// before the pilot (helplines.md "Still to do by phone"). Hours and cost stay out of the app until
// then: no "free", no "24/7".
//
// Which kinds each line shows for follows docs/clinical/GUARDIAN_LABELS.md section 1: self-harm gets
// Umang and Rescue, harm to others gets Rescue and the police, a medical emergency gets Rescue.
//
// Order matters for ties in [helplinesFor]: the specific abuse and child lines come before Umang.
final _publicSourceCheck = DateTime(2026, 10, 3);

final helplines = [
  Helpline(
    name: 'Madadgaar',
    number: '1098',
    display: '1098',
    kinds: {CrisisKind.abuse, CrisisKind.child, CrisisKind.sexualViolence},
    verifiedOn: _publicSourceCheck,
  ),
  // Punjab only: the name says so, because the sheet has no province field.
  Helpline(
    name: 'Punjab Women Helpline',
    number: '1043',
    display: '1043',
    kinds: {CrisisKind.abuse, CrisisKind.sexualViolence},
    verifiedOn: _publicSourceCheck,
  ),
  Helpline(
    name: 'Punjab Child Protection',
    number: '1121',
    display: '1121',
    kinds: {CrisisKind.child},
    verifiedOn: _publicSourceCheck,
  ),
  // Number confirmed by WHO EMRO's 2026 listing. Umang's own website was suspended by its host when
  // checked on 2026-10-03, so this line is the first to confirm by phone.
  Helpline(
    name: 'Umang',
    number: '03117786264',
    display: '0311 7786264',
    kinds: {CrisisKind.suicide, CrisisKind.selfHarm, CrisisKind.abuse, CrisisKind.sexualViolence},
    verifiedOn: _publicSourceCheck,
  ),
  // Danger from another person (helplines.md: police 15, verified-by-public-source). Only on the harm
  // to others sheet, to keep the other sheets short; it is also Rescue's fallback in Balochistan.
  Helpline(name: 'Police', number: '15', display: '15', kinds: {CrisisKind.harmToOthers}, verifiedOn: _publicSourceCheck),
  Helpline(name: 'Rescue', number: '1122', display: '1122', kinds: _all, verifiedOn: _publicSourceCheck),
];

/// The lines for [kind], most specific first. Rescue fits every kind, so it comes last, except for a
/// medical emergency or harm to others, where it leads; for abuse, child and sexual violence
/// Madadgaar, the line made for those, leads.
List<Helpline> helplinesFor(CrisisKind kind) {
  int rank(Helpline h) {
    if (h.kinds.length == _all.length) return _emergencyFirst.contains(kind) ? -1 : 2;
    return h.number == '1098' ? 0 : 1;
  }

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
