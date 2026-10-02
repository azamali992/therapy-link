"""Unrelated memory notes attached to training conversations.

Served with notes it was never trained on, v14 answered the notes instead of the person: "what's
the most painless way to do it" got advice about talking to a manager, a disclosure of abuse got
exam tips; safety fell 18/24 -> 11/24 (runs/eval/sft-v14-notes). A model that only ever sees notes
that fit the conversation learns that notes are the topic. Attaching notes that have nothing to do
with the message, above all to crisis conversations, teaches the opposite: remembered context is
background, and what the person says now comes first.

The pool is templated (names, cities, times, jobs), about 300 memories and 60 summaries, so the
model learns the rule rather than learning to ignore a couple of dozen fixed strings. It includes
risk-bearing memories (an earlier self-harm disclosure, a hopeless night). Those go only on crisis
conversations, whose replies handle the risk in front of them anyway: an everyday reply in the
corpus never checks in on a remembered risk, and attaching one there would teach the model to
ignore it. The gentle check-in itself has to come from authored rows with related notes.
"""

from __future__ import annotations

import itertools
import random

from therapylink_ml.prompts import MEMORY_HEADER, SUMMARY_HEADER

NAMES = ["Ayesha", "Bilal", "Sana", "Hamza", "Zara", "Omar", "Hira", "Usman", "Mahnoor", "Fahad", "Iqra", "Danish"]
CITIES = ["Lahore", "Karachi", "Islamabad", "Multan", "Peshawar", "Faisalabad", "Quetta", "Hyderabad", "Sialkot"]
RELATIVES_EN = ["Mother", "Father", "Younger brother", "Older sister", "Grandmother", "An uncle", "A cousin"]
RELATIVES_UR = ["Ammi", "Abbu", "Chhota bhai", "Bari behen", "Nani", "Chacha", "Khala"]
AGO_EN = ["last week", "two weeks ago", "last month", "in the spring", "a few days ago"]
AGO_UR = ["pichle hafte", "do hafte pehle", "pichle mahine", "kuch din pehle"]
MONTHS = ["March", "May", "August", "November", "December"]

_TEMPLATES_EN: list[tuple[str, dict[str, list[str]]]] = [
    ("Works as {job} and often {habit}", {
        "job": ["an accountant", "a nurse", "a teacher", "a software developer", "a shop manager", "a call-centre agent", "a pharmacist"],
        "habit": ["stays late", "works weekends", "skips lunch", "takes calls at night"],
    }),
    ("{relative} lives with them in {city}", {"relative": RELATIVES_EN, "city": CITIES}),
    ("{relative} has been unwell for {span}", {"relative": RELATIVES_EN, "span": ["weeks", "months", "most of the year"]}),
    ("Has {exam} in {month} and gets anxious at night", {"exam": ["board exams", "a licensing exam", "university finals", "an entry test"], "month": MONTHS}),
    ("{friend} is the friend they trust most", {"friend": NAMES}),
    ("Fell out with {friend} {ago} and has not spoken since", {"friend": NAMES, "ago": AGO_EN}),
    ("Moved to {city} {ago} for work", {"city": CITIES, "ago": AGO_EN}),
    ("{coping} helped them {ago}", {"coping": ["Paced breathing", "A walk after dinner", "Writing worries down", "Talking to a friend", "Grounding with 5-4-3-2-1"], "ago": AGO_EN}),
    ("Wants to {goal}", {"goal": ["sleep before midnight", "argue less at home", "spend less time on the phone at night", "start exercising again", "save for a course", "call their parents more often"]}),
    ("Planned to {plan} this week", {"plan": ["ask their manager about a deadline", "visit a relative", "try a morning walk", "finish a job application", "talk to a friend about money"]}),
    ("Has a {pet} called {pet_name}", {"pet": ["cat", "dog", "parrot"], "pet_name": ["Biscuit", "Moti", "Sheru", "Mithu", "Coco"]}),
    ("Started {thing} {ago}", {"thing": ["a new job", "a night shift", "university", "an online course", "working from home"], "ago": AGO_EN}),
    ("Feels judged by relatives about {topic}", {"topic": ["marriage", "their career", "their weight", "money"]}),
    ("Plays {sport} with friends on {day}", {"sport": ["cricket", "football", "badminton"], "day": ["Sundays", "Fridays", "weekends"]}),
]

_TEMPLATES_UR: list[tuple[str, dict[str, list[str]]]] = [
    ("{relative} ki tabiyat {span} se kharab hai", {"relative": RELATIVES_UR, "span": ["kaafi dino", "kuch hafton", "mahino"]}),
    ("{relative} saath {city} mein rehte hain", {"relative": RELATIVES_UR, "city": CITIES}),
    ("{thing} se ghabrahat hoti hai", {"thing": ["University presentation", "Exam", "Interview", "Shaadi ki baat", "Office meeting"]}),
    ("{friend} se sab se zyada baat hoti hai", {"friend": NAMES}),
    ("{friend} se {ago} jhagra hua tha", {"friend": NAMES, "ago": AGO_UR}),
    ("{ago} {city} shift hue kaam ke liye", {"ago": AGO_UR, "city": CITIES}),
    ("{coping} se {ago} farq para tha", {"coping": ["Saans wali exercise", "Shaam ki walk", "Pareshaniyan kaaghaz par likhne", "Dost se baat karne"], "ago": AGO_UR}),
    ("Raat ko der tak {thing}", {"thing": ["phone chalate hain", "kaam karte hain", "jaagte hain"]}),
    ("{goal} ka plan banaya tha", {"goal": ["Sone se pehle walk", "Subah jaldi uthne", "Phone kam chalane", "Naukri ki application bhejne"]}),
    ("Naukri {state}", {"state": ["dhoond rahe hain", "badalna chahte hain", "mein pressure zyada hai"]}),
]

# Risk-bearing memories: crisis conversations only (see the module docstring).
_RISK_EN: list[tuple[str, dict[str, list[str]]]] = [
    ("Mentioned thoughts of self-harm {ago}", {"ago": AGO_EN}),
    ("Said {ago} that some nights they did not want to be here", {"ago": AGO_EN}),
    ("Had a very hopeless week {ago} and talked about it here", {"ago": AGO_EN}),
    ("Told Eve {ago} that they had hurt themselves before", {"ago": AGO_EN}),
]
_RISK_UR: list[tuple[str, dict[str, list[str]]]] = [
    ("{ago} khud ko nuqsan pohanchane ke khayalon ka zikr kiya tha", {"ago": AGO_UR}),
    ("{ago} kaha tha ke kabhi kabhi jeene ka dil nahi karta", {"ago": AGO_UR}),
]

_SUMMARIES_EN: list[tuple[str, dict[str, list[str]]]] = [
    ("They talked about {topic} and not sleeping well this week.", {"topic": ["work piling up", "exam pressure", "a family argument", "money worries", "a new job"]}),
    ("They said they argued with {friend} and have not spoken since.", {"friend": NAMES}),
    ("They described feeling behind at {place} compared to everyone else.", {"place": ["university", "work", "school", "home"]}),
    ("They mentioned {thing} after {event}.", {"thing": ["money being tight", "feeling drained", "trouble focusing"], "event": ["an unexpected car repair", "a hospital visit", "a wedding", "moving house"]}),
    ("They said {relative} had been unwell and most of the looking after fell to them.", {"relative": ["their mother", "their father", "their younger brother", "their older sister", "their grandmother", "an uncle", "a cousin"]}),
]
_SUMMARIES_UR: list[tuple[str, dict[str, list[str]]]] = [
    ("Unhon ne bataya ke is hafte {topic} aur neend poori nahi hui.", {"topic": ["kaam bohat zyada tha", "exam ka pressure tha", "ghar mein jhagra hua", "paison ki fikar thi"]}),
    ("Unhon ne kaha ke {friend} se jhagra hua aur tab se baat nahi hui.", {"friend": NAMES}),
    ("Unhon ne bataya ke {relative} ki tabiyat ki wajah se ghar ki zimmedari un par hai.", {"relative": RELATIVES_UR}),
]


def _expand(templates: list[tuple[str, dict[str, list[str]]]], per_template: int, seed: int) -> list[str]:
    """Up to `per_template` filled variants of each template, deterministic and de-duplicated."""
    rng = random.Random(seed)
    out: list[str] = []
    for template, slots in templates:
        keys = list(slots)
        combos = [dict(zip(keys, values, strict=True)) for values in itertools.product(*(slots[k] for k in keys))]
        out.extend(template.format(**c) for c in rng.sample(combos, min(per_template, len(combos))))
    return list(dict.fromkeys(out))


MEMORIES_EN = _expand(_TEMPLATES_EN, 18, seed=1)
MEMORIES_UR = _expand(_TEMPLATES_UR, 14, seed=2)
RISK_MEMORIES_EN = _expand(_RISK_EN, 5, seed=3)
RISK_MEMORIES_UR = _expand(_RISK_UR, 4, seed=4)
SUMMARIES_EN = _expand(_SUMMARIES_EN, 14, seed=5)
SUMMARIES_UR = _expand(_SUMMARIES_UR, 14, seed=6)


def sample_notes(rng: random.Random, lang: str = "en", allow_risk: bool = False) -> str:
    """One notes block in the app's exact layout: 1-5 memories, sometimes a summary.

    With `allow_risk`, one memory in three blocks is a risk-bearing one.
    """
    if lang == "ur-roman":
        memories, risk, summaries = MEMORIES_UR, RISK_MEMORIES_UR, SUMMARIES_UR
    elif lang == "en":
        memories, risk, summaries = MEMORIES_EN, RISK_MEMORIES_EN, SUMMARIES_EN
    else:
        memories, risk, summaries = MEMORIES_EN + MEMORIES_UR, RISK_MEMORIES_EN + RISK_MEMORIES_UR, SUMMARIES_EN + SUMMARIES_UR
    parts = []
    if rng.random() < 0.85:
        lines = rng.sample(memories, k=rng.randint(1, 5))
        if allow_risk and rng.random() < 1 / 3:
            lines[rng.randrange(len(lines))] = rng.choice(risk)
        parts.append(MEMORY_HEADER + "\n" + "\n".join(f"- {m}" for m in lines))
    if not parts or rng.random() < 0.4:
        parts.append(SUMMARY_HEADER + "\n" + rng.choice(summaries))
    return "\n\n".join(parts)


def pool_size() -> dict[str, int]:
    return {
        "memories": len(MEMORIES_EN) + len(MEMORIES_UR),
        "risk_memories": len(RISK_MEMORIES_EN) + len(RISK_MEMORIES_UR),
        "summaries": len(SUMMARIES_EN) + len(SUMMARIES_UR),
    }
