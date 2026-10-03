/// Which kind of danger a crisis is. The help offered depends on it: a person being hurt by someone
/// else needs a different line from a person thinking of ending their life.
enum CrisisKind {
  suicide('suicidal'),
  abuse('abuse'),
  child('child'),
  sexualViolence('sexual_violence');

  const CrisisKind(this.label);

  /// The label the trained Guardian and ml/ use for this kind.
  final String label;

  static CrisisKind? fromLabel(String? label) {
    for (final k in values) {
      if (k.label == label) return k;
    }
    return null;
  }
}

/// What the on-device classifier says about one user message.
class GuardianVerdict {
  const GuardianVerdict({required this.crisis, required this.crisisScores, required this.valence, this.emotion, CrisisKind? kind})
      : _kind = kind;

  final bool crisis;
  final Map<String, double> crisisScores;
  final int valence; // −2..2
  final String? emotion;
  final CrisisKind? _kind;

  /// Null when there is no crisis. A crisis with no finer reading is treated as suicide risk, the
  /// route with the widest help.
  CrisisKind? get kind => crisis ? (_kind ?? CrisisKind.suicide) : null;

  static const none = GuardianVerdict(crisis: false, crisisScores: {}, valence: 0);
}

/// One verdict from several reads of the same text, as the windows of a long message are: a crisis
/// in any window is a crisis, each score is its highest, and valence is the lowest seen.
GuardianVerdict mergeVerdicts(List<GuardianVerdict> verdicts) {
  if (verdicts.isEmpty) return GuardianVerdict.none;
  if (verdicts.length == 1) return verdicts.single;
  final scores = <String, double>{};
  for (final v in verdicts) {
    v.crisisScores.forEach((k, p) => scores[k] = p > (scores[k] ?? double.negativeInfinity) ? p : scores[k]!);
  }
  final flagged = verdicts.where((v) => v.crisis).toList();
  return GuardianVerdict(
    crisis: flagged.isNotEmpty,
    crisisScores: scores,
    valence: verdicts.map((v) => v.valence).reduce((a, b) => a < b ? a : b),
    emotion: verdicts.first.emotion,
    kind: flagged.isEmpty ? null : flagged.first.kind,
  );
}

abstract class Guardian {
  Future<GuardianVerdict> classify(String text);
}

/// Keyword recall only, deliberately over-sensitive. It is the floor under the trained Guardian and
/// the whole check until that model is installed.
///
/// ml/therapylink_ml/train/guardian.py mirrors these patterns for its union evaluation; change both
/// together. Hard negatives it must not fire on ("this exam is killing me", "mar gaye hanste
/// hanste") are in app/test/crisis_keywords_test.dart.
class HeuristicGuardian implements Guardian {
  /// Suicide and self-harm. Verb forms are gender-neutral (chahta/chahti/chahte), because a pattern
  /// written in the masculine misses every woman who says the same thing.
  static final crisisPattern = RegExp(
    r'(kill myself|end it all|end my life|take my (own )?life|want to die|not wake up|suicid|hurt myself|self.?harm|'
    r'cut(ting)? myself|hang myself|better off dead|don.?t want to (live|be alive|exist)|\bkms\b|unalive|'
    r'khud ?kushi|marna chaht[aie]|mar ja(u|un|on|oon|na|ana|aana)\b|jeena nahi|zindagi khatam|'
    r'apne aap ko (hurt|nuqsan|khatam)|khud ko (khatam|maar|nuqsan)|zinda (nahi|nahin|na) rehna|'
    // 'jaan le' on its own also means "find out", and 'zeher' on its own is slang for brilliant, so
    // each needs the words that make it about a life or about swallowing something.
    r'\b(apni|meri|khud ki) jaan (de|le)\b|\bjaan (de|le) (d|l)(u|oo|un|oon|unga|ungi|enge)\b|'
    r'zeh[ae]r (kha|pi|pee|le|la|de|mang|kharid)|goliyan|'
    r'خودکشی|خود کشی|مرنا|جان دے|زہر (کھا|پی|لے|دے))',
    caseSensitive: false,
  );

  /// Someone who could be hurting the person. 'Touched me' and 'hits me' mean something else when a
  /// message or a thought does it ("your message touched me", "it hits me how alone I am"), so those
  /// verbs only count after one of these.
  static const _someone =
      r'(he|she|they|someone|somebody|husband|wife|partner|boyfriend|girlfriend|fiance|ex|father|dad|abbu|'
      r'mother|mom|mum|ammi|parents|brother|bhai|sister|uncle|chacha|mamu|aunt|cousin|step ?(dad|father|mom|mother)|'
      r'in-?laws|teacher|tutor|coach|neighbou?r|man|guy|boss|stranger|friend)';

  /// Sexual violence, including an unwanted touch, which people often describe without naming it.
  static final sexualPattern = RegExp(
    r'(\braped?\b|sexual(ly)? (assault|abuse|harass)|molest|zabardasti|zyadati|'
    r'\b' '$_someone' r'\b( \w+)? touch(ed|es|ing)? me\b|'
    r'touch(ed|es|ing)? me (there|inappropriately|without)|inappropriately touch|'
    // A bare 'chhuta' or 'chhuti' is also a missed train or a lost job, so the touch needs a 'mujhe'.
    r'\b(mujhe|mujhko|muje) (\w+ )?chhu(a|aa|ya|ta|te|ne)\b|galat (tareeqe|tarah|jagah) (se )?chhu|زیادتی)',
    caseSensitive: false,
  );

  /// Violence at home or from someone close. 'peeta' is left out on purpose: it also means drinks.
  /// 'Abuse' needs a victim or a relationship: "I used to abuse alcohol" is not the abuse route.
  static final abusePattern = RegExp(
    r'(\b' '$_someone' r'\b( \w+)? (hits?|hitting|beats?|beating|slaps?|slapped|slapping|chokes?|choked|choking|kicks?|kicked) me\b|'
    r'beat me up|beating me|domestic (violence|abuse)|'
    r'\babus(ed|es|ing) me\b|\babusive to me\b|\b(was|am|being|been|got) abused\b|abused as a (child|kid)|'
    r'abusive (husband|wife|partner|boyfriend|girlfriend|father|dad|mother|mom|parents|relationship|marriage|home)|'
    r'\b(husband|wife|partner|boyfriend|girlfriend|father|dad|mother|mom|parents|in-?laws) (is|are|was|were|has been|gets) (\w+ )?abusive|'
    r'maar(ta|ti|te) (hai|hain|hy)|mujhe maar(a|ta|ti|te)|mujhe peet|pit(a|aa)i|thappar|'
    r'ghar (mein|me) band|تشدد|مارتا)',
    caseSensitive: false,
  );

  /// A sign the person is a child: an age under 18, school, or a step-parent with an abuse hit.
  static final _minor = RegExp(
    r"(\b(i am|i'm|im|main|meri umar) ([5-9]|1[0-7])\b|\b([5-9]|1[0-7]) (years? old|saal)\b|\bschool\b|class \d|"
    r'\bstep ?(dad|father|mom|mother)\b|sautel[aie])',
    caseSensitive: false,
  );

  static final _low = RegExp(r'(sad|depress|hopeless|worthless|tired of|lonely|anxious|panic|udaas|pareshan|thak gay|akela|ghabra)', caseSensitive: false);
  static final _high = RegExp(r'(happy|grateful|relieved|excited|proud|calm|khush|sukoon|shukar|acha lag)', caseSensitive: false);

  /// The kind of crisis [text] shows on keywords alone, or null.
  static CrisisKind? kindOf(String text) {
    if (crisisPattern.hasMatch(text)) return CrisisKind.suicide;
    final sexual = sexualPattern.hasMatch(text);
    final abuse = abusePattern.hasMatch(text);
    if (!sexual && !abuse) return null;
    if (_minor.hasMatch(text)) return CrisisKind.child;
    return sexual ? CrisisKind.sexualViolence : CrisisKind.abuse;
  }

  @override
  Future<GuardianVerdict> classify(String text) async {
    final kind = kindOf(text);
    if (kind != null) {
      return GuardianVerdict(crisis: true, crisisScores: {kind.label: 0.9}, valence: -2, kind: kind);
    }
    final low = _low.allMatches(text).length;
    final high = _high.allMatches(text).length;
    final valence = (high - low).clamp(-2, 2);
    return GuardianVerdict(crisis: false, crisisScores: const {'suicidal': 0.05}, valence: valence);
  }
}
