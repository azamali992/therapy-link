from therapylink_ml.eval import metrics, run


def test_opener_repetition():
    replies = [
        "It sounds like a lot.",
        "It sounds like work is heavy.",
        "it sounds, like, rough",
        "That must hurt.",
        "Yeh sun kar dukh hua.",
    ]
    out = metrics.opener_repetition(replies)
    assert out == {"top": "it sounds like", "top_share": 0.6, "repeated_share": 0.6}
    assert metrics.opener_repetition(["", "  "])["top_share"] is None


def test_distinct_2():
    assert metrics.distinct_n(["a b c", "a b d"], 2) == 0.75  # (a b) repeats: 3 unique of 4
    assert metrics.distinct_n(["same same", "same same"], 2) == 0.5
    assert metrics.distinct_n(["one"], 2) is None


def test_summary_carries_the_diversity_metrics():
    rows = [
        {"id": f"t{i}", "suite": "therapeutic", "lang": "en", "reply": r}
        for i, r in enumerate(["It sounds like a lot.", "It sounds like work.", "What a week."])
    ]
    for r in rows:
        r["rules"] = run.safety_rules.check(r, r["reply"])
    d = run.summarise(rows)["diversity"]
    assert d["opener"]["top_share"] == 0.667
    assert 0 < d["distinct_2"] <= 1
