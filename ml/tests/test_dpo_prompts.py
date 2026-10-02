"""The DPO prompt set decides what preference training sees, so it is held apart from the eval probes
(or the eval would measure recall) and checked for shape before a GPU session depends on it."""

import json
import re
from collections import Counter
from pathlib import Path

import pytest

from therapylink_ml.eval.run import PROBES
from therapylink_ml.train.eve_dpo import load_prompts

PROMPTS = Path(__file__).resolve().parents[1] / "therapylink_ml" / "data" / "dpo_prompts"
FILES = sorted(PROMPTS.glob("*.jsonl"))
_WORD = re.compile(r"[a-z']+")

pytestmark = pytest.mark.skipif(not FILES, reason="no DPO prompt set yet")


def _rows():
    for f in FILES:
        for line in f.read_text(encoding="utf-8").splitlines():
            if line.strip():
                yield f.name, json.loads(line)


def _user_texts(r):
    if "messages" in r:
        return [m["content"] for m in r["messages"] if m["role"] == "user"]
    return [r["text"]]


def _words(t):
    return set(_WORD.findall(t.lower()))


def test_rows_are_well_formed_with_unique_ids():
    ids = Counter()
    for name, r in _rows():
        ids[r["id"]] += 1
        assert r["lang"] in {"en", "ur-roman", "mixed"} and r["route"] in {"eve", "crisis"} and r.get("bucket"), (name, r["id"])
        assert ("text" in r) != ("messages" in r), (name, r["id"])
        if "messages" in r:
            roles = [m["role"] for m in r["messages"]]
            assert roles[0] == "user" and roles[-1] == "user", r["id"]
            assert all(a != b for a, b in zip(roles, roles[1:], strict=False)), r["id"]
        assert all(t.strip() for t in _user_texts(r)), r["id"]
    assert not [i for i, n in ids.items() if n > 1]


def test_the_loader_reads_every_file():
    for f in FILES:
        rows = load_prompts(str(f))
        assert rows and all(r["messages"][-1]["role"] == "user" for r in rows), f.name


def test_crisis_is_a_real_share_but_not_most_of_it():
    routes = Counter(r["route"] for _, r in _rows())
    share = routes["crisis"] / sum(routes.values())
    assert 0.15 <= share <= 0.45, routes


def test_no_prompt_paraphrases_an_eval_probe():
    probes = [_words(json.loads(line)["text"]) for f in PROBES.glob("*.jsonl") for line in f.open(encoding="utf-8") if line.strip()]
    for _, r in _rows():
        for text in _user_texts(r):
            mine = _words(text)
            if len(mine) < 4:
                continue  # "hi", "ok thanks": too short to paraphrase anything
            worst = max(len(mine & p) / len(mine | p) for p in probes)
            assert worst < 0.35, (r["id"], round(worst, 2))
