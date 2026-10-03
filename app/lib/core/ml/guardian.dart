/// Which kind of danger a crisis is. The help offered depends on it: a person being hurt by someone
/// else needs a different line from a person thinking of ending their life.
///
/// One kind per label of the trained Guardian's crisis head (docs/clinical/GUARDIAN_LABELS.md). The
/// lines each kind shows are in app/lib/features/shared/helplines.dart.
enum CrisisKind {
  suicide('suicidal'),
  selfHarm('self_harm'),
  abuse('abuse'),
  child('child'),
  sexualViolence('sexual_violence'),
  harmToOthers('harm_to_others'),
  medical('medical');

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

/// The order a message carrying several kinds of risk is routed in, most urgent first. A message
/// gets one sheet, so it gets the help for the danger that can't wait:
///
/// 1. medical: something already taken, a serious injury, a collapse. Minutes matter, so Rescue
///    comes before anything else, even when the reason behind it is suicidal (guide rule 7).
/// 2. suicide: a life at risk. Its lines (Umang, Rescue) also cover self-harm.
/// 3. harmToOthers: someone else's life at risk. Rescue and the police.
/// 4. child: a minor being harmed. It is always labelled together with abuse or sexual violence,
///    so it must outrank both or the child lines would never show.
/// 5. sexualViolence, then 6. abuse: harm by another person. Same lines; the sexual violence words
///    are the more specific when both fit.
/// 7. selfHarm: hurting oneself without stated intent to die. Every route above it except child
///    already shows Umang and Rescue, which are self-harm's lines.
const crisisPriority = [
  CrisisKind.medical,
  CrisisKind.suicide,
  CrisisKind.harmToOthers,
  CrisisKind.child,
  CrisisKind.sexualViolence,
  CrisisKind.abuse,
  CrisisKind.selfHarm,
];

/// The score at which a fired label is sure enough to take part in [crisisPriority].
///
/// The shipped thresholds are set for recall (Guardian v1b fires every crisis label at 0.02), so a
/// real crisis message usually fires a few labels it doesn't carry: on the held-out set 'medical'
/// fired 111 times for 41 true cases. Ranking every fired label by priority would send many people
/// talking about suicide to the medical sheet on a 0.03. So the labels the model is sure of (this
/// score or more) are ranked by priority, and when it is sure of none, its highest-scoring label
/// routes. Whether to step in at all is still decided by the thresholds alone. A bundle can set its
/// own value as `route_confidence` in config.json.
const defaultRouteConfidence = 0.5;

/// The kind to route [fired] labels to, given each label's [scores]. Null when nothing fired or no
/// fired label is a known kind.
CrisisKind? routeCrisis(Iterable<String> fired, Map<String, double> scores, {double confident = defaultRouteConfidence}) {
  final kinds = {for (final l in fired) ?CrisisKind.fromLabel(l)};
  if (kinds.isEmpty) return null;
  final sure = kinds.where((k) => (scores[k.label] ?? 0) >= confident).toSet();
  if (sure.isNotEmpty) return crisisPriority.firstWhere(sure.contains);
  // Ties go to the more urgent kind.
  return crisisPriority.where(kinds.contains).reduce((a, b) => (scores[b.label] ?? 0) > (scores[a.label] ?? 0) ? b : a);
}

/// What the on-device classifier says about one user message.
class GuardianVerdict {
  const GuardianVerdict({
    required this.crisis,
    required this.crisisScores,
    required this.valence,
    this.emotion,
    CrisisKind? kind,
    this.labels = const {},
  }) : _kind = kind;

  final bool crisis;
  final Map<String, double> crisisScores;
  final int valence; // −2..2
  final String? emotion;
  final CrisisKind? _kind;

  /// Every crisis label that fired, which may be several. [kind] is the one routed to.
  final Set<String> labels;

  /// Null when there is no crisis. A crisis with no finer reading is treated as suicide risk, the
  /// route with the widest help.
  CrisisKind? get kind => crisis ? (_kind ?? CrisisKind.suicide) : null;

  static const none = GuardianVerdict(crisis: false, crisisScores: {}, valence: 0);
}

/// Each label's highest score across [scores].
Map<String, double> maxScores(Iterable<Map<String, double>> scores) {
  final out = <String, double>{};
  for (final s in scores) {
    s.forEach((k, p) => out[k] = p > (out[k] ?? double.negativeInfinity) ? p : out[k]!);
  }
  return out;
}

/// One verdict from several reads of the same text, as the windows of a long message are: a crisis
/// in any window is a crisis, each score is its highest, the labels are every window's, the route
/// is chosen again from all of them, and valence is the lowest seen.
GuardianVerdict mergeVerdicts(List<GuardianVerdict> verdicts, {double confident = defaultRouteConfidence}) {
  if (verdicts.isEmpty) return GuardianVerdict.none;
  if (verdicts.length == 1) return verdicts.single;
  final scores = maxScores(verdicts.map((v) => v.crisisScores));
  final flagged = verdicts.where((v) => v.crisis).toList();
  final labels = {for (final v in flagged) ...v.labels};
  return GuardianVerdict(
    crisis: flagged.isNotEmpty,
    crisisScores: scores,
    valence: verdicts.map((v) => v.valence).reduce((a, b) => a < b ? a : b),
    emotion: verdicts.first.emotion,
    kind: flagged.isEmpty ? null : (routeCrisis(labels, scores, confident: confident) ?? flagged.first.kind),
    labels: labels,
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
    r'خودکشی|خود کشی|مرنا|جان دے|زہر (کھا|پی|لے|دے)'
    // Wishing not to wake up or to vanish for good (passive ideation, guide S1, S2, S8).
    r'|\bdisappear (for good|forever|permanently)|(never|not) wake up|(don.?t|do not|didn.?t) want to wake up(?! (early|at|for|so|before|on time))|(wish|hope|pray) i (didn.?t|don.?t|wouldn.?t|won.?t|never) wake|sleep (forever|and never wake)'
    r'|better off (without me|if i (was|were)n.?t|if i (was|were) (gone|dead)|if i die)|(if|when|once) i.?m (gone|dead|not around|no longer around)|after i.?m gone|if i (wasn.?t|weren.?t|was not|were not) (around|here|alive|in the picture)|relieved if i died'
    r'|(reason|point) (to|in|of) (keep )?(living|live|going on|go on|being alive|be alive|existing)|tired of (living|being alive)|don.?t want to (be here|keep living|keep going)|i (don.?t want to|won.?t) be (here|around|alive) (anymore|much longer|for long|tomorrow)|to not be here|not to be here'
    // A time, a decision or a goodbye (acuity plan_or_intent / imminent).
    r'|end (it|things|everything|my life)( all)? (tonight|today|tomorrow|soon|this week)|tonight.?s the night|tonight is the night|(this is|it was|it.?s been) nice knowing (you|everyone|y.?all)|goodbye (everyone|forever|world)|(my )?(last|final) (salaam|goodbye|words)|forgive me for everything'
    // Preparation for death with no death word (red line R1, guide rule 4): letters just in case, giving
    // things or pets away, passwords and bank details handed over, nothing left to sort.
    r'|(letters?|notes?|khat)\b.{0,60}\bjust in case|just in case\b.{0,30}\b(letters?|notes?)|(letters?|notes?) for (after|when i|if anything)|who (gets|will get|should get) my|(gave|give|giving|given) away (all my|all of my|everything|my (things|stuff|belongings|savings|books|laptop|phone|cat|dog|pets?))|(gave|giving|given) my (dog|cat|pets?|birds?|parrot|rabbit|fish)\b|(passwords?|logins?|pins?|bank details) (to|for) my|wrote down (all )?my passwords|nothing left to (do|sort|live for|say)|won.?t (need|be needing) (it|them|this|these|those|anything|my \w+) (much longer|where i.?m going|after)'
    // Self-harm in general words, and hiding the marks (guide H3, H8, H10).
    r'|(burn|burned|burnt|burning|harm|harming|harmed|starve|starving) myself|(hurting|harming|cutting) (herself|himself|themselves|yourself)|(hide|hiding|cover|covering) (the |my |these |those )?(marks|cuts|scars)|(fresh|new) (marks|cuts)'
    // Roman Urdu: every spelling of khudkushi, ending everything, not wanting to live (MODEL_REVIEW item 5).
    r'|khud[ -]?k(h)?(u|a)shi|sab (kuch )?(khatam|khtm) (kar|kr) ?(d|l)(u|oo|un|oon|unga|ungi|enge)\b|(sab|zindagi|khud ko|apne aap ko) (kuch )?(khatam|khtm) (karna|krna|karne|krne) (hai|h|ka|ki|chah)|jee?n(a|e) (hi )?(nahi|nahin|nai|nhi|ni)\b|jeene (ka|ki|ko) (koi )?(faida|fayda|maqsad|wajah|dil nahi|dil nai|dil nhi|mann nahi|man nahi)|zindagi (nahi|nahin|nai|nhi) chahiye|zinda (nahi|nahin|nai|nhi|na) (rehna|rehena|rahna)'
    // Roman Urdu passive wishes, timing and goodbyes. A bare 'aakhri dafa' is also "I'm telling you for the last
    // time", so it needs a goodbye after it.
    r'|mar(ne|ny|nay) (ka|ki|ko) (dil|man|mann|jee|soch|khayal|khwahish|irada|faisla)|(allah|khuda|rab) (mujhe |mjhe |muje )?(utha|bula) le|(kabhi|phir|dobara) na uth|na uth(ti|ta) to (acha|behtar)|kash (main |mai )?na uth|(subah|kal) (na|nahi|nai|nhi) dekhn|(main|mai|mein) na (rahun|rahoon|rahu|hun|hoon|hoti|hota) to|jab (main|mai) na (rahun|rahoon|rahu|rahi|raha)|mere (jaane|jane|marne) (ke )?baad|hamesha (ke liye|k liye) (so |chala ja|chali ja|alvida)|aakhri (khat|salaam|alvida)|aakhri (dafa|baar|bar) (baat|mil|dekh)|sab ko alvida'
    // Roman Urdu self-harm. 'khud ko takleef' is left out: it is also the polite "don't trouble yourself".
    r'|(khud|apne aap) ko (hurt|nuqsaan|nuksan|nuksaan|nukhsan|zakhmi|dard de|saza de|kaat|jala)|(nishaan|nishan|nishanat|zakhm|zakham) (chhupa|chupa|chhup|chup)'
    // Urdu script: the same, written as people type it.
    r'|جینا نہیں|جینے کا (کوئی )?(فائدہ|مقصد)|زندہ نہیں رہنا|مر جاؤں|مرجاؤں|مر جانا|(اللہ|خدا) (مجھے )?(اٹھا|بلا) لے|سب ختم کر (دوں|لوں)|(خود|اپنے آپ) کو (ختم|نقصان|مار|زخمی|تکلیف دے|سزا دے)|نہ رہوں|میرے (جانے|مرنے) (کے )?بعد|آخری (خط|سلام)|آخری (بار|دفعہ) بات|(نشان|زخم) (چھپا|چھپ)|کبھی نہ اٹھ|صبح نہ دیکھ'
    // Ending or killing in other tenses (QA CR-001), method and dose questions (guide rule 3), and a dose
    // already taken, which is also a medical emergency (guide M1, M6, M10, M12).
    r'|ending (it all|my life|my own life|everything)|killing myself|taking my (own )?life|my (own )?funeral|for if anything happens to me|(painless|easiest|quickest|fastest|surest) way to (die|go|do it|end)|(lethal|fatal) (dose|amount)|\boverdos|how many .{0,30}(pills|tablets) .{0,30}(take|kill|die|enough|would it)|(took|swallowed|taken|have taken) (all|about|like|\d+|twenty|ten|fifty|a lot of|a bunch of|a handful of|the whole|half) .{0,25}(pills|tablets)|(count(ed|ing)|saving|saved|stockpil\w*) .{0,15}(pills|tablets)|(pills|tablets)\b.{0,30}\bcounted|(bleach|phenyl|poison|tezaab|acid|keeray maar \w+) (pee|pi|pii|kha|khaa|drank|swallowed)'
    // Self-harm said plainly (guide H1, H2, H6, H7, H9, H10). 'khud ko takleef' counts only in the first
    // person, because "aap khud ko takleef na dein" is a courtesy.
    r'|\bi (cut|burned|burnt) (again|last night|today|myself|my (arm|wrist|thigh|leg)s?)|(until|till) (it|they|i|my \w+) bleeds?|blade (utha|uthaya|liya|li)|(khud|apne aap) ko (maar(ti|ta|te)|takleef dene (ka|ki)|takleef de(ti|ta|te) (hun|hoon|hu))|(nishaan|nishan|nishanat|zakhm|zakham|marks?)\b.{0,40}(chhupa|chupa|chhup|chup|dikh)|na (hoti|hota|hote) to (acha|behtar)|maafi (ka|ke) (message|msg|messages)'
    // Urdu script: not wanting to live on (QA CR-003), self-harm, pills taken.
    r'|نہیں رہنا چاہت|کٹ لگا|خود کو تکلیف دینے|(نشان|زخم).{0,40}چھپا|گولیاں (کھا لی|جمع)|زہر (پی|کھا) لیا'
    // Urdu script: more ways people say it, from the written training batches.
    r'|نہیں جی (سکت|سکو|پا)|مزید نہیں جی|مرنے کا (طریقہ|سوچ|دل|خیال|ارادہ)|جان خود لے|اپنی جان (لے|دے)|آخری (ملاقات|کال)|آخری بار سب|الوداع|خود کو تکلیف دی(تا|تی|نا)|مر ہی جاؤں|جانے کا وقت|ختم کر (لوں|دوں) گ|ختم کر لوں گ|ہمیشہ کا (سکون|نیند)|اٹھا (کیوں )?نہیں لیتا|ایسی زندگی کا|کر بیٹھوں|(بازو|کلائی) (کے|پر|پہ) (نشان|کٹ)|کوشش کی تھی)',
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
    r'\b(mujhe|mujhko|muje) (\w+ )?chhu(a|aa|ya|ta|te|ne)\b|galat (tareeqe|tarah|jagah) (se )?chhu|زیادتی'
    // Force, groping, sextortion and "I said no" as people describe them; 'forcing me' alone is also
    // "forcing me to study medicine", so force needs a reflexive or 'kiya'.
    r'|forc(ed|es|ing) (himself|herself)|force (kiya|kia|karta|krta)|\bgrop(e|ed|es|ing)\b|assault(ed|s|ing)? me\b|harass(es|ed|ing)? me\b|\bharassment\b|\bnudes\b|(asking|asked|asks) (me )?for (pics|pictures|photos)|(pics|pictures|photos|videos|tasveer\w*|tasvir\w*)\b.{0,40}\b(unless|viral|leak\w*|send (them )?to (everyone|my))|(viral|leak) (kar|kr) (de|du|dun|dega|denge|doon|dungi)|even (though|after|when) i said (no|stop)|i said (no|stop)\W+(and|but) (he|she|they) (didn.?t|did not|wouldn.?t|kept|still|forced|carried|did it)|(ghalat|galat) (harkat\w*|kaam)|zabrdasti|zbrdsti|ziadti|ziyadti|زبردستی|غلط (حرکت|طریقے|جگہ)|ہراساں|ہراسانی'
    // Grooming, image-based abuse and unwanted touch as they are described (guide C3, C10, C13, V2, V3, V16).
    r'|(comes?|came) (in)?to my room (at night|when)|(it.?s|its) our (little )?secret|(post|share|send|leak|upload)\w* my (private |intimate |nude )?(photos|pics|pictures|videos)|(photos|pics|pictures|videos)\b.{0,40}\bif i (don.?t|do not|won.?t)|touch(es|ing|ed)? my (waist|body|chest|breasts?|thighs?|legs?|bum|butt)|spiked my drink|تصویریں مانگ'
    // Urdu script: rape, abuse in a madrasa or at home, image threats.
    r'|ریپ|غلط کام کر|چھیڑ|ویڈیوز بنا|تصویریں.{0,30}(بھیج|دکھا|ڈال)|انٹرنیٹ (پہ|پر) ڈال)',
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
    r'ghar (mein|me) band|تشدد|مارتا'
    // More of what a person does to the user, threats to kill or 'make me disappear', honour threats. A
    // parent who "will kill me" over a result is an idiom (guide N3), so a threat needs 'says' or 'threatened'.
    r'|(threaten\w*|swore|swears|says|said|told me)( that)? (he|she|they)?(.?ll| will| would| is going to| are going to)? ?(kill|finish|bury|burn) (me|us|her|him|my)\b|(kill|murder|bury) (me|her|him|us|my \w+) (for|over) (honou?r|izzat|ghairat)|honou?r (killing|threat)|make me disappear|(no one|nobody) will (ever )?find my body'
    // Roman Urdu: a raised hand, beating with a belt or stick, death threats, being locked in.
    r'|(haath|hath) (uthata|uthaata|uthati|uthate|uthaya|uthaaya|utha chuka)|(belt|danda|dande|dando|chhari|chappal|joot\w*) (se|say) (maar|mara|maara|peet|pita)|(mujhe|mjhe|muje|mujhko|humein|hume|ammi ko|amma ko) (bohat |roz |phir |bht |bohot |bura )?(maara|mara|maarta|marta|maarti|marti|maarte|peeta|peet(a|e|i|ta|te|ti)|pitai)\b|jaan se (maar|mar) (de|da|dal|daal)|(zinda|jeeta|jeeti) (nahi|nahin|nai|nhi) (chho?r|chor)|(kamre|kamray|ghar) (mein|me|main|mai) band (kar|kr|rakh)|ghairat (ke|ki|k) (naam|khatir|wajah)|(jaan|maarne|qatal|tezaab|jalane|jala) (se maarne )?ki (dhamki|dhamkiyan|dhamky)|(maar|mar) (ke|kar|kr) (ghar se )?nikal'
    // Urdu script.
    r'|مار(تی|تے) (ہے|ہیں)|مار پیٹ|تھپڑ|ہاتھ اٹھا|جان سے مار|(کمرے|گھر) میں بند|غیرت کے نام|پیٹتا|پیٹتے|پٹائی|مارنے کی دھمکی'
    // A person close to the user doing more than hitting: pushing, strangling, locking in (guide A1, A2, A10).
    r'|\b' '$_someone' r'\b( \w+)? (pushed|pushes|shoved|shoves|punched|punches|strangled|strangles|dragged|drags|burned|burns|locked|locks|lock|threw|throws) me\b'
    r'|\b(slaps|slapped|punched|punches|shoved|shoves|strangled|choked|chokes) me\b|(brother|husband|father|abbu|bhai|uncle|chacha|ex|in-?laws)\b.{0,40}\b(kill|finish|bury) (me|us|her)\b|gala (dabaya|dabata|dabati|dabate|daba diya)|jala (dein|denge|dega|degi|dalenge|daalenge|dein ge|den ge|de ga|de gi)|maar kha(ta|ti|te|ya|yi)\b|peet.?te (hain|hai)|گلا دبا|جلا (دیں|دے) گ'
    // Risk to someone other than the user (harm_to_others, guide O1-O15). The floor has no kind of its own for
    // it, and this route shows Rescue 1122 as well as Madadgaar.
    r'|make (him|her|them) pay|i.?m going to (kill|hurt|stab|shoot) (him|her|them)|jaan se maar (doon|dun|dunga|dungi|dalunga|daalunga)|(chaaku|chaku|churi|chhuri|knife|pistol|gun|bandook|bandooq)\b.{0,40}(rakha|rakh li|intezam|mil gay|mil gai|ready|in my bag)|(hurt|shake|harm) (my|the) baby|(bachon|bachay|bache|bachey) ko .{0,20}maar (deti|deta)|بچے کو نقصان|پستول'
    // Urdu script: threats to kill or bury, breaking bones, a push.
    r'|(مار|قتل|جان).{0,30}دھمکی|دھمکی.{0,30}(مار|قتل|جان)|لاش بن|قبر یہیں|دفنا دوں|کام تمام کر|ہڈیاں توڑ (دوں|دے گا|دیں گے)|ہاتھ پاؤں توڑ|بازو توڑ|دھکا دیا|بہت مارا|مار دوں گا|سبق سکھاؤں)',
    caseSensitive: false,
  );

  /// A sign the person is a child: an age under 18, school, or a step-parent with an abuse hit.
  static final _minor = RegExp(
    r"(\b(i am|i'm|im|main|meri umar) ([5-9]|1[0-7])\b|\b([5-9]|1[0-7]) (years? old|saal)\b|\bschool\b|class \d|"
    r'\bstep ?(dad|father|mom|mother)\b|sautel[aie]'
    // "14 ki hun", "class 7", "9th", madrasa, and Urdu-script school words.
    r'|\b([5-9]|1[0-7]) (ki|ka) (hun|hoon|hu|hn)\b|\b(class|grade) ?([1-9]|1[0-2])\b|\b([5-9]|1[0-2])(th|st|nd|rd)\b|\bmatric\b|madrass?a|madrasse|سکول|اسکول|مدرس|کلاس'
    // An age written in Urdu script, in either digits or words.
    r'|(^|[^0-9۰-۹])([5-9]|1[0-7]|[۵-۹]|۱[۰-۷]) (سال|کا ہوں|کی ہوں|کا ہے|کی ہے)|(پانچ|چھ|سات|آٹھ|نو|دس|گیارہ|بارہ|تیرہ|چودہ|پندرہ|سولہ|سترہ) سال)',
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
      return GuardianVerdict(crisis: true, crisisScores: {kind.label: 0.9}, valence: -2, kind: kind, labels: {kind.label});
    }
    final low = _low.allMatches(text).length;
    final high = _high.allMatches(text).length;
    final valence = (high - low).clamp(-2, 2);
    return GuardianVerdict(crisis: false, crisisScores: const {'suicidal': 0.05}, valence: valence);
  }
}
