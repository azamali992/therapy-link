from collections import Counter

from therapylink_ml.schema import Conversation, Message
from therapylink_ml.train.eve_sft import (
    eval_every,
    load_conversations,
    parse_min_quality,
    read_conversations,
    stratified_sample,
    trained_prompt_manifest,
)

PROSE = " ".join(["word"] * 60)


def _conv(i, source, reply=PROSE, quality=None, lang="en"):
    return Conversation(
        id=f"{source}-{i}",
        source=source,
        lang=lang,
        messages=[Message(role="user", content=f"{source} message {i}"), Message(role="assistant", content=reply)],
        quality=quality,
    )


def _write(path, convs):
    with path.open("w", encoding="utf-8") as f:
        for c in convs:
            f.write(c.model_dump_json() + "\n")
    return path


def test_min_quality_drops_low_rated_annomi_and_leaves_upvotes_alone(tmp_path):
    data = _write(
        tmp_path / "c.jsonl",
        [_conv(1, "annomi", quality=1.0), _conv(2, "annomi", quality=0.0), _conv(3, "annomi"), _conv(4, "counselchat", quality=0.0)],
    )
    kept = {c.id for c in read_conversations(data, exclude_nc=False, min_quality=parse_min_quality("1.0"))}
    # quality=0.0 on counselchat is an upvote count, not a rating: a bare floor never touches it.
    assert kept == {"annomi-1", "annomi-3", "counselchat-4"}
    assert parse_min_quality("") == {}
    assert parse_min_quality("counselchat=2") == {"counselchat": 2.0}


def test_mentalchat_keeps_only_short_prose_replies(tmp_path):
    long_reply = " ".join(["word"] * 181)
    listy = "Here are a few things:\n- sleep earlier\n- drink water\n- take a walk"
    data = _write(
        tmp_path / "c.jsonl",
        [_conv(1, "mentalchat16k"), _conv(2, "mentalchat16k", reply=long_reply), _conv(3, "mentalchat16k", reply=listy), _conv(4, "annomi", reply=long_reply)],
    )
    kept = {c.id for c in read_conversations(data, exclude_nc=False, mentalchat_max_words=180)}
    assert kept == {"mentalchat16k-1", "annomi-4"}
    assert len(read_conversations(data, exclude_nc=False)) == 4


def test_filters_run_before_weighting(tmp_path):
    data = _write(tmp_path / "c.jsonl", [_conv(1, "annomi", quality=1.0), _conv(2, "annomi", quality=0.0)])
    convs = load_conversations(data, exclude_nc=False, weights={"annomi": 3}, seed=1, min_quality={"annomi": 1.0})
    assert len(convs) == 3 and all(c[0]["content"].endswith("annomi message 1") for c in convs)


def test_validation_sample_is_stratified_by_source_and_deterministic():
    convs = [_conv(i, "a") for i in range(600)] + [_conv(i, "b") for i in range(300)] + [_conv(i, "c") for i in range(4)]
    picked = stratified_sample(convs, 300, seed=13)
    counts = Counter(c.source for c in picked)
    assert len(picked) == 300
    assert counts["c"] >= 1 and abs(counts["a"] - 2 * counts["b"]) <= 3
    assert [c.id for c in picked] == [c.id for c in stratified_sample(convs, 300, seed=13)]
    assert stratified_sample(convs[:10], 300, seed=13) == convs[:10]


def test_validation_split_through_the_loader(tmp_path):
    data = _write(tmp_path / "v.jsonl", [_conv(i, "a") for i in range(50)] + [_conv(i, "b") for i in range(50)])
    val = load_conversations(data, exclude_nc=False, weights={}, seed=13, sample=30)
    assert len(val) == 30


def test_eval_runs_every_half_epoch():
    # 590 optimizer steps an epoch at batch 2 x 8 (v14): measure the val loss twice an epoch.
    assert eval_every(9440, 2, 8) == 295
    assert eval_every(10, 2, 8) == 1


def test_the_adapter_records_the_prompt_it_was_trained_with():
    import hashlib

    from therapylink_ml.prompts import EVE_SYSTEM_PROMPT

    manifest = trained_prompt_manifest()
    assert manifest["prompt"] in {"v1", "v2"}
    assert manifest["sha256"] == hashlib.sha256(EVE_SYSTEM_PROMPT.encode("utf-8")).hexdigest()
