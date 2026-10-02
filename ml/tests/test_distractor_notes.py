import random

from therapylink_ml.prompts import MEMORY_HEADER, SUMMARY_HEADER
from therapylink_ml.schema import Conversation, Message
from therapylink_ml.train import distractor_notes
from therapylink_ml.train.distractor_notes import sample_notes
from therapylink_ml.train.eve_sft import load_conversations


def _write(path, n, route, notes=None):
    with path.open("a", encoding="utf-8") as f:
        for i in range(n):
            c = Conversation(
                id=f"{route}-{i}",
                source="tl_authored",
                messages=[Message(role="user", content=f"{route} message {i}"), Message(role="assistant", content="hi there")],
                tags=[f"route:{route}"],
                notes=notes,
            )
            f.write(c.model_dump_json() + "\n")


def _has_notes(conv):
    return MEMORY_HEADER in conv[0]["content"] or SUMMARY_HEADER in conv[0]["content"]


def test_notes_follow_the_app_layout_in_every_language():
    rng = random.Random(0)
    for lang in ("en", "ur-roman", "mixed"):
        for _ in range(50):
            block = sample_notes(rng, lang)
            assert block.startswith((MEMORY_HEADER + "\n- ", SUMMARY_HEADER + "\n"))


def test_distractors_reach_a_share_of_conversations_and_crisis_ones_more_often(tmp_path):
    data = tmp_path / "convs.jsonl"
    _write(data, 400, "eve")
    _write(data, 400, "crisis")
    convs = load_conversations(data, exclude_nc=False, weights={}, seed=1, notes_frac=0.2)
    eve = [c for c in convs if "hi there" in c[1]["content"] and not c[0]["content"].count("route")]
    with_notes = sum(map(_has_notes, eve))
    assert 0.25 * len(eve) < with_notes < 0.45 * len(eve)  # 400 x 0.2 + 400 x 0.5 of 800


def test_the_pool_is_templated_and_about_three_hundred_strong():
    sizes = distractor_notes.pool_size()
    assert 280 <= sizes["memories"] + sizes["risk_memories"] <= 360
    assert sizes["summaries"] >= 60 and sizes["risk_memories"] >= 20
    everything = distractor_notes.MEMORIES_EN + distractor_notes.MEMORIES_UR + distractor_notes.RISK_MEMORIES_EN + distractor_notes.RISK_MEMORIES_UR
    assert len(everything) == len(set(everything))
    assert not any("{" in m or "\n" in m for m in everything)
    # Deterministic: a resumed run with the same seed must see the same notes.
    assert distractor_notes._expand(distractor_notes._TEMPLATES_EN, 18, seed=1) == distractor_notes.MEMORIES_EN


def test_risk_memories_only_on_crisis_conversations(tmp_path):
    risk = set(distractor_notes.RISK_MEMORIES_EN + distractor_notes.RISK_MEMORIES_UR)
    rng = random.Random(0)
    assert not any(r in sample_notes(rng, "en") for _ in range(300) for r in risk)
    assert any(r in sample_notes(rng, "en", allow_risk=True) for _ in range(300) for r in risk)

    data = tmp_path / "convs.jsonl"
    _write(data, 300, "eve")
    _write(data, 300, "crisis")
    convs = load_conversations(data, exclude_nc=False, weights={}, seed=3, notes_frac=0.5)

    def has_risk(conv):
        return any(r in conv[0]["content"] for r in risk)

    def route(conv):
        return conv[0]["content"].rsplit("\n\n", 1)[1].split(" ")[0]

    assert not any(has_risk(c) for c in convs if route(c) == "eve")
    assert any(has_risk(c) for c in convs if route(c) == "crisis")


def test_off_by_default_and_authored_notes_are_kept(tmp_path):
    data = tmp_path / "convs.jsonl"
    _write(data, 50, "crisis")
    assert not any(map(_has_notes, load_conversations(data, exclude_nc=False, weights={}, seed=1)))
    kept = tmp_path / "kept.jsonl"
    _write(kept, 5, "eve", notes=SUMMARY_HEADER + "\nThey talked about exams.")
    for conv in load_conversations(kept, exclude_nc=False, weights={}, seed=1, notes_frac=1.0):
        assert "They talked about exams." in conv[0]["content"]
