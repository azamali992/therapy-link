"""Guardian: one XLM-RoBERTa encoder, one classification head per task.

Multi-label tasks (crisis, emotion) use BCE and per-class thresholds calibrated on the
validation set to hit a target recall. Single-label tasks (valence, condition) use CE.

Guardian v1's crisis head is multi-label over CRISIS_LABELS, so the app can tell a person at risk
of suicide from a person being hurt by someone else and show the right line. `heldout` reports
recall per language and per category on a clinician-written file kept apart from the 24 safety
probes the thresholds are tuned against.
"""

from __future__ import annotations

import json
import random
import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import torch
import typer
from rich.console import Console
from rich.table import Table
from sklearn.metrics import f1_score, precision_recall_fscore_support
from torch import nn
from torch.utils.data import DataLoader, Dataset
from transformers import AutoModel, AutoTokenizer, get_cosine_schedule_with_warmup

from therapylink_ml.schema import LabeledText, stable_id

ML_ROOT = Path(__file__).resolve().parents[2]
DATA = ML_ROOT / "data" / "processed"
MULTI_LABEL_TASKS = {"crisis", "emotion"}
# Crisis is deliberately recall-calibrated: missing a suicidal message costs far more than a false
# alarm, which only shows the user a helpline. Emotion has no such asymmetry — forcing 0.6 recall
# across 28 classes destroys precision on rare ones — so it gets F1-optimal thresholds instead.
RECALL_TARGETS = {"crisis": 0.95}
# Guardian v1 calibrates the crisis head per language: each label's threshold is the lowest that any
# language needs to reach the target on validation, so no language is carried by another's recall.
# Validation is written by the same authors as training and scores higher than new text will, so
# the target here sits above the 0.95 the held-out gate asks for.
LANG_RECALL_TARGET = 0.98
MIN_LANG_POSITIVES = 5

# Guardian v1's crisis head. Fixed, not derived from the data: the app maps each label to the help
# it shows (abuse and child route to Madadgaar 1098), so a label missing from one corpus build must
# still exist as an output rather than silently shift every index after it.
CRISIS_LABELS = ("none", "suicidal", "self_harm", "abuse", "child", "sexual_violence", "harm_to_others", "medical")

app = typer.Typer(add_completion=False, no_args_is_help=True)
console = Console()


# --- Keyword floor -------------------------------------------------------------------------------
# An exact mirror of HeuristicGuardian in app/lib/core/ml/guardian.dart: the floor under the
# trained model and the whole check until it is installed. tests/test_train_guardian.py reads the
# Dart file and fails on any drift, so change both together. The pieces are kept as the Dart raw
# strings are split, which is what makes that comparison exact.

SOMEONE = (
    r'(he|she|they|someone|somebody|husband|wife|partner|boyfriend|girlfriend|fiance|ex|father|dad|abbu|'
    r'mother|mom|mum|ammi|parents|brother|bhai|sister|uncle|chacha|mamu|aunt|cousin|step ?(dad|father|mom|mother)|'
    r'in-?laws|teacher|tutor|coach|neighbou?r|man|guy|boss|stranger|friend)'
)

# Suicide and self-harm. Verb forms are gender-neutral (chahta/chahti/chahte): a pattern written in
# the masculine misses every woman who says the same thing.
CRISIS_SOURCE = (
    r'(kill myself|end it all|end my life|take my (own )?life|want to die|not wake up|suicid|hurt myself|self.?harm|'
    r'cut(ting)? myself|hang myself|better off dead|don.?t want to (live|be alive|exist)|\bkms\b|unalive|'
    r'khud ?kushi|marna chaht[aie]|mar ja(u|un|on|oon|na|ana|aana)\b|jeena nahi|zindagi khatam|'
    r'apne aap ko (hurt|nuqsan|khatam)|khud ko (khatam|maar|nuqsan)|zinda (nahi|nahin|na) rehna|'
    r'\b(apni|meri|khud ki) jaan (de|le)\b|\bjaan (de|le) (d|l)(u|oo|un|oon|unga|ungi|enge)\b|'
    r'zeh[ae]r (kha|pi|pee|le|la|de|mang|kharid)|goliyan|'
    r'خودکشی|خود کشی|مرنا|جان دے|زہر (کھا|پی|لے|دے)'
    # Wishing not to wake up or to vanish for good (passive ideation, guide S1, S2, S8).
    r'|\bdisappear (for good|forever|permanently)|(never|not) wake up|(don.?t|do not|didn.?t) want to wake up(?! (early|at|for|so|before|on time))|(wish|hope|pray) i (didn.?t|don.?t|wouldn.?t|won.?t|never) wake|sleep (forever|and never wake)'
    r'|better off (without me|if i (was|were)n.?t|if i (was|were) (gone|dead)|if i die)|(if|when|once) i.?m (gone|dead|not around|no longer around)|after i.?m gone|if i (wasn.?t|weren.?t|was not|were not) (around|here|alive|in the picture)|relieved if i died'
    r'|(reason|point) (to|in|of) (keep )?(living|live|going on|go on|being alive|be alive|existing)|tired of (living|being alive)|don.?t want to (be here|keep living|keep going)|i (don.?t want to|won.?t) be (here|around|alive) (anymore|much longer|for long|tomorrow)|to not be here|not to be here'
    # A time, a decision or a goodbye (acuity plan_or_intent / imminent).
    r'|end (it|things|everything|my life)( all)? (tonight|today|tomorrow|soon|this week)|tonight.?s the night|tonight is the night|(this is|it was|it.?s been) nice knowing (you|everyone|y.?all)|goodbye (everyone|forever|world)|(my )?(last|final) (salaam|goodbye|words)|forgive me for everything'
    # Preparation for death with no death word (red line R1, guide rule 4): letters just in case, giving
    # things or pets away, passwords and bank details handed over, nothing left to sort.
    r'|(letters?|notes?|khat)\b.{0,60}\bjust in case|just in case\b.{0,30}\b(letters?|notes?)|(letters?|notes?) for (after|when i|if anything)|who (gets|will get|should get) my|(gave|give|giving|given) away (all my|all of my|everything|my (things|stuff|belongings|savings|books|laptop|phone|cat|dog|pets?))|(gave|giving|given) my (dog|cat|pets?|birds?|parrot|rabbit|fish)\b|(passwords?|logins?|pins?|bank details) (to|for) my|wrote down (all )?my passwords|nothing left to (do|sort|live for|say)|won.?t (need|be needing) (it|them|this|these|those|anything|my \w+) (much longer|where i.?m going|after)'
    # Self-harm in general words, and hiding the marks (guide H3, H8, H10).
    r'|(burn|burned|burnt|burning|harm|harming|harmed|starve|starving) myself|(hurting|harming|cutting) (herself|himself|themselves|yourself)|(hide|hiding|cover|covering) (the |my |these |those )?(marks|cuts|scars)|(fresh|new) (marks|cuts)'
    # Roman Urdu: every spelling of khudkushi, ending everything, not wanting to live (MODEL_REVIEW item 5).
    r'|khud[ -]?k(h)?(u|a)shi|sab (kuch )?(khatam|khtm) (kar|kr) ?(d|l)(u|oo|un|oon|unga|ungi|enge)\b|(sab|zindagi|khud ko|apne aap ko) (kuch )?(khatam|khtm) (karna|krna|karne|krne) (hai|h|ka|ki|chah)|jee?n(a|e) (hi )?(nahi|nahin|nai|nhi|ni)\b|jeene (ka|ki|ko) (koi )?(faida|fayda|maqsad|wajah|dil nahi|dil nai|dil nhi|mann nahi|man nahi)|zindagi (nahi|nahin|nai|nhi) chahiye|zinda (nahi|nahin|nai|nhi|na) (rehna|rehena|rahna)'
    # Roman Urdu passive wishes, timing and goodbyes. A bare 'aakhri dafa' is also "I'm telling you for the last
    # time", so it needs a goodbye after it.
    r'|mar(ne|ny|nay) (ka|ki|ko) (dil|man|mann|jee|soch|khayal|khwahish|irada|faisla)|(allah|khuda|rab) (mujhe |mjhe |muje )?(utha|bula) le|(kabhi|phir|dobara) na uth|na uth(ti|ta) to (acha|behtar)|kash (main |mai )?na uth|(subah|kal) (na|nahi|nai|nhi) dekhn|(main|mai|mein) na (rahun|rahoon|rahu|hun|hoon|hoti|hota) to|jab (main|mai) na (rahun|rahoon|rahu|rahi|raha)|mere (jaane|jane|marne) (ke )?baad|hamesha (ke liye|k liye) (so |chala ja|chali ja|alvida)|aakhri (khat|salaam|alvida)|aakhri (dafa|baar|bar) (baat|mil|dekh)|sab ko alvida'
    # Roman Urdu self-harm. 'khud ko takleef' is left out: it is also the polite "don't trouble yourself".
    r'|(khud|apne aap) ko (hurt|nuqsaan|nuksan|nuksaan|nukhsan|zakhmi|dard de|saza de|kaat|jala)|(nishaan|nishan|nishanat|zakhm|zakham) (chhupa|chupa|chhup|chup)'
    # Urdu script: the same, written as people type it.
    r'|جینا نہیں|جینے کا (کوئی )?(فائدہ|مقصد)|زندہ نہیں رہنا|مر جاؤں|مرجاؤں|مر جانا|(اللہ|خدا) (مجھے )?(اٹھا|بلا) لے|سب ختم کر (دوں|لوں)|(خود|اپنے آپ) کو (ختم|نقصان|مار|زخمی|تکلیف دے|سزا دے)|نہ رہوں|میرے (جانے|مرنے) (کے )?بعد|آخری (خط|سلام)|آخری (بار|دفعہ) بات|(نشان|زخم) (چھپا|چھپ)|کبھی نہ اٹھ|صبح نہ دیکھ'
    # Ending or killing in other tenses (QA CR-001), method and dose questions (guide rule 3), and a dose
    # already taken, which is also a medical emergency (guide M1, M6, M10, M12).
    r'|ending (it all|my life|my own life|everything)|killing myself|taking my (own )?life|my (own )?funeral|for if anything happens to me|(painless|easiest|quickest|fastest|surest) way to (die|go|do it|end)|(lethal|fatal) (dose|amount)|\boverdos|how many .{0,30}(pills|tablets) .{0,30}(take|kill|die|enough|would it)|(took|swallowed|taken|have taken) (all|about|like|\d+|twenty|ten|fifty|a lot of|a bunch of|a handful of|the whole|half) .{0,25}(pills|tablets)|(count(ed|ing)|saving|saved|stockpil\w*) .{0,15}(pills|tablets)|(pills|tablets)\b.{0,30}\bcounted|(bleach|phenyl|poison|tezaab|acid|keeray maar \w+) (pee|pi|pii|kha|khaa|drank|swallowed)'
    # Self-harm said plainly (guide H1, H2, H6, H7, H9, H10). 'khud ko takleef' counts only in the first
    # person, because "aap khud ko takleef na dein" is a courtesy.
    r'|\bi (cut|burned|burnt) (again|last night|today|myself|my (arm|wrist|thigh|leg)s?)|(until|till) (it|they|i|my \w+) bleeds?|blade (utha|uthaya|liya|li)|(khud|apne aap) ko (maar(ti|ta|te)|takleef dene (ka|ki)|takleef de(ti|ta|te) (hun|hoon|hu))|(nishaan|nishan|nishanat|zakhm|zakham|marks?)\b.{0,40}(chhupa|chupa|chhup|chup|dikh)|na (hoti|hota|hote) to (acha|behtar)|maafi (ka|ke) (message|msg|messages)'
    # Urdu script: not wanting to live on (QA CR-003), self-harm, pills taken.
    r'|نہیں رہنا چاہت|کٹ لگا|خود کو تکلیف دینے|(نشان|زخم).{0,40}چھپا|گولیاں (کھا لی|جمع)|زہر (پی|کھا) لیا'
    # Urdu script: more ways people say it, from the written training batches.
    r'|نہیں جی (سکت|سکو|پا)|مزید نہیں جی|مرنے کا (طریقہ|سوچ|دل|خیال|ارادہ)|جان خود لے|اپنی جان (لے|دے)|آخری (ملاقات|کال)|آخری بار سب|الوداع|خود کو تکلیف دی(تا|تی|نا)|مر ہی جاؤں|جانے کا وقت|ختم کر (لوں|دوں) گ|ختم کر لوں گ|ہمیشہ کا (سکون|نیند)|اٹھا (کیوں )?نہیں لیتا|ایسی زندگی کا|کر بیٹھوں|(بازو|کلائی) (کے|پر|پہ) (نشان|کٹ)|کوشش کی تھی)'
)

SEXUAL_SOURCE = (
    r'(\braped?\b|sexual(ly)? (assault|abuse|harass)|molest|zabardasti|zyadati|'
    r'\b' + SOMEONE + r'\b( \w+)? touch(ed|es|ing)? me\b|'
    r'touch(ed|es|ing)? me (there|inappropriately|without)|inappropriately touch|'
    r'\b(mujhe|mujhko|muje) (\w+ )?chhu(a|aa|ya|ta|te|ne)\b|galat (tareeqe|tarah|jagah) (se )?chhu|زیادتی'
    # Force, groping, sextortion and "I said no" as people describe them; 'forcing me' alone is also
    # "forcing me to study medicine", so force needs a reflexive or 'kiya'.
    r'|forc(ed|es|ing) (himself|herself)|force (kiya|kia|karta|krta)|\bgrop(e|ed|es|ing)\b|assault(ed|s|ing)? me\b|harass(es|ed|ing)? me\b|\bharassment\b|\bnudes\b|(asking|asked|asks) (me )?for (pics|pictures|photos)|(pics|pictures|photos|videos|tasveer\w*|tasvir\w*)\b.{0,40}\b(unless|viral|leak\w*|send (them )?to (everyone|my))|(viral|leak) (kar|kr) (de|du|dun|dega|denge|doon|dungi)|even (though|after|when) i said (no|stop)|i said (no|stop)\W+(and|but) (he|she|they) (didn.?t|did not|wouldn.?t|kept|still|forced|carried|did it)|(ghalat|galat) (harkat\w*|kaam)|zabrdasti|zbrdsti|ziadti|ziyadti|زبردستی|غلط (حرکت|طریقے|جگہ)|ہراساں|ہراسانی'
    # Grooming, image-based abuse and unwanted touch as they are described (guide C3, C10, C13, V2, V3, V16).
    r'|(comes?|came) (in)?to my room (at night|when)|(it.?s|its) our (little )?secret|(post|share|send|leak|upload)\w* my (private |intimate |nude )?(photos|pics|pictures|videos)|(photos|pics|pictures|videos)\b.{0,40}\bif i (don.?t|do not|won.?t)|touch(es|ing|ed)? my (waist|body|chest|breasts?|thighs?|legs?|bum|butt)|spiked my drink|تصویریں مانگ'
    # Urdu script: rape, abuse in a madrasa or at home, image threats.
    r'|ریپ|غلط کام کر|چھیڑ|ویڈیوز بنا|تصویریں.{0,30}(بھیج|دکھا|ڈال)|انٹرنیٹ (پہ|پر) ڈال)'
)

ABUSE_SOURCE = (
    r'(\b' + SOMEONE + r'\b( \w+)? (hits?|hitting|beats?|beating|slaps?|slapped|slapping|chokes?|choked|choking|kicks?|kicked) me\b|'
    r'beat me up|beating me|domestic (violence|abuse)|'
    r'\babus(ed|es|ing) me\b|\babusive to me\b|\b(was|am|being|been|got) abused\b|abused as a (child|kid)|'
    r'abusive (husband|wife|partner|boyfriend|girlfriend|father|dad|mother|mom|parents|relationship|marriage|home)|'
    r'\b(husband|wife|partner|boyfriend|girlfriend|father|dad|mother|mom|parents|in-?laws) (is|are|was|were|has been|gets) (\w+ )?abusive|'
    r'maar(ta|ti|te) (hai|hain|hy)|mujhe maar(a|ta|ti|te)|mujhe peet|pit(a|aa)i|thappar|'
    r'ghar (mein|me) band|تشدد|مارتا'
    # More of what a person does to the user, threats to kill or 'make me disappear', honour threats. A
    # parent who "will kill me" over a result is an idiom (guide N3), so a threat needs 'says' or 'threatened'.
    r'|(threaten\w*|swore|swears|says|said|told me)( that)? (he|she|they)?(.?ll| will| would| is going to| are going to)? ?(kill|finish|bury|burn) (me|us|her|him|my)\b|(kill|murder|bury) (me|her|him|us|my \w+) (for|over) (honou?r|izzat|ghairat)|honou?r (killing|threat)|make me disappear|(no one|nobody) will (ever )?find my body'
    # Roman Urdu: a raised hand, beating with a belt or stick, death threats, being locked in.
    r'|(haath|hath) (uthata|uthaata|uthati|uthate|uthaya|uthaaya|utha chuka)|(belt|danda|dande|dando|chhari|chappal|joot\w*) (se|say) (maar|mara|maara|peet|pita)|(mujhe|mjhe|muje|mujhko|humein|hume|ammi ko|amma ko) (bohat |roz |phir |bht |bohot |bura )?(maara|mara|maarta|marta|maarti|marti|maarte|peeta|peet(a|e|i|ta|te|ti)|pitai)\b|jaan se (maar|mar) (de|da|dal|daal)|(zinda|jeeta|jeeti) (nahi|nahin|nai|nhi) (chho?r|chor)|(kamre|kamray|ghar) (mein|me|main|mai) band (kar|kr|rakh)|ghairat (ke|ki|k) (naam|khatir|wajah)|(jaan|maarne|qatal|tezaab|jalane|jala) (se maarne )?ki (dhamki|dhamkiyan|dhamky)|(maar|mar) (ke|kar|kr) (ghar se )?nikal'
    # Urdu script.
    r'|مار(تی|تے) (ہے|ہیں)|مار پیٹ|تھپڑ|ہاتھ اٹھا|جان سے مار|(کمرے|گھر) میں بند|غیرت کے نام|پیٹتا|پیٹتے|پٹائی|مارنے کی دھمکی'
    # A person close to the user doing more than hitting: pushing, strangling, locking in (guide A1, A2, A10).
    r'|\b' + SOMEONE + r'\b( \w+)? (pushed|pushes|shoved|shoves|punched|punches|strangled|strangles|dragged|drags|burned|burns|locked|locks|lock|threw|throws) me\b'
    r'|\b(slaps|slapped|punched|punches|shoved|shoves|strangled|choked|chokes) me\b|(brother|husband|father|abbu|bhai|uncle|chacha|ex|in-?laws)\b.{0,40}\b(kill|finish|bury) (me|us|her)\b|gala (dabaya|dabata|dabati|dabate|daba diya)|jala (dein|denge|dega|degi|dalenge|daalenge|dein ge|den ge|de ga|de gi)|maar kha(ta|ti|te|ya|yi)\b|peet.?te (hain|hai)|گلا دبا|جلا (دیں|دے) گ'
    # Risk to someone other than the user (harm_to_others, guide O1-O15). The floor has no kind of its own for
    # it, and this route shows Rescue 1122 as well as Madadgaar.
    r'|make (him|her|them) pay|i.?m going to (kill|hurt|stab|shoot) (him|her|them)|jaan se maar (doon|dun|dunga|dungi|dalunga|daalunga)|(chaaku|chaku|churi|chhuri|knife|pistol|gun|bandook|bandooq)\b.{0,40}(rakha|rakh li|intezam|mil gay|mil gai|ready|in my bag)|(hurt|shake|harm) (my|the) baby|(bachon|bachay|bache|bachey) ko .{0,20}maar (deti|deta)|بچے کو نقصان|پستول'
    # Urdu script: threats to kill or bury, breaking bones, a push.
    r'|(مار|قتل|جان).{0,30}دھمکی|دھمکی.{0,30}(مار|قتل|جان)|لاش بن|قبر یہیں|دفنا دوں|کام تمام کر|ہڈیاں توڑ (دوں|دے گا|دیں گے)|ہاتھ پاؤں توڑ|بازو توڑ|دھکا دیا|بہت مارا|مار دوں گا|سبق سکھاؤں)'
)

MINOR_SOURCE = (
    r"(\b(i am|i'm|im|main|meri umar) ([5-9]|1[0-7])\b|\b([5-9]|1[0-7]) (years? old|saal)\b|\bschool\b|class \d|"
    r'\bstep ?(dad|father|mom|mother)\b|sautel[aie]'
    # "14 ki hun", "class 7", "9th", madrasa, and Urdu-script school words.
    r'|\b([5-9]|1[0-7]) (ki|ka) (hun|hoon|hu|hn)\b|\b(class|grade) ?([1-9]|1[0-2])\b|\b([5-9]|1[0-2])(th|st|nd|rd)\b|\bmatric\b|madrass?a|madrasse|سکول|اسکول|مدرس|کلاس'
    # An age written in Urdu script, in either digits or words.
    r'|(^|[^0-9۰-۹])([5-9]|1[0-7]|[۵-۹]|۱[۰-۷]) (سال|کا ہوں|کی ہوں|کا ہے|کی ہے)|(پانچ|چھ|سات|آٹھ|نو|دس|گیارہ|بارہ|تیرہ|چودہ|پندرہ|سولہ|سترہ) سال)'
)

# re.ASCII because Dart's RegExp is JavaScript's: \b and \w are ASCII there too.
_FLAGS = re.I | re.ASCII
_CRISIS = re.compile(CRISIS_SOURCE, _FLAGS)
_SEXUAL = re.compile(SEXUAL_SOURCE, _FLAGS)
_ABUSE = re.compile(ABUSE_SOURCE, _FLAGS)
_MINOR = re.compile(MINOR_SOURCE, _FLAGS)


def keyword_kind(text: str) -> str | None:
    """The crisis label the keywords alone give `text` (HeuristicGuardian.kindOf), or None."""
    if _CRISIS.search(text):
        return "suicidal"
    sexual, abuse = bool(_SEXUAL.search(text)), bool(_ABUSE.search(text))
    if not sexual and not abuse:
        return None
    if _MINOR.search(text):
        return "child"
    return "sexual_violence" if sexual else "abuse"


def _keyword_crisis(text: str) -> bool:
    """What ships when no model is installed. A trained model has to beat this to be worth downloading."""
    return keyword_kind(text) is not None


# --- Authored conversations as crisis examples ---------------------------------------------------
# The authored rows are the only Roman Urdu and mixed crisis text we have, and the only abuse,
# child and sexual-violence examples at all (mh_text is suicidal-vs-none Reddit).

AUTHORED_CATEGORY_LABELS = {
    "none": ["none"],
    "suicide_passive": ["suicidal"],
    "suicide_active": ["suicidal"],
    "crisis_with_memory": ["suicidal"],
    "indirect_signs": ["suicidal"],
    "method_request": ["suicidal"],
    "asking_for_a_friend": ["suicidal"],
    "self_harm": ["self_harm"],
    "domestic_violence": ["abuse"],
    "elder_abuse": ["abuse"],
    "honour_threat": ["abuse", "harm_to_others"],
    "child_endangerment": ["child", "abuse"],
    "child_user": ["child"],
    "child_sexual_abuse_historic": ["sexual_violence"],
    "rape": ["sexual_violence"],
    "sexual_violence": ["sexual_violence"],
    "sexual_harassment": ["sexual_violence"],
    "eating_disorder": ["medical"],
    "medication_request": ["none"],
    "listy_advice": ["none"],
}


def authored_crisis_texts(include_pending: bool = False) -> list[LabeledText]:
    """One user turn per authored row, labelled by category (a row's guardian_labels win).

    For a crisis row it is the turn the risk appears in (crisis_turn), which in a multi-turn row is
    not the first: "rough time since losing my job" labelled suicidal would teach the head the
    wrong thing and leave out the text that carries the risk. Everyday rows give their first turn,
    the hard negatives: stress in strong words that must not trip the crisis head.
    """
    from therapylink_ml.data.loaders.authored import rows
    from therapylink_ml.train.reply_rules import crisis_turn

    out = []
    for r in rows(include_pending=include_pending):
        if r["route"] == "eve":
            labels = ["none"]
        else:
            labels = r.get("guardian_labels") or AUTHORED_CATEGORY_LABELS.get(r["category"])
            if not labels:
                raise ValueError(f"authored category {r['category']!r} ({r['id']}) has no crisis label; add it to AUTHORED_CATEGORY_LABELS")
        unknown = set(labels) - set(CRISIS_LABELS)
        if unknown:
            raise ValueError(f"{r['id']}: unknown crisis labels {sorted(unknown)}")
        if r["route"] == "eve":
            text = next(m["content"] for m in r["messages"] if m["role"] == "user")
        else:
            text = r["messages"][crisis_turn(r)]["content"]
        out.append(LabeledText(id=stable_id("tl_authored", "crisis", r["id"]), source="tl_authored", lang=r["lang"], text=text, task="crisis", labels=labels))
    return out


# A share of the authored examples goes to validation. Without it the val split is mh_text alone,
# so abuse, child, sexual_violence and the rest have no positives there and _calibrate leaves their
# thresholds at 0.5 instead of tuning them to the recall target.
AUTHORED_VAL_FRAC = 0.2


def split_authored(items: list[LabeledText], val_frac: float = AUTHORED_VAL_FRAC) -> tuple[list[LabeledText], list[LabeledText]]:
    """(train, val), split per label set so every set with two or more examples has one in val.

    Deterministic: items are ordered by their stable id, so train and calibrate hold out the same ones.
    """
    groups: dict[tuple[str, ...], list[LabeledText]] = {}
    for it in items:
        groups.setdefault(tuple(sorted(it.labels)), []).append(it)
    train, val = [], []
    for group in groups.values():
        group = sorted(group, key=lambda it: it.id)
        n_val = max(1, round(val_frac * len(group))) if len(group) >= 2 else 0
        val += group[:n_val]
        train += group[n_val:]
    return train, val


def authored_extras(with_authored: bool) -> tuple[dict[str, list[LabeledText]], dict[str, list[LabeledText]]]:
    """Extra (train, val) items per task from the authored rows; empty when turned off."""
    if not with_authored:
        return {}, {}
    train, val = split_authored(authored_crisis_texts())
    return {"crisis": train}, {"crisis": val}


# --- Held-out recall report ----------------------------------------------------------------------


def read_heldout(path: Path, tuning_probes: Path | None) -> list[dict]:
    """Held-out rows {id, text, lang, labels}; refuses any row that is one of the tuning probes.

    When thresholds are tuned against the 24 safety probes, a recall number measured on them is a
    number the tuning already saw. Guardian v1 tunes on its validation split instead and keeps the
    probes in its held-out set; pass `tuning_probes=None` for that.
    """
    probes = set()
    if tuning_probes is not None:
        probes = {json.loads(line)["text"].strip().lower() for line in tuning_probes.read_text(encoding="utf-8").splitlines() if line.strip()}
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    for r in rows:
        if r["text"].strip().lower() in probes:
            raise ValueError(f"held-out row {r['id']} is a tuning probe; the held-out set must be separate")
        unknown = set(r["labels"]) - set(CRISIS_LABELS)
        if unknown or not r["labels"]:
            raise ValueError(f"held-out row {r['id']}: labels must be from {CRISIS_LABELS}, got {r['labels']}")
    return rows


def recall_report(rows: list[dict], predicted: list[set[str]]) -> dict:
    """Recall per language and per category, and false alarms on the 'none' rows.

    `detect` counts a crisis row as caught when any crisis label fires (that is what routes the
    person to help); `exact` also needs its own label (that is what picks the right line).
    """

    def crisis_of(labels) -> set[str]:
        return set(labels) - {"none"}

    groups: dict[str, dict[str, list[int]]] = {}

    def add(group: str, detect: bool, exact: bool) -> None:
        g = groups.setdefault(group, {"n": [], "detect": [], "exact": []})
        g["n"].append(1)
        g["detect"].append(int(detect))
        g["exact"].append(int(exact))

    calm_by_lang: dict[str, list[int]] = {}
    for r, pred in zip(rows, predicted, strict=True):
        truth, fired = crisis_of(r["labels"]), crisis_of(pred)
        if not truth:
            calm_by_lang.setdefault(r["lang"], []).append(int(bool(fired)))
            continue
        add("all", bool(fired), truth <= fired)
        add(f"lang:{r['lang']}", bool(fired), truth <= fired)
        for label in truth:
            add(f"category:{label}", bool(fired), label in fired)

    def rate(xs: list[int]) -> float:
        return round(sum(xs) / len(xs), 3) if xs else 0.0

    return {
        "recall": {k: {"n": len(v["n"]), "detect": rate(v["detect"]), "exact": rate(v["exact"])} for k, v in sorted(groups.items())},
        "false_alarm": {lang: {"n": len(v), "rate": rate(v)} for lang, v in sorted(calm_by_lang.items())},
    }


def class_lang_report(rows: list[dict], predicted: list[set[str]], labels: tuple[str, ...] = CRISIS_LABELS) -> dict:
    """Recall and precision per crisis label within each language, and over all languages.

    Recall: of the rows carrying the label, the share the label fired on. Precision: of the rows the
    label fired on, the share that carry it. `detect_recall` counts a row caught when any crisis
    label fires, which is what puts the helpline in front of the person.
    """

    def crisis(labels_) -> set[str]:
        return set(labels_) - {"none"}

    out: dict[str, dict] = {}
    for lang in ["all", *sorted({r["lang"] for r in rows})]:
        idx = [i for i, r in enumerate(rows) if lang == "all" or r["lang"] == lang]
        per = {}
        for lab in labels:
            if lab == "none":
                continue
            pos = [i for i in idx if lab in rows[i]["labels"]]
            fired = [i for i in idx if lab in predicted[i]]
            tp = len(set(pos) & set(fired))
            per[lab] = {
                "n": len(pos),
                "recall": round(tp / len(pos), 3) if pos else None,
                "detect_recall": round(sum(1 for i in pos if crisis(predicted[i])) / len(pos), 3) if pos else None,
                "precision": round(tp / len(fired), 3) if fired else None,
                "fired": len(fired),
            }
        pos = [i for i in idx if crisis(rows[i]["labels"])]
        calm = [i for i in idx if not crisis(rows[i]["labels"])]
        flagged = [i for i in idx if crisis(predicted[i])]
        out[lang] = {
            "labels": per,
            "any_crisis": {
                "n": len(pos),
                "recall": round(sum(1 for i in pos if crisis(predicted[i])) / len(pos), 3) if pos else None,
                "precision": round(len(set(flagged) & set(pos)) / len(flagged), 3) if flagged else None,
                "n_calm": len(calm),
                "false_alarm_rate": round(sum(1 for i in calm if crisis(predicted[i])) / len(calm), 3) if calm else None,
            },
        }
    return out


def below(report: dict, min_recall: float) -> list[str]:
    """The groups whose detection recall falls short of `min_recall`."""
    return [f"{k} {v['detect']:.0%} (n={v['n']})" for k, v in report["recall"].items() if v["detect"] < min_recall]


def predicted_labels(probs, labels: list[str], thresholds: list[float] | None) -> set[str]:
    return {lab for j, lab in enumerate(labels) if probs[j] >= (thresholds[j] if thresholds and j < len(thresholds) else 0.5)}


def _read(path: Path) -> list[LabeledText]:
    if not path.exists():
        return []
    with path.open(encoding="utf-8") as f:
        return [LabeledText.model_validate_json(line) for line in f if line.strip()]


@dataclass
class TaskData:
    name: str
    labels: list[str]
    train: list[LabeledText]
    val: list[LabeledText]
    test: list[LabeledText]
    index: dict[str, int] = field(init=False)

    def __post_init__(self) -> None:
        self.index = {lab: i for i, lab in enumerate(self.labels)}

    @property
    def multi(self) -> bool:
        return self.name in MULTI_LABEL_TASKS

    @classmethod
    def load(
        cls,
        task: str,
        data_dir: Path = DATA,
        extra_train: list[LabeledText] | None = None,
        extra_val: list[LabeledText] | None = None,
    ) -> TaskData:
        splits = {s: _read(data_dir / f"labeled.{task}.{s}.jsonl") for s in ("train", "val", "test")}
        splits["train"] = splits["train"] + list(extra_train or [])
        splits["val"] = splits["val"] + list(extra_val or [])
        if not splits["train"]:
            raise FileNotFoundError(f"no training data for task {task!r} in {data_dir}")
        seen = {lab for items in splits.values() for it in items for lab in it.labels}
        if task != "crisis":
            return cls(task, sorted(seen), splits["train"], splits["val"], splits["test"])
        unknown = seen - set(CRISIS_LABELS)
        if unknown:
            raise ValueError(f"crisis labels {sorted(unknown)} are not in CRISIS_LABELS {CRISIS_LABELS}")
        untrained = set(CRISIS_LABELS) - {lab for it in splits["train"] for lab in it.labels}
        if untrained:
            console.print(f"[yellow]crisis labels with no training examples: {sorted(untrained)}; their outputs stay untrained")
        uncalibrated = set(CRISIS_LABELS) - {lab for it in splits["val"] for lab in it.labels}
        if uncalibrated:
            console.print(f"[yellow]crisis labels with no validation examples: {sorted(uncalibrated)}; their thresholds stay at 0.5")
        return cls(task, list(CRISIS_LABELS), splits["train"], splits["val"], splits["test"])

    def target(self, item: LabeledText) -> torch.Tensor:
        if self.multi:
            t = torch.zeros(len(self.labels))
            for lab in item.labels:
                t[self.index[lab]] = 1.0
            return t
        return torch.tensor(self.index[item.labels[0]])


class _Dataset(Dataset):
    def __init__(self, items: list[LabeledText], task: TaskData):
        self.items, self.task = items, task

    def __len__(self) -> int:
        return len(self.items)

    def __getitem__(self, i: int):
        return self.items[i].text, self.task.target(self.items[i])


def _collate(tokenizer, max_len: int):
    def fn(batch):
        texts, targets = zip(*batch, strict=True)
        enc = tokenizer(list(texts), truncation=True, max_length=max_len, padding=True, return_tensors="pt")
        return enc, torch.stack(list(targets))

    return fn


class GuardianModel(nn.Module):
    def __init__(self, base: str, task_sizes: dict[str, int], dropout: float = 0.1):
        super().__init__()
        self.encoder = AutoModel.from_pretrained(base)
        hidden = self.encoder.config.hidden_size
        self.heads = nn.ModuleDict(
            {t: nn.Sequential(nn.Dropout(dropout), nn.Linear(hidden, n)) for t, n in task_sizes.items()}
        )

    def encode(self, input_ids, attention_mask):
        return self.encoder(input_ids=input_ids, attention_mask=attention_mask).last_hidden_state[:, 0]

    def forward(self, task: str, input_ids, attention_mask):
        return self.heads[task](self.encode(input_ids, attention_mask))


@torch.no_grad()
def _predict(model, loader, task: str, device) -> tuple[np.ndarray, np.ndarray]:
    model.eval()
    logits, targets = [], []
    for enc, y in loader:
        enc = {k: v.to(device) for k, v in enc.items()}
        logits.append(model(task, **enc).float().cpu())
        targets.append(y)
    return torch.cat(logits).numpy(), torch.cat(targets).numpy()


def _calibrate(probs: np.ndarray, y: np.ndarray, target_recall: float | None) -> list[float]:
    """Per-class thresholds: hit `target_recall` when given, else maximise F1."""
    thresholds = []
    for c in range(probs.shape[1]):
        pos = probs[y[:, c] == 1, c]
        if len(pos) == 0:
            thresholds.append(0.5)
        elif target_recall is not None:
            thresholds.append(float(np.clip(np.quantile(pos, 1 - target_recall), 0.02, 0.98)))
        else:
            thresholds.append(_best_f1_threshold(probs[:, c], y[:, c]))
    return thresholds


def calibrate_by_lang(
    probs: np.ndarray, y: np.ndarray, langs: list[str], labels: list[str], target_recall: float = LANG_RECALL_TARGET,
    min_positives: int = MIN_LANG_POSITIVES,
) -> list[float]:
    """Per-label thresholds that reach `target_recall` on the positives of every language.

    A language with fewer than `min_positives` positives for a label does not set that label's
    threshold on its own (one row is not a recall estimate); the pooled positives still do. 'none'
    is not a crisis output and keeps 0.5.
    """
    langs_arr = np.asarray(langs)
    out = []
    for c, lab in enumerate(labels):
        pos_all = probs[y[:, c] == 1, c]
        if lab == "none" or len(pos_all) == 0:
            out.append(0.5)
            continue
        # method="lower" picks an observed score, so at least target_recall of the positives reach it.
        cands = [np.quantile(pos_all, 1 - target_recall, method="lower")]
        for lang in sorted(set(langs)):
            pos = probs[(y[:, c] == 1) & (langs_arr == lang), c]
            if len(pos) >= min_positives:
                cands.append(np.quantile(pos, 1 - target_recall, method="lower"))
        out.append(float(np.clip(min(cands), 0.02, 0.98)))
    return out


def pos_weights(items: list[LabeledText], labels: list[str], cap: float = 10.0) -> torch.Tensor:
    """BCE pos_weight per label: sqrt(negatives / positives), between 1 and `cap`.

    Rare crisis labels (medical, harm_to_others) would otherwise be learnt as 'never'; the square
    root keeps the push without turning every sad message into a crisis."""
    n = len(items)
    counts = {lab: 0 for lab in labels}
    for it in items:
        for lab in it.labels:
            counts[lab] += 1
    return torch.tensor([float(np.clip(np.sqrt((n - counts[lab]) / max(counts[lab], 1)), 1.0, cap)) for lab in labels])


def _best_f1_threshold(prob: np.ndarray, y: np.ndarray) -> float:
    candidates = np.unique(np.quantile(prob, np.linspace(0.01, 0.99, 99)))
    best_t, best_f1 = 0.5, -1.0
    for t in candidates:
        pred = prob >= t
        tp = float((pred & (y == 1)).sum())
        if tp == 0:
            continue
        f1 = 2 * tp / (pred.sum() + y.sum())
        if f1 > best_f1:
            best_t, best_f1 = float(t), f1
    return float(np.clip(best_t, 0.02, 0.98))


def _metrics(task: TaskData, logits: np.ndarray, y: np.ndarray, thresholds: list[float] | None) -> dict:
    if task.multi:
        probs = 1 / (1 + np.exp(-logits))
        thr = np.array(thresholds if thresholds else [0.5] * probs.shape[1])
        pred = (probs >= thr).astype(int)
        p, r, f, _ = precision_recall_fscore_support(y, pred, average=None, zero_division=0)
        return {
            "macro_f1": float(f1_score(y, pred, average="macro", zero_division=0)),
            "per_class": {lab: {"p": float(p[i]), "r": float(r[i]), "f1": float(f[i])} for i, lab in enumerate(task.labels)},
        }
    pred = logits.argmax(-1)
    p, r, f, _ = precision_recall_fscore_support(y, pred, average=None, zero_division=0, labels=range(len(task.labels)))
    return {
        "accuracy": float((pred == y).mean()),
        "macro_f1": float(f1_score(y, pred, average="macro", zero_division=0)),
        "per_class": {lab: {"p": float(p[i]), "r": float(r[i]), "f1": float(f[i])} for i, lab in enumerate(task.labels)},
    }


def _print_metrics(task: str, m: dict) -> None:
    table = Table(title=f"{task}  macro-F1 {m['macro_f1']:.3f}" + (f"  acc {m['accuracy']:.3f}" if "accuracy" in m else ""))
    for col in ("label", "P", "R", "F1"):
        table.add_column(col, justify="right" if col != "label" else "left")
    for lab, s in m["per_class"].items():
        table.add_row(lab, f"{s['p']:.2f}", f"{s['r']:.2f}", f"{s['f1']:.2f}")
    console.print(table)


@app.command()
def train(
    tasks: list[str] = typer.Option(["emotion"], "--task", help="Task names matching labeled.{task}.*.jsonl"),
    base: str = "FacebookAI/xlm-roberta-base",
    out: Path = ML_ROOT / "runs" / "guardian",
    data_dir: Path = DATA,
    epochs: int = 3,
    lr: float = 2e-5,
    batch: int = 16,
    max_len: int = 128,
    warmup: float = 0.06,
    seed: int = 13,
    grad_checkpointing: bool = False,
    freeze_embeddings: bool = typer.Option(True, help="XLM-R's 250k×768 embedding table is ~70% of its parameters; freezing it keeps AdamW state inside 4 GB"),
    limit: int = typer.Option(0, help="Debug: cap train items per task"),
    with_authored: bool = typer.Option(True, help="Add the authored rows to the crisis head's train and val data (Roman Urdu, abuse, child, sexual violence)"),
    class_weights: bool = typer.Option(True, help="BCE pos_weight per label (sqrt of negatives/positives, capped at 10)"),
    lang_recall: float = typer.Option(0.0, help="If > 0, calibrate the crisis thresholds per language to this recall on validation (Guardian v1 uses 0.98)"),
) -> None:
    random.seed(seed)
    torch.manual_seed(seed)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    console.print(f"device: {device}  base: {base}  tasks: {tasks}")

    extra_train, extra_val = authored_extras(with_authored)
    task_data = {t: TaskData.load(t, data_dir, extra_train.get(t), extra_val.get(t)) for t in tasks}
    if limit:
        for td in task_data.values():
            td.train = td.train[:limit]
    tokenizer = AutoTokenizer.from_pretrained(base)
    model = GuardianModel(base, {t: len(td.labels) for t, td in task_data.items()}).to(device)
    if grad_checkpointing:
        model.encoder.gradient_checkpointing_enable()
    if freeze_embeddings:
        for p in model.encoder.embeddings.parameters():
            p.requires_grad = False
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    console.print(f"trainable params: {trainable / 1e6:.1f}M")

    collate = _collate(tokenizer, max_len)
    loaders = {
        t: DataLoader(_Dataset(td.train, td), batch_size=batch, shuffle=True, collate_fn=collate)
        for t, td in task_data.items()
    }
    val_loaders = {
        t: DataLoader(_Dataset(td.val, td), batch_size=batch * 2, collate_fn=collate)
        for t, td in task_data.items()
        if td.val
    }
    losses = {
        t: (nn.BCEWithLogitsLoss(pos_weight=pos_weights(td.train, td.labels).to(device) if class_weights else None) if td.multi else nn.CrossEntropyLoss())
        for t, td in task_data.items()
    }
    for t, td in task_data.items():
        if td.multi and class_weights:
            console.print(f"{t} pos_weight: " + ", ".join(f"{lab}={w:.2f}" for lab, w in zip(td.labels, losses[t].pos_weight.tolist(), strict=True)))

    steps_per_epoch = sum(len(ld) for ld in loaders.values())
    total = steps_per_epoch * epochs
    optim = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=lr, weight_decay=0.01)
    sched = get_cosine_schedule_with_warmup(optim, int(total * warmup), total)
    scaler = torch.amp.GradScaler(enabled=device.type == "cuda")

    best, out = -1.0, Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for epoch in range(epochs):
        model.train()
        schedule = [t for t, ld in loaders.items() for _ in range(len(ld))]
        random.shuffle(schedule)
        iters = {t: iter(ld) for t, ld in loaders.items()}
        running = 0.0
        for step, t in enumerate(schedule, 1):
            enc, y = next(iters[t])
            enc = {k: v.to(device) for k, v in enc.items()}
            y = y.to(device)
            with torch.autocast(device_type=device.type, dtype=torch.float16, enabled=device.type == "cuda"):
                loss = losses[t](model(t, **enc), y)
            optim.zero_grad(set_to_none=True)
            scaler.scale(loss).backward()
            scaler.unscale_(optim)
            nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            scaler.step(optim)
            scaler.update()
            sched.step()
            running += loss.item()
            if step % 50 == 0:
                console.print(f"epoch {epoch + 1} step {step}/{steps_per_epoch} loss {running / 50:.4f}")
                running = 0.0

        results, thresholds = {}, {}
        for t, ld in val_loaders.items():
            logits, y = _predict(model, ld, t, device)
            if t == "crisis" and lang_recall > 0:
                thresholds[t] = calibrate_by_lang(1 / (1 + np.exp(-logits)), y, [it.lang for it in task_data[t].val], task_data[t].labels, lang_recall)
            elif task_data[t].multi:
                thresholds[t] = _calibrate(1 / (1 + np.exp(-logits)), y, RECALL_TARGETS.get(t))
            results[t] = _metrics(task_data[t], logits, y, thresholds.get(t))
            _print_metrics(t, results[t])
        score = float(np.mean([m["macro_f1"] for m in results.values()])) if results else 0.0
        if score > best:
            best = score
            torch.save(model.state_dict(), out / "model.pt")
            tokenizer.save_pretrained(out)
            (out / "config.json").write_text(
                json.dumps(
                    {"base": base, "max_len": max_len, "tasks": {t: td.labels for t, td in task_data.items()},
                     "multi_label": sorted(MULTI_LABEL_TASKS & set(tasks)), "with_authored": with_authored,
                     "class_weights": class_weights, "lang_recall": lang_recall},
                    indent=2,
                ),
                encoding="utf-8",
            )
            (out / "thresholds.json").write_text(json.dumps(thresholds, indent=2), encoding="utf-8")
            (out / "metrics.json").write_text(json.dumps({"epoch": epoch + 1, "val": results}, indent=2), encoding="utf-8")
            console.print(f"[green]saved[/] {out} (mean macro-F1 {score:.3f})")


@app.command()
def calibrate(
    run: Path = ML_ROOT / "runs" / "guardian",
    data_dir: Path = DATA,
    split: str = typer.Option("val", help="val (tune thresholds) or test (final report)"),
    batch: int = 32,
) -> None:
    """Re-derive thresholds and metrics from a saved checkpoint. No training."""
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    cfg = json.loads((run / "config.json").read_text(encoding="utf-8"))
    # Same authored val items as training held out, so re-calibrating doesn't drop them. Runs from
    # before the key was saved trained with the authored rows (the default then too).
    extra_train, extra_val = authored_extras(cfg.get("with_authored", True))
    tasks = {t: TaskData.load(t, data_dir, extra_train.get(t), extra_val.get(t)) for t in cfg["tasks"]}
    model = GuardianModel(cfg["base"], {t: len(labs) for t, labs in cfg["tasks"].items()}).to(device)
    model.load_state_dict(torch.load(run / "model.pt", map_location=device))
    tokenizer = AutoTokenizer.from_pretrained(run)
    collate = _collate(tokenizer, cfg["max_len"])

    # Thresholds are tuned on val and only ever applied to test. Re-tuning them on test would
    # leak the answer into the number we report.
    thresholds: dict[str, list[float]] = {}
    if split == "test":
        path = run / "thresholds.json"
        if not path.exists():
            raise typer.BadParameter(f"{path} not found — run `calibrate --split val` first")
        thresholds = json.loads(path.read_text(encoding="utf-8"))
        console.print("[dim]using thresholds tuned on the validation split")

    results = {}
    for t, td in tasks.items():
        items = {"val": td.val, "test": td.test}[split]
        if not items:
            continue
        loader = DataLoader(_Dataset(items, td), batch_size=batch, collate_fn=collate)
        logits, y = _predict(model, loader, t, device)
        if td.multi and split == "val":
            thresholds[t] = _calibrate(1 / (1 + np.exp(-logits)), y, RECALL_TARGETS.get(t))
        results[t] = _metrics(td, logits, y, thresholds.get(t))
        _print_metrics(t, results[t])

    if split == "val":
        (run / "thresholds.json").write_text(json.dumps(thresholds, indent=2), encoding="utf-8")
    (run / f"metrics.{split}.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    console.print(f"[green]wrote[/] {run / f'metrics.{split}.json'}")


@app.command()
def probe(
    run: Path = ML_ROOT / "runs" / "guardian",
    probes: Path = ML_ROOT / "therapylink_ml" / "eval" / "probes" / "safety.jsonl",
    batch: int = 16,
    baseline: bool = typer.Option(True, help="Also score the app's keyword fallback, so a model that is worse than shipping nothing is visible"),
) -> None:
    """Run Guardian over the hand-written safety probes — the job it actually has in the app.

    The corpus test split measures it on Reddit posts; this measures it on the crisis phrasings,
    Roman Urdu and code-switching it will really meet, which is the number worth reporting.
    """
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    cfg = json.loads((run / "config.json").read_text(encoding="utf-8"))
    if "crisis" not in cfg["tasks"]:
        raise typer.BadParameter(f"{run} has no crisis head")
    labels = cfg["tasks"]["crisis"]
    thresholds = json.loads((run / "thresholds.json").read_text(encoding="utf-8")).get("crisis")

    model = GuardianModel(cfg["base"], {t: len(v) for t, v in cfg["tasks"].items()}).to(device)
    model.load_state_dict(torch.load(run / "model.pt", map_location=device))
    model.eval()
    tokenizer = AutoTokenizer.from_pretrained(run)

    rows = [json.loads(line) for line in probes.read_text(encoding="utf-8").splitlines() if line.strip()]
    texts = [r["text"] for r in rows]
    flags: list[bool] = []
    for i in range(0, len(texts), batch):
        chunk = texts[i : i + batch]
        enc = tokenizer(chunk, truncation=True, max_length=cfg["max_len"], padding=True, return_tensors="pt").to(device)
        with torch.no_grad():
            probs = torch.sigmoid(model("crisis", **enc)).float().cpu().numpy()
        for p in probs:
            flags.append(bool(predicted_labels(p, labels, thresholds) - {"none"}))

    def score(fl: list[bool]) -> dict:
        crisis = [(r, f) for r, f in zip(rows, fl, strict=True) if r["route"] == "crisis"]
        calm = [(r, f) for r, f in zip(rows, fl, strict=True) if r["route"] != "crisis"]
        return {
            "crisis": crisis,
            "calm": calm,
            "recall": sum(f for _, f in crisis) / len(crisis),
            "false_alarm": sum(f for _, f in calm) / len(calm),
            "by_lang": {
                lang: sum(f for r, f in crisis if r["lang"] == lang) / sum(1 for r, _ in crisis if r["lang"] == lang)
                for lang in sorted({r["lang"] for r, _ in crisis})
            },
        }

    model_s = score(flags)
    base_s = score([_keyword_crisis(t) for t in texts]) if baseline else None
    crisis, calm = model_s["crisis"], model_s["calm"]

    table = Table(title=f"Crisis detection on {len(rows)} hand-written probes")
    table.add_column("group")
    table.add_column("n", justify="right")
    table.add_column("model", justify="right")
    if base_s:
        table.add_column("keyword fallback", justify="right")

    def row(label: str, n: int, a: float, b: float | None) -> None:
        cells = [label, str(n), f"{a:.0%}"]
        if b is not None:
            cells.append(f"{b:.0%}")
        table.add_row(*cells)

    row("crisis caught", len(crisis), model_s["recall"], base_s["recall"] if base_s else None)
    row("false alarms", len(calm), model_s["false_alarm"], base_s["false_alarm"] if base_s else None)
    for lang, v in model_s["by_lang"].items():
        n = sum(1 for r, _ in crisis if r["lang"] == lang)
        row(f"  caught · {lang}", n, v, base_s["by_lang"].get(lang) if base_s else None)
    console.print(table)
    if base_s and base_s["recall"] > model_s["recall"]:
        console.print(
            "[bold yellow]The keyword fallback catches more than the model. Shipping this "
            "checkpoint would make the app less safe, not more.[/]"
        )

    missed = [r["text"] for r, f in crisis if not f]
    if missed:
        console.print("\n[bold]missed:[/]")
        for m in missed:
            console.print(f"  · {m[:100]}", highlight=False)

    out = run / "probe_results.json"
    payload = {
        "probes": len(rows),
        "model": {
            "crisis_recall": round(model_s["recall"], 3),
            "false_alarm_rate": round(model_s["false_alarm"], 3),
            "by_lang": {k: round(v, 3) for k, v in model_s["by_lang"].items()},
        },
        "missed": missed,
    }
    if base_s:
        payload["keyword_baseline"] = {
            "crisis_recall": round(base_s["recall"], 3),
            "false_alarm_rate": round(base_s["false_alarm"], 3),
            "by_lang": {k: round(v, 3) for k, v in base_s["by_lang"].items()},
        }
    out.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    console.print(f"\n[green]wrote[/] {out}")


@app.command()
def heldout(
    file: Path = typer.Argument(..., help="Held-out JSONL {id, text, lang, labels}, written by a clinician and never used for tuning"),
    run: Path = ML_ROOT / "runs" / "guardian",
    tuning_probes: Path = ML_ROOT / "therapylink_ml" / "eval" / "probes" / "safety.jsonl",
    probes_in_heldout: bool = typer.Option(False, help="The safety probes are part of the held-out set (thresholds were tuned on validation, not on them)"),
    batch: int = 16,
    min_recall: float = typer.Option(0.95, help="Fail unless every language and category reaches this detection recall"),
) -> None:
    """Recall per language and per category on a held-out set: the number that decides whether v1 ships.

    Reported for the model alone, the keyword floor alone, and both together (what the app runs:
    the model with the keywords underneath). The gate applies to the union.
    """
    rows = read_heldout(file, None if probes_in_heldout else tuning_probes)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    cfg = json.loads((run / "config.json").read_text(encoding="utf-8"))
    if "crisis" not in cfg["tasks"]:
        raise typer.BadParameter(f"{run} has no crisis head")
    labels = cfg["tasks"]["crisis"]
    thresholds = json.loads((run / "thresholds.json").read_text(encoding="utf-8")).get("crisis")
    model = GuardianModel(cfg["base"], {t: len(v) for t, v in cfg["tasks"].items()}).to(device)
    model.load_state_dict(torch.load(run / "model.pt", map_location=device))
    model.eval()
    tokenizer = AutoTokenizer.from_pretrained(run)

    model_pred: list[set[str]] = []
    for i in range(0, len(rows), batch):
        chunk = [r["text"] for r in rows[i : i + batch]]
        enc = tokenizer(chunk, truncation=True, max_length=cfg["max_len"], padding=True, return_tensors="pt").to(device)
        with torch.no_grad():
            probs = torch.sigmoid(model("crisis", **enc)).float().cpu().numpy()
        model_pred.extend(predicted_labels(p, labels, thresholds) for p in probs)
    keyword_pred = [{k} if (k := keyword_kind(r["text"])) else set() for r in rows]
    union_pred = [m | k for m, k in zip(model_pred, keyword_pred, strict=True)]

    reports = {name: recall_report(rows, pred) for name, pred in (("model", model_pred), ("keywords", keyword_pred), ("union", union_pred))}
    table = Table(title=f"Guardian recall on {len(rows)} held-out rows ({file.name})")
    for col in ("group", "n", "model", "keywords", "model+keywords", "right label"):
        table.add_column(col, justify="left" if col == "group" else "right")
    for group, v in reports["union"]["recall"].items():
        table.add_row(
            group, str(v["n"]), f"{reports['model']['recall'][group]['detect']:.0%}", f"{reports['keywords']['recall'][group]['detect']:.0%}",
            f"{v['detect']:.0%}", f"{v['exact']:.0%}",
        )
    for lang, v in reports["union"]["false_alarm"].items():
        table.add_row(f"false alarms · {lang}", str(v["n"]), f"{reports['model']['false_alarm'][lang]['rate']:.0%}", f"{reports['keywords']['false_alarm'][lang]['rate']:.0%}", f"{v['rate']:.0%}", "")
    console.print(table)
    short = below(reports["union"], min_recall)
    out = run / "heldout_report.json"
    by_class = {name: class_lang_report(rows, pred) for name, pred in (("model", model_pred), ("keywords", keyword_pred), ("union", union_pred))}
    out.write_text(json.dumps({"file": str(file), "rows": len(rows), "min_recall": min_recall, "below": short, **reports, "by_class_lang": by_class}, indent=2), encoding="utf-8")
    console.print(f"[green]wrote[/] {out}")
    if short:
        console.print(f"[bold red]below {min_recall:.0%}:[/] " + "; ".join(short))
        raise SystemExit(1)


@app.command("export-onnx")
def export_onnx(run: Path = ML_ROOT / "runs" / "guardian", opset: int = 17, quantize: bool = True) -> None:
    """Export encoder + all heads to ONNX; optionally add a dynamic-int8 copy (~4× smaller) for the phone."""
    cfg = json.loads((run / "config.json").read_text(encoding="utf-8"))
    model = GuardianModel(cfg["base"], {t: len(labs) for t, labs in cfg["tasks"].items()})
    model.load_state_dict(torch.load(run / "model.pt", map_location="cpu"))
    model.eval()
    tasks = list(cfg["tasks"])

    class AllHeads(nn.Module):
        def __init__(self, m):
            super().__init__()
            self.m = m

        def forward(self, input_ids, attention_mask):
            h = self.m.encode(input_ids, attention_mask)
            return tuple(self.m.heads[t](h) for t in tasks)

    tokenizer = AutoTokenizer.from_pretrained(run)
    enc = tokenizer(["hello"], return_tensors="pt")
    torch.onnx.export(
        AllHeads(model),
        (enc["input_ids"], enc["attention_mask"]),
        str(run / "guardian.onnx"),
        input_names=["input_ids", "attention_mask"],
        output_names=[f"{t}_logits" for t in tasks],
        dynamic_axes={"input_ids": {0: "b", 1: "s"}, "attention_mask": {0: "b", 1: "s"},
                      **{f"{t}_logits": {0: "b"} for t in tasks}},
        opset_version=opset,
        dynamo=False,
    )
    console.print(f"[green]wrote[/] {run / 'guardian.onnx'}")
    if quantize:
        from onnxruntime.quantization import QuantType, quantize_dynamic

        quantize_dynamic(str(run / "guardian.onnx"), str(run / "guardian.int8.onnx"), weight_type=QuantType.QInt8)
        size_mb = (run / "guardian.int8.onnx").stat().st_size // (1 << 20)
        console.print(f"[green]wrote[/] {run / 'guardian.int8.onnx'} ({size_mb} MB)")


if __name__ == "__main__":
    app()
