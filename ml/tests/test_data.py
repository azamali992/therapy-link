import pytest
import typer

from therapylink_ml.data.build import DEFAULT_OUT, _trim, build
from therapylink_ml.data.splits import assign_splits, dedupe
from therapylink_ml.schema import Conversation, Message, clean_text, normalise_messages


def _conv(i: int, source: str = "s", user: str | None = None) -> Conversation:
    return Conversation(
        id=f"{source}-{i}",
        source=source,
        messages=[
            Message(role="user", content=user or f"hello {i}"),
            Message(role="assistant", content=f"reply {i}"),
        ],
    )


def test_clean_text_normalises_whitespace_and_newlines():
    assert clean_text("  a \t b \r\n\r\n\r\n c  ") == "a b\n\nc"


def test_dedupe_drops_exact_duplicates_case_insensitively():
    a = _conv(1, user="I feel low")
    b = _conv(2, user="i feel LOW")
    b.messages[1] = Message(role="assistant", content="reply 1")
    kept, dropped = dedupe([a, b, _conv(3)])
    assert dropped == 1
    assert [c.id for c in kept] == ["s-1", "s-3"]


def test_assign_splits_is_deterministic_and_stratified():
    items = [_conv(i, source="a") for i in range(200)] + [_conv(i, source="b") for i in range(60)]
    first = {c.id: c.split for c in assign_splits(items, seed=7)}
    for c in items:
        c.split = None
    second = {c.id: c.split for c in assign_splits(items, seed=7)}
    assert first == second
    for source in ("a", "b"):
        splits = {first[c.id] for c in items if c.source == source}
        assert splits == {"train", "val", "test"}


def _conv_with(*roles: str) -> Conversation:
    return Conversation(
        id="x",
        source="s",
        messages=[Message(role=r, content=f"{r} text") for r in roles],
    )


def test_trim_strips_a_leading_assistant_turn():
    # EmpatheticDialogues produced 23 of these; training died on them hours in.
    out = _trim(_conv_with("assistant", "user", "assistant"))
    assert [m.role for m in out.messages] == ["user", "assistant"]


def test_trim_strips_a_trailing_user_turn():
    out = _trim(_conv_with("user", "assistant", "user"))
    assert [m.role for m in out.messages] == ["user", "assistant"]


def test_trim_drops_conversations_with_nothing_left():
    assert _trim(_conv_with("assistant")) is None
    assert _trim(_conv_with("user")) is None


def test_trim_keeps_the_invariant_after_truncating_long_conversations():
    out = _trim(_conv_with(*(["user", "assistant"] * 40)))
    assert out.messages[0].role == "user"
    assert out.messages[-1].role == "assistant"
    assert len(out.messages) <= 40


def test_trim_merges_consecutive_same_role_turns():
    # Chat templates reject non-alternating roles; a speaker split across rows is still one turn.
    out = _trim(_conv_with("user", "user", "assistant", "assistant", "user", "assistant"))
    assert [m.role for m in out.messages] == ["user", "assistant", "user", "assistant"]


def test_normalise_merges_content_rather_than_discarding_it():
    out = normalise_messages([
        Message(role="user", content="first"),
        Message(role="user", content="second"),
        Message(role="assistant", content="reply"),
    ])
    assert out[0].content == "first\nsecond"


def test_normalise_keeps_the_first_strategy_label_when_merging():
    out = normalise_messages([
        Message(role="user", content="hi"),
        Message(role="assistant", content="a", strategy="reflection"),
        Message(role="assistant", content="b", strategy="question"),
    ])
    assert out[-1].strategy == "reflection"


def test_normalise_drops_empty_turns_without_breaking_alternation():
    out = normalise_messages([
        Message(role="user", content="hi"),
        Message(role="assistant", content="   "),
        Message(role="user", content="still me"),
        Message(role="assistant", content="reply"),
    ])
    assert [m.role for m in out] == ["user", "assistant"]
    assert out[0].content == "hi\nstill me"


def test_assign_splits_keeps_existing_split():
    c = _conv(1)
    c.split = "test"
    assign_splits([c] + [_conv(i) for i in range(2, 60)])
    assert c.split == "test"


def test_a_pending_build_cannot_write_into_the_training_corpus(tmp_path):
    # Refused before anything is loaded or written.
    with pytest.raises(typer.BadParameter, match="--include-pending"):
        build(only=["tl_authored"], out=DEFAULT_OUT, include_pending=True)
    build(only=["tl_authored"], out=tmp_path, include_pending=True)
    assert "review:pending_clinician" in (tmp_path / "conversations.train.jsonl").read_text(encoding="utf-8")
