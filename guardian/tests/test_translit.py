import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "data"))
import translit  # noqa: E402

LATIN = re.compile(r"[A-Za-z']+")


def test_transliterate_known_words():
    assert translit.transliterate("مجھے نہیں پتہ کیا کروں") == "mujhe nahi pata kya karoon"
    assert translit.transliterate("تم بہت اچھے ہو یار") == "tum bohat ache ho yaar"
    assert translit.transliterate("کھانا") == "khaana"  # aspirate
    assert translit.transliterate("وقت") == "waqt"  # short-vowel guess after initial consonant
    assert translit.transliterate("کہاں ہے؟ ۱۲۳۔") == "kahan hai? 123."  # punctuation and digits
    assert translit.transliterate("مُجھے") == "mujhe"  # tashkeel stripped before lexicon lookup


def test_respell_deterministic_and_only_from_table():
    src = "mujhe nahi pata kya karoon yaar bohat aur tum"
    a = translit.respell(src, 11, rate=1.0)
    assert a == translit.respell(src, 11, rate=1.0)
    for orig, new in zip(src.split(), a.split()):
        if orig in translit.VARIANTS:
            assert new in translit.VARIANTS[orig]
        else:
            assert new == orig  # words outside the table are never touched
    assert translit.respell(src, 11, rate=0.0) == src


def test_codemix_only_touches_dict_words():
    src = "kal ghar jaun ga lekin paise nahi hain"
    out = translit.codemix(src, 3, rate=1.0)
    for orig, new in zip(src.split(), out.split()):
        if orig in translit.CODEMIX:
            assert new == translit.CODEMIX[orig]
        else:
            assert new == orig
    assert translit.codemix(src, 3, rate=1.0) == out


def test_make_roman_provenance():
    urdu = "کل اسے سبق سکھاؤں گا"
    r = translit.make_roman(urdu, seed=5)
    assert r == translit.make_roman(urdu, seed=5)
    assert r["provenance"] == {
        "urdu_from": "transliterated",
        "translit": "rule-v0",
        "variant_seed": 5,
        "respell_rate": 0.3,
        "codemix_rate": 0.15,
        "source_text": urdu,
    }
    assert LATIN.search(r["text"]) and not re.search(r"[؀-ۿ]", r["text"])
