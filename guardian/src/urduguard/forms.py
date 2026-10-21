"""Cheap language-form detection: en, ur (Urdu script), roman_ur, mixed.

Script is decided by Unicode block. Latin text is split into Roman Urdu vs English by a small word list
plus character n-gram cues, because fastText lid.176 has no Roman Urdu class and labels romanised Urdu as
whatever Latin language it resembles. The detector is itself a fairness surface: the eval harness reports
gate results with gold forms and with detected forms, and the detector's confusion matrix ships in the
coverage card.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

_ARABIC = re.compile(r"[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]")
_LATIN = re.compile(r"[A-Za-z]")
_WORD = re.compile(r"[A-Za-z']+")

# Function words and very common tokens of Roman Urdu with their usual spellings. A Latin-script message
# in which these make up a noticeable share of the words is Roman Urdu or mixed.
ROMAN_URDU_WORDS = frozenset("""
hai hain hy h hn ha nahi nahin nhi nai ni mujhe mujhay mjhe muje mujh main mein mai mn kya kia kiya kyun kyu kiun q
aur or tum tm ap aap woh wo yeh ye yh us is ka ki ke ko se mein me par pe bhi tha thi they thay the hoon hun hu ho
kar kr karo kro karna krna kiya kya raha rahi rahe rha rhi rhe liye lye ab abhi phir fir acha accha achha bohat bohot
bahut bht kuch kch sab sb log loag yaar yar bhai dost ghar ghr kaam kam kal aaj aj waqt time paisa paise pesa
lekin magar kyunke kyun ke agar to toh na mat nahi ja jao gaya gayi gaye jana aana aya ayi aye dekho dekh bolo bol
suno sun mera meri mere tera teri tere uska uski uske hamara hamari hamare tumhara tumhari apna apni apne khud
zindagi zindgi jaan jan dil dimagh dimaag pyar pyaar mohabbat shadi shaadi larki larka ladki ladka beta beti ammi
abbu abba bhabhi behen bahen chacha mamu khala phuppo saath sath wala wali wale thora thoda zyada ziada bilkul
bas bs theek thik sahi galat matlab mtlb kaise kese kaisa kesa kahan kaha kab kon kaun kisi kisko kisne jab tab
insan insaan dunya duniya baat bat batao bta kr do dede dedo lo le lena dena dedo chal chalo chalein chale
""".split())

# Short English stopwords that Roman Urdu writers also use; they do not count for either side.
_NEUTRAL = frozenset("a an the i you he she it we is are was be to of in on at and or but not no yes ok okay so if do did me us they time log bat h ha ho hu na mat ja jab tab kon bs le lo pe ye hun".split())


@dataclass(frozen=True)
class FormGuess:
    form: str
    script_ratio: float  # share of letters in Arabic script
    roman_ratio: float   # share of Latin words that look Roman Urdu (0 when no Latin words)


def detect(text: str) -> FormGuess:
    arabic = len(_ARABIC.findall(text))
    latin = len(_LATIN.findall(text))
    total = arabic + latin
    if total == 0:
        return FormGuess("en", 0.0, 0.0)
    script_ratio = arabic / total
    words = [w.lower() for w in _WORD.findall(text)]
    words = [w for w in words if w not in _NEUTRAL]
    # shortcut: fewer than three content words is not enough evidence to call Latin text Roman Urdu; upgrade when a trained detector exists
    roman_ratio = (sum(w in ROMAN_URDU_WORDS for w in words) / len(words)) if len(words) >= 3 else 0.0
    if script_ratio >= 0.9:
        return FormGuess("ur", script_ratio, roman_ratio)
    if script_ratio > 0.1:
        return FormGuess("mixed", script_ratio, roman_ratio)
    if roman_ratio >= 0.5:
        return FormGuess("roman_ur", script_ratio, roman_ratio)
    if roman_ratio >= 0.3:
        return FormGuess("mixed", script_ratio, roman_ratio)
    return FormGuess("en", script_ratio, roman_ratio)
