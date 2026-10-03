enum Role { patient, clinician, admin }

/// Public-domain instruments only, matching the server. BDI-II is licensed and stays out.
enum Instrument { phq9, gad7 }

enum LinkStatus { pending, active, revoked }

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.firstWhere((v) => v.name == raw, orElse: () => fallback);

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

class Me {
  const Me({required this.uid, this.email, this.displayName, required this.role, required this.locale, required this.clinicianVerified, this.inviteCode});

  final String uid;
  final String? email;
  final String? displayName;
  final Role role;
  final String locale;
  final bool clinicianVerified;

  /// Set only for the signed-in clinician themselves.
  final String? inviteCode;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
    uid: j['uid'],
    email: j['email'],
    displayName: j['display_name'],
    role: _enum(Role.values, j['role'], Role.patient),
    locale: j['locale'] ?? 'en',
    clinicianVerified: j['clinician_verified'] == true,
    inviteCode: j['invite_code'],
  );
}

class Assessment {
  const Assessment({
    required this.id,
    required this.instrument,
    required this.score,
    required this.band,
    required this.flags,
    required this.takenAt,
    this.delta,
    this.locale,
  });

  final String id;
  final Instrument instrument;
  final int score;
  final String band;
  final List<String> flags;
  final DateTime takenAt;
  final int? delta;

  /// The language the items were shown in, 'en' or 'ur'; null from older rows.
  final String? locale;

  /// Answered in the app's Roman Urdu wording, which is not a validated clinical translation.
  bool get unvalidatedTranslation => locale == 'ur';

  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
    id: j['id'],
    instrument: _enum(Instrument.values, j['instrument'], Instrument.phq9),
    score: j['score'],
    band: j['band'],
    flags: List<String>.from(j['flags'] ?? const []),
    takenAt: _date(j['taken_at'])!,
    delta: j['delta'],
    locale: j['locale'],
  );
}

class MoodPointUpload {
  const MoodPointUpload({required this.valence, this.emotion, required this.source, required this.recordedAt, this.clientId})
    : assert(clientId == null || (clientId.length > 0 && clientId.length <= 64));

  final int valence;
  final String? emotion;
  final String source;
  final DateTime recordedAt;

  /// Names the queued row this point came from, so the server skips it when a batch is resent
  /// after a reply that never arrived. At most 64 characters.
  final String? clientId;

  Map<String, dynamic> toJson() => {
    'valence': valence,
    'emotion': emotion,
    'source': source,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    if (clientId != null) 'client_id': clientId,
  };
}

/// The client id for mood queue row [rowId]. The row id alone would repeat: signing out deletes
/// the database file, and the next one numbers its rows from 1 again, so the server would take a
/// new check-in for one it already has. The row's own timestamp keeps it unique, and both parts
/// are read back from the row, so every resend of the same row sends the same id.
String moodClientId(int rowId, DateTime recordedAt) => '$rowId-${recordedAt.toUtc().millisecondsSinceEpoch}';

/// What the server did with an upload: points stored, and points it already had.
class MoodUploadResult {
  const MoodUploadResult({required this.accepted, required this.duplicates});

  final int accepted;
  final int duplicates;
}

class MoodDay {
  const MoodDay({required this.day, required this.meanValence, required this.n});

  final DateTime day;
  final double meanValence;
  final int n;

  factory MoodDay.fromJson(Map<String, dynamic> j) => MoodDay(day: DateTime.parse(j['day']), meanValence: (j['mean_valence'] as num).toDouble(), n: j['n']);
}

class JournalEntry {
  const JournalEntry({required this.id, this.title, required this.body, this.mood, required this.createdAt, required this.updatedAt});

  final String id;
  final String? title;
  final String body;
  final int? mood;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
    id: j['id'],
    title: j['title'],
    body: j['body'],
    mood: j['mood'],
    createdAt: _date(j['created_at'])!,
    updatedAt: _date(j['updated_at'])!,
  );
}

class SharedSummary {
  const SharedSummary({required this.id, required this.kind, required this.content, this.periodStart, this.periodEnd, required this.createdAt});

  final String id;
  final String kind;
  final String content;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime createdAt;

  factory SharedSummary.fromJson(Map<String, dynamic> j) => SharedSummary(
    id: j['id'],
    kind: j['kind'],
    content: j['content'],
    periodStart: _date(j['period_start']),
    periodEnd: _date(j['period_end']),
    createdAt: _date(j['created_at'])!,
  );
}

class CareLink {
  const CareLink({
    required this.id,
    required this.patientUid,
    required this.clinicianUid,
    required this.status,
    required this.shareAssessments,
    required this.shareMoodTrend,
    required this.shareSummaries,
    required this.shareJournal,
    this.clinicianName,
    this.clinicianVerified = false,
  });

  final String id;
  final String patientUid;
  final String clinicianUid;

  /// Who the patient is linked with, when the server includes it; older servers send only the uid.
  final String? clinicianName;
  final bool clinicianVerified;
  final LinkStatus status;
  final bool shareAssessments;
  final bool shareMoodTrend;
  final bool shareSummaries;
  final bool shareJournal;

  factory CareLink.fromJson(Map<String, dynamic> j) {
    // Accept the clinician either flattened onto the link or nested as a user object.
    final c = j['clinician'] is Map ? Map<String, dynamic>.from(j['clinician'] as Map) : const <String, dynamic>{};
    final name = (j['clinician_name'] ?? j['clinician_display_name'] ?? c['display_name']) as String?;
    return CareLink(
      id: j['id'],
      patientUid: j['patient_uid'],
      clinicianUid: j['clinician_uid'],
      status: _enum(LinkStatus.values, j['status'], LinkStatus.pending),
      shareAssessments: j['share_assessments'] == true,
      shareMoodTrend: j['share_mood_trend'] == true,
      shareSummaries: j['share_summaries'] == true,
      shareJournal: j['share_journal'] == true,
      clinicianName: (name == null || name.trim().isEmpty) ? null : name.trim(),
      clinicianVerified: j['clinician_verified'] == true || c['clinician_verified'] == true,
    );
  }
}

/// One time a clinician was shown some of this patient's data.
class AccessLogEntry {
  const AccessLogEntry({required this.clinicianUid, this.clinicianName, required this.action, required this.sections, required this.at});

  final String clinicianUid;
  final String? clinicianName;

  /// `caseload` (their patient list, which shows latest scores) or `overview` (this patient's page).
  final String action;

  /// `assessments`, `mood_trend`, `summaries`, `journal`.
  final List<String> sections;
  final DateTime at;

  factory AccessLogEntry.fromJson(Map<String, dynamic> j) => AccessLogEntry(
    clinicianUid: j['clinician_uid'],
    clinicianName: j['clinician_name'],
    action: j['action'],
    sections: List<String>.from(j['sections'] ?? const []),
    at: _date(j['at'])!,
  );
}

/// A patient who asked to link and is waiting for the clinician's answer. Nothing of theirs is
/// visible until the request is accepted.
class LinkRequest {
  const LinkRequest({required this.linkId, required this.patient, this.requestedAt});

  final String linkId;
  final Me patient;
  final DateTime? requestedAt;

  factory LinkRequest.fromJson(Map<String, dynamic> j) =>
      LinkRequest(linkId: j['link_id'], patient: Me.fromJson(j['patient']), requestedAt: _date(j['requested_at']));
}

class PatientOverview {
  const PatientOverview({required this.patient, required this.consent, this.assessments, this.moodTrend, this.summaries, this.journal});

  final Me patient;
  final CareLink consent;
  final List<Assessment>? assessments;
  final List<MoodDay>? moodTrend;
  final List<SharedSummary>? summaries;
  final List<JournalEntry>? journal;

  factory PatientOverview.fromJson(Map<String, dynamic> j) => PatientOverview(
    patient: Me.fromJson(j['patient']),
    consent: CareLink.fromJson(j['consent']),
    assessments: (j['assessments'] as List?)?.map((e) => Assessment.fromJson(e)).toList(),
    moodTrend: (j['mood_trend'] as List?)?.map((e) => MoodDay.fromJson(e)).toList(),
    summaries: (j['summaries'] as List?)?.map((e) => SharedSummary.fromJson(e)).toList(),
    journal: (j['journal'] as List?)?.map((e) => JournalEntry.fromJson(e)).toList(),
  );
}

/// A patient in a clinician's list. The server orders rows so the ones needing a look come first.
class CaseloadRow {
  const CaseloadRow({required this.patient, required this.sharesAssessments, required this.latest, required this.attention, this.lastAssessedAt});

  final Me patient;
  final bool sharesAssessments;

  /// Newest result per instrument; empty when nothing is shared.
  final List<Assessment> latest;

  /// `risk_item`, `worsened`, `severe`.
  final List<String> attention;
  final DateTime? lastAssessedAt;

  factory CaseloadRow.fromJson(Map<String, dynamic> j) => CaseloadRow(
    patient: Me.fromJson(j['patient']),
    sharesAssessments: j['shares_assessments'] == true,
    latest: ((j['latest'] as List?) ?? const []).map((e) => Assessment.fromJson(e)).toList(),
    attention: List<String>.from(j['attention'] ?? const []),
    lastAssessedAt: _date(j['last_assessed_at']),
  );
}
