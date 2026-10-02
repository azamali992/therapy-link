"""The authored crisis set is training data for a safety behaviour, so it is held to the same rules
the eval uses — and kept lexically away from the eval probes so the eval still measures
generalisation rather than recall."""

import json
import re
from collections import Counter

from therapylink_ml.data.loaders.authored import AUTHORED_DIR, PENDING, REVIEW_STATUSES, is_pending, load, rows
from therapylink_ml.eval import safety_rules
from therapylink_ml.eval.run import PROBES
from therapylink_ml.train.reply_rules import MEDICATION, foreign_numbers, is_listy, score_reply

# Every row, including drafts pending clinician review: a draft must meet the same bar before review.
ROWS = list(rows(include_pending=True))
_WORD = re.compile(r"[a-z']+")


def _assistant_turns(r):
    return [m["content"] for m in r["messages"] if m["role"] == "assistant"]


def _words(text):
    return set(_WORD.findall(text.lower()))


def test_ids_are_unique_and_conversations_are_well_formed():
    ids = Counter(r["id"] for r in ROWS)
    assert ROWS and not [i for i, n in ids.items() if n > 1]
    for r in ROWS:
        roles = [m["role"] for m in r["messages"]]
        assert roles[0] == "user" and roles[-1] == "assistant", r["id"]
        assert all(a != b for a, b in zip(roles, roles[1:], strict=False)), r["id"]
        assert r["route"] in {"crisis", "eve"} and r["lang"] in {"en", "ur-roman", "mixed"}, r["id"]


def test_crisis_replies_acknowledge_and_name_real_help():
    for r in (r for r in ROWS if r["route"] == "crisis"):
        final = _assistant_turns(r)[-1]
        assert safety_rules.ACKNOWLEDGE.search(final), f"{r['id']}: no acknowledgement"
        assert safety_rules.RESOURCE.search(final), f"{r['id']}: no resource"
        # Verified 2026-09-15: Umang 24/7 mental health, Rescue 1122, Madadgaar 1098 (violence
        # against women and children), Ministry of Human Rights 1099.
        assert re.search(r"0311-?7786264|\b1122\b|\b1098\b|\b1099\b", final), f"{r['id']}: no verified number"


def test_everyday_stress_replies_never_reach_for_a_helpline():
    for r in (r for r in ROWS if r["route"] == "eve"):
        for turn in _assistant_turns(r):
            assert not safety_rules.OVERREACT.search(turn), f"{r['id']}: over-reaction"


def test_no_reply_contains_harmful_or_dismissive_language():
    for r in ROWS:
        for turn in _assistant_turns(r):
            for name in ("METHOD", "MINIMISE", "LECTURE", "BLAME"):
                assert not getattr(safety_rules, name).search(turn), f"{r['id']}: {name}"


def test_replies_are_substantial_not_one_liners():
    for r in ROWS:
        for turn in _assistant_turns(r):
            assert len(turn.split()) >= 30, f"{r['id']}: {len(turn.split())} words"


def test_roman_urdu_rows_are_answered_in_roman_urdu():
    for r in (r for r in ROWS if r["lang"] in {"ur-roman", "mixed"}):
        for turn in _assistant_turns(r):
            assert len(safety_rules.ROMAN_URDU.findall(turn)) >= 3, r["id"]


def test_user_turns_do_not_paraphrase_eval_probes():
    probes = [json.loads(line)["text"] for f in PROBES.glob("*.jsonl") for line in f.open(encoding="utf-8") if line.strip()]
    for r in ROWS:
        for m in (m for m in r["messages"] if m["role"] == "user"):
            mine = _words(m["content"])
            for probe in probes:
                theirs = _words(probe)
                overlap = len(mine & theirs) / max(1, len(mine | theirs))
                assert overlap < 0.35, f"{r['id']} overlaps probe {probe[:50]!r} ({overlap:.2f})"


# --- Review status and the red-line drafts -----------------------------------------------------------

PENDING_ROWS = [r for r in ROWS if is_pending(r)]
# "Free" and "24/7" are claims about a helpline that no human has verified yet; drafts don't make them.
UNVERIFIED_CLAIM = re.compile(r"\bfree\b|24/7|24 ghante", re.I)
# Roman Urdu marks the listener's gender on verbs and adjectives ("soch rahi hain", "akelay"). With
# no cue from the person, a draft addresses them without assuming one (llm-engineer.md finding 14).
GENDERED_ADDRESS = re.compile(r"\baap\b[^.?!]{0,30}\b(rahi|rahe|sakti|sakte|chahti|chahte|karti|karte|gayi|gaye|akeli|akela|akelay|thi|thin)\b", re.I)


def test_review_status_is_known_and_red_line_drafts_are_pending():
    for r in ROWS:
        assert r.get("review_status", "approved") in REVIEW_STATUSES, r["id"]
    for path in AUTHORED_DIR.glob("redline_*.jsonl"):
        for line in path.read_text(encoding="utf-8").splitlines():
            assert json.loads(line).get("review_status") == PENDING, f"{path.name}: drafts stay pending until a clinician signs off"
    assert PENDING_ROWS


def test_pending_rows_never_reach_a_corpus_by_default():
    pending = {r["id"] for r in PENDING_ROWS}
    assert not pending & {r["id"] for r in rows()}
    assert all(not any(t.startswith("review:") for t in c.tags) for c in load())
    assert sum(any(t == f"review:{PENDING}" for t in c.tags) for c in load(include_pending=True)) == len(pending)


def test_no_reply_names_a_foreign_number():
    for r in ROWS:
        for turn in _assistant_turns(r):
            assert not foreign_numbers(turn), f"{r['id']}: {foreign_numbers(turn)}"


def test_drafts_pass_the_hard_reply_rules():
    for r in PENDING_ROWS:
        final = _assistant_turns(r)[-1]
        assert score_reply(r["route"], r["lang"], final).passed, f"{r['id']}: {score_reply(r['route'], r['lang'], final).failures}"
        for turn in _assistant_turns(r):
            assert not is_listy(turn) and turn.count("?") <= 2 and not MEDICATION.search(turn), r["id"]
            assert not UNVERIFIED_CLAIM.search(turn), f"{r['id']}: unverified helpline claim"


def test_drafts_cover_the_red_line_categories_in_every_language():
    by_category: dict[str, set[str]] = {}
    for r in PENDING_ROWS:
        by_category.setdefault(r["category"], set()).add(r["lang"])
    for category in ("indirect_signs", "asking_for_a_friend", "method_request", "sexual_violence", "child_user", "medication_request", "listy_advice"):
        assert by_category.get(category) == {"en", "ur-roman", "mixed"}, category
    child = [r for r in PENDING_ROWS if r["category"] == "child_user"]
    assert all("1098" in _assistant_turns(r)[-1] for r in child)


def test_roman_urdu_drafts_do_not_assume_the_persons_gender():
    for r in (r for r in PENDING_ROWS if r["lang"] in {"ur-roman", "mixed"}):
        for turn in _assistant_turns(r):
            m = GENDERED_ADDRESS.search(turn)
            assert not m, f"{r['id']}: {m.group(0)!r}"
