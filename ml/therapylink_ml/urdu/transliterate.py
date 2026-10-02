"""Stage 2: Urdu script → a rough Roman Urdu seed.

Deliberately simple and deterministic. It produces readable but stiff romanisation; stage 3
rewrites it into the register people actually type. Do not tune this into a good transliterator —
the point is to hand the LLM something it can't mistranslate, not something pretty.
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path

import typer

from therapylink_ml.urdu.common import URDU_DIR, read_jsonl, run_resumable

app = typer.Typer(add_completion=False)

_MAP = {
    "ا": "a", "آ": "aa", "ب": "b", "پ": "p", "ت": "t", "ٹ": "t", "ث": "s", "ج": "j", "چ": "ch",
    "ح": "h", "خ": "kh", "د": "d", "ڈ": "d", "ذ": "z", "ر": "r", "ڑ": "r", "ز": "z", "ژ": "zh",
    "س": "s", "ش": "sh", "ص": "s", "ض": "z", "ط": "t", "ظ": "z", "ع": "a", "غ": "gh", "ف": "f",
    "ق": "q", "ک": "k", "گ": "g", "ل": "l", "م": "m", "ن": "n", "ں": "n", "و": "o", "ہ": "h",
    "ھ": "h", "ء": "", "ی": "i", "ے": "e", "ئ": "i", "ۃ": "h", "ة": "h", "ك": "k", "ي": "i",
    "۔": ".", "،": ",", "؟": "?", "؛": ";", "٪": "%",
    "َ": "a", "ِ": "i", "ُ": "u", "ً": "an", "ٍ": "in", "ٌ": "un", "ْ": "", "ٰ": "a",
    "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4", "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9",
}
_SHADDA = "ّ"
_WORD = re.compile(r"\S+")

_COMMON = {
    "ہے": "hai", "ہیں": "hain", "ہوں": "hoon", "نہیں": "nahi", "میں": "mein", "مجھے": "mujhe",
    "آپ": "aap", "تم": "tum", "کیا": "kya", "کیوں": "kyun", "بہت": "bohat", "ٹھیک": "theek",
    "اور": "aur", "لیکن": "lekin", "کے": "ke", "کی": "ki", "کا": "ka", "کو": "ko", "سے": "se",
    "پر": "par", "یہ": "yeh", "وہ": "woh", "تھا": "tha", "تھی": "thi", "تھے": "the", "ہو": "ho",
    "ہوتا": "hota", "ہوتی": "hoti", "کرنا": "karna", "کر": "kar", "رہا": "raha", "رہی": "rahi",
    "رہے": "rahe", "گا": "ga", "گی": "gi", "گے": "ge", "اب": "ab", "جب": "jab", "تو": "to",
    "بھی": "bhi", "کچھ": "kuch", "سب": "sab", "اچھا": "acha", "برا": "bura", "دل": "dil",
    "زندگی": "zindagi", "کبھی": "kabhi", "ہمیشہ": "hamesha", "لگتا": "lagta", "لگتی": "lagti",
    "چاہتا": "chahta", "چاہتی": "chahti", "سکتا": "sakta", "سکتی": "sakti", "شکریہ": "shukriya",
}


def _word(w: str) -> str:
    stripped = w.strip(".,!?؟،۔;:\"'()")
    if stripped in _COMMON:
        return w.replace(stripped, _COMMON[stripped])
    out: list[str] = []
    chars = list(w)
    for i, ch in enumerate(chars):
        if ch == _SHADDA:
            if out:
                out.append(out[-1])
            continue
        if ch == "و" and (i == 0 or chars[i - 1] in "اآ"):
            out.append("w")
        elif ch == "ی" and i == 0:
            out.append("y")
        elif ch == "ا" and i == 0 and i + 1 < len(chars) and chars[i + 1] in "َِ ُ":
            continue
        else:
            out.append(_MAP.get(ch, ch))
    return "".join(out)


def romanise(text: str) -> str:
    text = unicodedata.normalize("NFC", text)
    return _WORD.sub(lambda m: _word(m.group(0)), text)


@app.command()
def run(source: Path = URDU_DIR / "stage1_translated.jsonl", out: Path = URDU_DIR / "stage2_romanised.jsonl") -> None:
    def fn(conv: dict) -> dict:
        for m in conv["messages"]:
            m["ur_roman_seed"] = romanise(m["ur"])
        return conv

    run_resumable(read_jsonl(source), out, fn, label="romanise")


@app.command()
def demo(text: str) -> None:
    typer.echo(romanise(text))


if __name__ == "__main__":
    app()
