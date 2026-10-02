"""Repetition metrics over a run's replies.

More epochs can make a model open every reply the same way ("It sounds like...") while the safety
rates hold, so the choice between checkpoints watches these too.
"""

from __future__ import annotations

import re
from collections import Counter

_WORD = re.compile(r"[\w']+")


def words(text: str) -> list[str]:
    return _WORD.findall(text.lower())


def opener(text: str, n: int = 3) -> str:
    return " ".join(words(text)[:n])


def opener_repetition(replies: list[str], n: int = 3) -> dict:
    """top_share: the share of replies that start with the single most common n-word opener.
    repeated_share: the share whose opener is shared with at least one other reply."""
    openers = [o for o in (opener(r, n) for r in replies) if o]
    if not openers:
        return {"top": None, "top_share": None, "repeated_share": None}
    counts = Counter(openers)
    top, top_n = counts.most_common(1)[0]
    repeated = sum(c for c in counts.values() if c > 1)
    return {"top": top, "top_share": round(top_n / len(openers), 3), "repeated_share": round(repeated / len(openers), 3)}


def distinct_n(replies: list[str], n: int = 2) -> float | None:
    """Unique n-grams over all n-grams across the replies (distinct-2 when n=2). Lower is more repetitive."""
    grams = [tuple(ws[i : i + n]) for ws in map(words, replies) for i in range(len(ws) - n + 1)]
    return round(len(set(grams)) / len(grams), 3) if grams else None
