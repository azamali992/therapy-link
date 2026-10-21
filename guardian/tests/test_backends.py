"""Output parsing for the open guard models, without loading any weights."""

from urduguard.eval.backends import HFGenerativeBackend, LLAMA_GUARD_3_MODEL, QWEN3GUARD_MODEL, make


def _backend(model_id: str, strict: bool = True) -> HFGenerativeBackend:
    b = HFGenerativeBackend.__new__(HFGenerativeBackend)
    b.model_id, b.strict = model_id, strict
    return b


def test_llama_guard_3_parse():
    b = _backend(LLAMA_GUARD_3_MODEL)
    assert b.parse("safe").flagged is False
    p = b.parse("unsafe\nS1,S10")
    assert p.flagged and p.labels == {"violence_threats", "hate_group"}
    assert b.parse("unsafe\nS2").labels == {"other"}  # unsafe but outside the taxonomy still counts as flagged


def test_qwen3guard_parse_strict_and_loose():
    strict, loose = _backend(QWEN3GUARD_MODEL, True), _backend(QWEN3GUARD_MODEL, False)
    assert strict.parse("Safety: Safe\nCategories: None").flagged is False
    p = strict.parse("Safety: Unsafe\nCategories: Violent, PII")
    assert p.flagged and p.labels == {"violence_threats", "other"}
    c = "Safety: Controversial\nCategories: Politically Sensitive Topics"
    assert strict.parse(c).flagged is True and loose.parse(c).flagged is False
    assert strict.parse(c).labels == {"needs_caution"}


def test_make_rejects_unknown():
    try:
        make("nope:x")
    except ValueError as e:
        assert "unknown backend" in str(e)
    else:
        raise AssertionError
