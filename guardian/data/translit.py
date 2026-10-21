"""Rule-based Urdu script -> Roman Urdu with a spelling-variant sampler.

Stdlib only. Rule set id: "rule-v0". Known weak spots (see docs/research/03-roman-urdu.md):
unmarked short vowels, hamza (ئ) on verbs, izafat, medial choti ye.
"""
from __future__ import annotations

import random
import re
import sys

RULE_ID = "rule-v0"

# Function words: most common chat spelling. Applied before char rules so they keep their vowels.
LEXICON = {
    "ہے": "hai", "ہیں": "hain", "نہیں": "nahi", "مجھے": "mujhe", "کیا": "kya", "اور": "aur",
    "میں": "main", "ہو": "ho", "ہوں": "hoon", "کا": "ka", "کی": "ki", "کے": "ke", "کو": "ko",
    "سے": "se", "پر": "par", "بھی": "bhi", "تم": "tum", "آپ": "ap", "وہ": "woh", "یہ": "yeh",
    "اس": "us", "یہی": "yehi", "کچھ": "kuch", "سب": "sab", "اب": "ab", "پھر": "phir", "کیوں": "kyun",
    "اچھا": "acha", "اچھے": "ache", "بہت": "bohat", "لوگ": "log", "یار": "yaar", "بھائی": "bhai",
    "کہ": "ke", "تو": "to", "نے": "ne", "ہی": "hi", "تھا": "tha", "تھی": "thi", "تھے": "the",
    "گا": "ga", "گی": "gi", "گے": "ge", "رہا": "raha", "رہی": "rahi", "رہے": "rahe", "کر": "kar",
    "کیسے": "kaise", "کہاں": "kahan", "کب": "kab", "کوئی": "koi", "کروں": "karoon", "جاؤں": "jaun",
    "تمہارا": "tumhara", "مجھ": "mujh", "ہم": "hum", "میرا": "mera", "میری": "meri", "لیکن": "lekin",
    "کیونکہ": "kyunke", "آج": "aaj", "کل": "kal", "اسے": "usay", "ہمیشہ": "hamesha",
    "گھر": "ghar", "پیسے": "paise", "پیسہ": "paisa", "دوست": "dost", "زندگی": "zindagi",
}

# Single-letter map. Context letters (ا ی و ہ) are handled in _romanize_word.
CHARS = {
    "ب": "b", "پ": "p", "ت": "t", "ٹ": "t", "ث": "s", "ج": "j", "چ": "ch", "ح": "h", "خ": "kh",
    "د": "d", "ڈ": "d", "ذ": "z", "ر": "r", "ڑ": "r", "ز": "z", "ژ": "zh", "س": "s", "ش": "sh",
    "ص": "s", "ض": "z", "ط": "t", "ظ": "z", "ع": "", "غ": "gh", "ف": "f", "ق": "q", "ک": "k",
    "ك": "k", "گ": "g", "ل": "l", "م": "m", "ن": "n", "ں": "n", "ھ": "h", "ء": "", "ئ": "i",
    "ؤ": "o", "ے": "e", "آ": "aa", "ۃ": "a", "ة": "a", "ي": "i", "ى": "a", "أ": "a", "إ": "i",
}
PUNCT = {"۔": ".", "؟": "?", "،": ",", "؛": ";", "٪": "%", "«": '"', "»": '"'}
DIGITS = {c: str(i) for i, c in enumerate("۰۱۲۳۴۵۶۷۸۹")} | {c: str(i) for i, c in enumerate("٠١٢٣٤٥٦٧٨٩")}
CONSONANTS = set(CHARS) - {"ھ", "ء", "ئ", "ؤ", "ے", "آ", "ۃ", "ة", "ي", "ى", "أ", "إ", "ع"}
# Tashkeel, tatweel, zero-width joiners: dropped.
STRIP = re.compile(r"[ً-ٰٟۖ-ۭـ‌‍]")
WORD = re.compile(r"[؀-ۿ]+")
LATIN_WORD = re.compile(r"[A-Za-z']+")

# Attested and observed spelling variants (canonical first). Provenance per set is in the doc.
VARIANTS = {
    "mujhe": ["mujhe", "mujhay", "mjhe", "muje", "mujy"],
    "nahi": ["nahi", "nhi", "nahin", "nai", "ni", "nae"],
    "kya": ["kya", "kia", "kiya", "kya"],
    "hai": ["hai", "hy", "h", "he", "hain"],
    "kar": ["kar", "kr"],
    "main": ["main", "mein", "mai", "mn", "me"],
    "aur": ["aur", "or", "r", "aor"],
    "tum": ["tum", "tm"],
    "acha": ["acha", "accha", "achha", "acha"],
    "bohat": ["bohat", "bohot", "bahut", "bht", "buhat"],
    "kyun": ["kyun", "kyu", "q", "kiun", "kion"],
    "phir": ["phir", "fir", "phr"],
    "mera": ["mera", "mra", "maira"],
    "hoon": ["hoon", "hun", "hu", "hon"],
    "zindagi": ["zindagi", "zindgi", "zndgi"],
    "maar": ["maar", "mar"],
    "jaan": ["jaan", "jan"],
    "dost": ["dost", "dst", "dosst"],
    "yaar": ["yaar", "yar", "yr"],
    "log": ["log", "loag", "lg"],
    "bhai": ["bhai", "bhae", "bhaii", "bhi"],
    "sab": ["sab", "sb"],
    "kuch": ["kuch", "kch", "kuchh"],
    "ab": ["ab", "abb"],
    "ghar": ["ghar", "ghr"],
    "paise": ["paise", "pesay", "paisay", "pese"],
    "larki": ["larki", "larkii", "ladki", "lrki"],
    "shadi": ["shadi", "shaadi", "shadii"],
    "yeh": ["yeh", "ye", "yah", "yeah"],
    "khushi": ["khushi", "kushi", "khooshi", "khoshi", "khshi"],
    "bakwaas": ["bakwaas", "bakwas", "bakwass", "bkwas"],
    "kaise": ["kaise", "kese", "kesi", "kesy", "kaisay"],
    "woh": ["woh", "wo", "vo"],
    "tha": ["tha", "tha"],
}
_VARIANT_OF = {v: group for group in VARIANTS.values() for v in group}

# Roman Urdu -> English, for word-level code-mixing.
CODEMIX = {
    "lekin": "but", "kyunke": "because", "dost": "friend", "ghar": "home", "kaam": "work",
    "kal": "tomorrow", "aaj": "today", "waqt": "time", "paise": "money", "phone": "phone",
    "zindagi": "life", "school": "school", "office": "office", "problem": "problem",
    "khushi": "happiness", "shadi": "wedding", "larki": "girl", "larka": "boy", "sach": "truth",
    "jhoot": "lie", "din": "day", "raat": "night", "subah": "morning", "shaam": "evening",
    "baat": "talk", "sawal": "question", "jawab": "answer", "khana": "food", "pyaar": "love",
}


def _romanize_word(w: str) -> str:
    out = []
    n = len(w)
    for i, c in enumerate(w):
        first, last = i == 0, i == n - 1
        prev = w[i - 1] if i else ""
        if c == "ا":  # alif: short at edges, long in the middle
            out.append("a" if first or last else "aa")
        elif c == "ی":  # choti ye: y at start, i elsewhere
            out.append("y" if first else "i")
        elif c == "و":  # waw: w at start, o after a consonant
            out.append("w" if first else "o")
        elif c == "ہ":  # final he after a consonant is a vowel (پتہ -> pata)
            out.append("a" if last and prev in CONSONANTS else "h")
        else:
            out.append(CHARS.get(c, c))
        # Short-vowel guess: a word-initial consonant followed by a consonant gets an 'a' (وقت -> waqt).
        if first and (c in CONSONANTS or c == "و") and n > 1 and w[1] in CONSONANTS:
            out.append("a")
    s = "".join(out)
    return re.sub(r"ii+", "i", s)


def transliterate(text: str, seed: int | None = None) -> str:
    """Urdu script -> Roman Urdu. With a seed, attested spelling variants are sampled too."""
    text = STRIP.sub("", text)
    text = "".join(PUNCT.get(c, DIGITS.get(c, c)) for c in text)
    text = WORD.sub(lambda m: LEXICON.get(m.group(0)) or _romanize_word(m.group(0)), text)
    return respell(text, seed) if seed is not None else text


def respell(text: str, seed: int, rate: float = 0.3) -> str:
    """Swap a sampled fraction of known words for an attested variant. Deterministic under seed."""
    rng = random.Random(seed)

    def pick(m: re.Match) -> str:
        w = m.group(0)
        group = _VARIANT_OF.get(w.lower())
        if group and rng.random() < rate:
            return rng.choice(group)
        return w

    return LATIN_WORD.sub(pick, text)


def codemix(text: str, seed: int, rate: float = 0.15) -> str:
    """Replace a sampled fraction of dictionary words with their English equivalent."""
    rng = random.Random(seed)

    def pick(m: re.Match) -> str:
        w = m.group(0)
        if w.lower() in CODEMIX and rng.random() < rate:
            return CODEMIX[w.lower()]
        return w

    return LATIN_WORD.sub(pick, text)


def make_roman(urdu_text: str, seed: int, respell_rate: float = 0.3, codemix_rate: float = 0.15) -> dict:
    """Full pipeline with a provenance tag so native speakers can trace and correct a sample."""
    roman = transliterate(urdu_text)
    roman = respell(roman, seed, respell_rate)
    roman = codemix(roman, seed + 1, codemix_rate)  # seed+1: independent draw from respell
    return {
        "text": roman,
        "provenance": {
            "urdu_from": "transliterated",
            "translit": RULE_ID,
            "variant_seed": seed,
            "respell_rate": respell_rate,
            "codemix_rate": codemix_rate,
            "source_text": urdu_text,
        },
    }


if __name__ == "__main__":
    lines = sys.argv[1:] or [l.rstrip("\n") for l in sys.stdin]
    for line in lines:
        print(transliterate(line))
