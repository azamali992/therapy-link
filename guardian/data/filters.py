"""Row filters applied before any built file exists, so nobody opens a file that still has these rows.

Three filters, each returning (kept_rows, removed_count). Rows are dropped in memory; only counts are kept.

1. religious: any mention of a religion, sect, scripture or religious figure, in English, Roman Urdu or
   Urdu script, or a source category naming religion or blasphemy. This project ships no religious-hate
   detector, so no religious text goes into training or evaluation.
2. minors: sexual content involving minors (source category "Sexual (minor)" or child + sexual words).
3. first_person_self_harm: a person disclosing their own suicidal thoughts or self-harm. Third-person and
   instructional self-harm content stays (it is what the self_harm label describes).

Keyword lists are deliberately broad. A broad filter loses some benign rows; a narrow one leaks what we
said we removed.
"""

from __future__ import annotations

import re

RELIGION_WORDS = [
    # English
    r"islam", r"muslim", r"quran", r"koran", r"hadith", r"prophet", r"muhammad", r"mohammed", r"allah",
    r"mosque", r"masjid", r"imam", r"mullah", r"maulvi", r"sunni", r"shia", r"shi'?ite", r"ahmadi", r"qadiani",
    r"wahhabi", r"deobandi", r"barelvi", r"salafi", r"sufi", r"jihad", r"sharia", r"fatwa", r"blasphem",
    r"christian", r"christ\b", r"jesus", r"bible", r"church", r"pastor", r"priest", r"catholic", r"protestant",
    r"hindu", r"hinduism", r"temple", r"mandir", r"brahmin", r"krishna", r"shiva", r"vishnu", r"ganesh",
    r"\bram\b", r"ramayan", r"gita", r"\bvedas?\b", r"sikh", r"gurdwara", r"guru nanak", r"granth",
    r"jew", r"judaism", r"torah", r"synagogue", r"rabbi", r"zionis", r"buddhis", r"buddha", r"atheis",
    r"god\b", r"gods\b", r"religio", r"scripture", r"holy", r"heaven", r"hell\b", r"satan", r"devil",
    r"infidel", r"kafir", r"kaffir", r"heretic", r"apostat", r"pagan", r"cult\b",
    # Roman Urdu
    r"\bkhuda\b", r"\brab\b", r"\bnamaz\b", r"\broza\b", r"ramzan", r"ramadan", r"\beid\b", r"\bhajj\b", r"umrah",
    r"\bmolvi\b", r"\bmaulana\b", r"\bmadrasa", r"\bmadrassa", r"\bazan\b", r"\bdua\b", r"\bduaa\b", r"\bmazhab",
    r"\bdeen\b", r"\bdin-e", r"\bkalma", r"\bmasjid", r"\bpeer\b", r"\bdargah", r"\bmazar\b", r"\bfirqa",
    r"\bmomin", r"\bkafir", r"\bmushrik", r"\bbidat", r"\bnabi\b", r"\brasool", r"\bsahaba", r"\bhuzoor",
    r"\bmolana", r"\bmandir\b", r"\bgurdwara", r"\bgirja", r"\bisai\b", r"\bisaai", r"\bhindu", r"\byahood",
    # Urdu script
    r"اسلام", r"مسلم", r"مسلمان", r"قرآن", r"قران", r"حدیث", r"نبی", r"رسول", r"محمد", r"اللہ", r"الله", r"خدا",
    r"مسجد", r"امام", r"مولوی", r"مولانا", r"ملا\b", r"سنی", r"شیعہ", r"شیعی", r"احمدی", r"قادیانی", r"وہابی",
    r"دیوبندی", r"بریلوی", r"صوفی", r"جہاد", r"شریعت", r"فتویٰ", r"فتوی", r"توہین", r"گستاخ", r"کافر", r"مشرک",
    r"عیسائی", r"مسیح", r"بائبل", r"انجیل", r"گرجا", r"کلیسا", r"پادری", r"ہندو", r"مندر", r"برہمن", r"سکھ",
    r"گردوارہ", r"یہودی", r"یہود", r"تورات", r"بدھ", r"ملحد", r"مذہب", r"مذہبی", r"دین\b", r"دینی", r"نماز",
    r"روزہ", r"رمضان", r"عید", r"حج\b", r"عمرہ", r"اذان", r"دعا\b", r"کلمہ", r"جنت", r"جہنم", r"دوزخ",
    r"شیطان", r"فرشت", r"پیر\b", r"درگاہ", r"مزار", r"فرقہ", r"مومن", r"صحابہ", r"حضور", r"بدعت",
]
RELIGION_CATEGORY = re.compile(r"relig|blasphem|communal", re.I)

MINOR_WORDS = r"(child|children|kid|kids|minor|minors|underage|under-age|teen|teenage|preteen|toddler|infant|baby|boy|girl|schoolgirl|schoolboy|student|bacha|bachi|bachay|bachon|bachchi|larka|larki|ladka|ladki|بچہ|بچی|بچے|بچوں|لڑکا|لڑکی|نابالغ|کم عمر)"
SEXUAL_WORDS = r"(sex|sexual|sexy|nude|naked|porn|rape|molest|fuck|genital|penis|vagina|breast|orgasm|masturbat|touch(ing)? (him|her|them)|undress|jinsi|zyadati|zabardasti|جنسی|زیادتی|زبردستی|ننگ|فحش|عریان)"
MINOR_SEXUAL = re.compile(rf"{MINOR_WORDS}.{{0,80}}{SEXUAL_WORDS}|{SEXUAL_WORDS}.{{0,80}}{MINOR_WORDS}", re.I | re.S)
MINOR_CATEGORY = re.compile(r"sexual.?\(?minor|child sexual|csam", re.I)

FIRST_PERSON_SELF_HARM = re.compile(
    r"\b(i|i'm|im|i am|i've|i have|i want|i wanna|i wish|i feel|i think|i'm going|i will|i'll|me|myself|main|mein|mai|mujhe|mujhay|mjhe|muje|khud|apne aap|میں|مجھے|خود|اپنے آپ)\b"
    r".{0,60}"
    r"(kill myself|killing myself|end my life|end it all|take my (own )?life|want to die|wanna die|wish i was dead|better off dead|"
    r"not (want to|wanna) (live|be alive|exist)|suicid|self.?harm|hurt myself|cut(ting)? myself|cut myself|hang myself|overdos|"
    r"unalive|kms\b|khudkushi|khud ?kushi|marna chaht|mar jaa?(u|un|on|oon|na)|jaan de|zindagi khatam|jeena nahi|"
    r"خودکشی|خود کشی|مرنا چاہت|مر جا|جان دے|زندگی ختم|جینا نہیں|اپنے آپ کو (نقصان|ختم|مار))",
    re.I | re.S,
)
SELF_HARM_CATEGORY = re.compile(r"suicide|self.?harm", re.I)

_RELIGION = re.compile("|".join(RELIGION_WORDS), re.I)


def _texts(row: dict) -> str:
    return " ".join(str(row.get(k) or "") for k in ("text", "prompt", "response"))


def _category(row: dict) -> str:
    return str(row.get("original_label") or row.get("provenance", {}).get("original_label") or row.get("violated_categories") or "")


def religious(rows: list[dict]) -> tuple[list[dict], int]:
    kept = [r for r in rows if not (_RELIGION.search(_texts(r)) or RELIGION_CATEGORY.search(_category(r)))]
    return kept, len(rows) - len(kept)


def minors(rows: list[dict]) -> tuple[list[dict], int]:
    kept = [r for r in rows if not (MINOR_CATEGORY.search(_category(r)) or MINOR_SEXUAL.search(_texts(r)))]
    return kept, len(rows) - len(kept)


def first_person_self_harm(rows: list[dict]) -> tuple[list[dict], int]:
    kept = [r for r in rows if not (SELF_HARM_CATEGORY.search(_category(r)) and FIRST_PERSON_SELF_HARM.search(_texts(r)))]
    return kept, len(rows) - len(kept)


def apply_all(rows: list[dict]) -> tuple[list[dict], dict[str, int]]:
    counts = {}
    for name, fn in (("religious", religious), ("minors", minors), ("first_person_self_harm", first_person_self_harm)):
        rows, counts[name] = fn(rows)
    return rows, counts
