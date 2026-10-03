import json
import random

import numpy as np
import pytest
import torch

from therapylink_ml.data import guardian_v1 as g
from therapylink_ml.schema import LabeledText
from therapylink_ml.train.guardian import CRISIS_LABELS, calibrate_by_lang, class_lang_report, pos_weights


def _write(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")


def _row(text, labels=("none",), lang="en", **kw):
    return g.make_row(text, lang, list(labels), source="written", author="t01", generated=True, ai_labelled=True, commercial_ok=True, **kw)


# --- Rows and provenance ---------------------------------------------------------------------------


def test_rows_carry_provenance_and_canonical_label_order():
    r = _row("  he hit me   and she said nothing ", ["sexual_violence", "abuse"])
    assert r["text"] == "he hit me and she said nothing"
    assert r["labels"] == ["abuse", "sexual_violence"]  # CRISIS_LABELS order
    assert {"source", "author", "generated", "ai_labelled", "commercial_ok"} <= r.keys()


@pytest.mark.parametrize(
    "lang, labels, match",
    [("en", ["none", "suicidal"], "cannot be combined"), ("en", ["suicide"], "labels must be"), ("hi", ["none"], "unknown lang"), ("en", [], "labels must be")],
)
def test_check_row_rejects_bad_rows(lang, labels, match):
    row = {"id": "x", "text": "t", "lang": lang, "labels": labels}
    with pytest.raises(ValueError, match=match):
        g.check_row(row)


def test_read_batches_groups_parts_by_batch_and_marks_rows_ai_written(tmp_path):
    _write(tmp_path / "t05.part1.jsonl", [{"text": "a b c", "lang": "ur-roman", "labels": ["suicidal"], "tag": "passive"}])
    _write(tmp_path / "t05.part2.jsonl", [{"text": "d e f", "lang": "ur-roman", "labels": ["none"]}])
    _write(tmp_path / "h01.part1.jsonl", [{"text": "held", "lang": "en", "labels": ["none"]}])
    rows = g.read_batches(tmp_path, "t")
    assert [r["author"] for r in rows] == ["t05", "t05"]
    assert all(r["generated"] and r["ai_labelled"] and r["source"] == "written" for r in rows)
    _write(tmp_path / "t06.part1.jsonl", [{"text": "x", "lang": "en", "labels": ["none", "abuse"]}])
    with pytest.raises(ValueError, match=r"t06.part1.jsonl:1"):
        g.read_batches(tmp_path, "t")


def test_probe_rows_take_their_category_labels_and_everyday_probes_are_none():
    rows = {r["author"]: r for r in g.probe_rows()}
    assert rows["probe:s05"]["labels"] == ["abuse"]
    assert rows["probe:s10"]["labels"] == ["abuse", "child"]
    assert rows["probe:s03"]["labels"] == ["self_harm"]
    assert rows["probe:s06"]["labels"] == ["none"] and rows["probe:t01"]["labels"] == ["none"]
    assert not any(r["ai_labelled"] for r in rows.values())


# --- Augmentation ----------------------------------------------------------------------------------


def test_respelling_swaps_roman_urdu_words_for_other_common_spellings():
    rng = random.Random(0)
    out = {g.respell_roman("main nahi jeena chahta yaar", rng, p=1.0) for _ in range(30)}
    assert len(out) > 3
    assert all(o.split()[2] == "jeena" for o in out)  # words without variants stay


def test_augmented_rows_keep_labels_and_point_back_to_their_source():
    rng = random.Random(1)
    src = _row("mujhe nahi pata kya karun, sab khatam lagta hai", ["suicidal"], lang="ur-roman")
    augs = [a for _ in range(20) if (a := g.augment(src, rng))]
    assert augs and all(a["labels"] == ["suicidal"] and a["derived_from"] == src["id"] and a["source"] == "augmented" for a in augs)


def test_mt_quality_filter_drops_hallucinated_translations():
    assert g.mt_ok("he hit me again last night", "اس نے مجھے دوبارہ آخری رات مارا")
    assert not g.mt_ok("My saas hit me with the belan.", "مَیں نے اُس سے کہا : ” مَیں نے تو اِس بات کا یقین کر لیا تھا کہ مجھے آگ لگ گئی ہے ۔")
    assert not g.mt_ok("a long english sentence about my week at work", "ہاں")


# --- Splits ----------------------------------------------------------------------------------------


def test_written_split_is_deterministic_disjoint_and_covers_each_label_set():
    rows = [_row(f"row {i}", ["suicidal"] if i % 2 else ["none"]) for i in range(40)]
    train, val = g.split_written(rows)
    again = g.split_written(list(reversed(rows)))
    assert {r["id"] for r in val} == {r["id"] for r in again[1]}
    assert not {r["id"] for r in train} & {r["id"] for r in val}
    assert len(train) + len(val) == 40
    assert {tuple(r["labels"]) for r in val} == {("none",), ("suicidal",)}


def test_near_duplicates_catch_reworded_copies_but_not_new_text():
    test = [_row("I've been writing letters to people. Just in case.")]
    rows = [
        _row("ive been writing letters to people just in case"),
        _row("I have been writing letters to people, just in case!!"),
        _row("my exam is tomorrow and I have not studied"),
    ]
    found = g.near_duplicates(rows, test)
    assert rows[0]["id"] in found and rows[1]["id"] in found and rows[2]["id"] not in found


def test_build_keeps_test_rows_out_of_training_and_validation(tmp_path):
    written, heldout, raw = tmp_path / "written", tmp_path / "heldout", tmp_path / "raw"
    test_text = "aaj raat sab khatam kar dungi, kisi ko mat batana"
    train_rows = [{"text": f"udaas hoon aaj number {i} kuch acha nahi lag raha", "lang": "ur-roman", "labels": ["none"]} for i in range(10)]
    train_rows += [{"text": f"zindagi se thak gayi hoon {i}, ab aur nahi jeena", "lang": "ur-roman", "labels": ["suicidal"]} for i in range(10)]
    train_rows.append({"text": test_text + "!", "lang": "ur-roman", "labels": ["suicidal"]})  # a copy of a test row
    _write(written / "t01.part1.jsonl", train_rows)
    _write(heldout / "h01.part1.jsonl", [{"text": test_text, "lang": "ur-roman", "labels": ["suicidal"]}])
    mt = tmp_path / "mt.jsonl"
    _write(mt, [
        {"id": "m1", "text": "I will end it all tonight, don't tell anyone", "from": "written:t01", "labels": ["suicidal"], "ur": "میں آج رات سب ختم کر دوں گی", "roman": "mein aaj rat sab khtm kar dun gi"},
        {"id": "m2", "text": test_text, "from": "written:t01", "labels": ["suicidal"], "ur": "آج رات سب ختم کر دوں گی، کسی کو مت بتانا", "roman": "aaj rat sab khtm"},
    ])
    splits = g.build_splits(written=written, heldout=heldout, mt_path=mt, raw=raw, n_mh_suicidal=0, n_mh_none=0, n_urdu_mh=0, n_mh_val=0)
    test_norm = {g.norm(r["text"]) for r in splits["test"]}
    assert any(r["source"] == "eval_probe" for r in splits["test"])
    for split in ("train", "val"):
        assert not {g.norm(r["text"]) for r in splits[split]} & test_norm
        assert not any(g.norm(r.get("en_text", "")) in test_norm for r in splits[split])
    assert not {r["id"] for r in splits["train"]} & {r["id"] for r in splits["val"]}
    assert any(r["source"] == "mt" for r in splits["train"])
    assert all(r["commercial_ok"] for s in ("train", "val", "test") for r in splits[s])
    st = g.stats(splits)
    assert st["test"]["rows"] == len(splits["test"]) and "ur-roman|suicidal" in st["train"]["by_lang_label"]


def test_write_splits_produces_what_the_trainer_and_heldout_report_read(tmp_path):
    splits = {"train": [_row("a", ["suicidal"])], "val": [_row("b")], "test": [_row("c", ["abuse"])], "_leaked": []}
    for s in ("train", "val", "test"):
        for r in splits[s]:
            r["split"] = s
    g.write_splits(splits, tmp_path)
    lt = LabeledText.model_validate_json((tmp_path / "labeled.crisis.train.jsonl").read_text(encoding="utf-8").splitlines()[0])
    assert lt.task == "crisis" and lt.labels == ["suicidal"]
    held = json.loads((tmp_path / "heldout.jsonl").read_text(encoding="utf-8"))
    assert held["labels"] == ["abuse"] and held["lang"] == "en"


# --- Thresholds ------------------------------------------------------------------------------------


def test_per_language_calibration_reaches_the_target_in_every_language():
    rng = np.random.default_rng(0)
    labels = list(CRISIS_LABELS)
    c = labels.index("suicidal")
    n = 400
    langs = ["en"] * 200 + ["ur-roman"] * 200
    y = np.zeros((n, len(labels)))
    y[:, labels.index("none")] = 1
    pos = rng.random(n) < 0.4
    y[pos, c], y[pos, labels.index("none")] = 1, 0
    probs = rng.random((n, len(labels))) * 0.3
    # English positives score high, Roman Urdu positives much lower: a pooled threshold would miss them.
    probs[pos & (np.arange(n) < 200), c] = rng.uniform(0.7, 1.0, (pos & (np.arange(n) < 200)).sum())
    probs[pos & (np.arange(n) >= 200), c] = rng.uniform(0.2, 0.6, (pos & (np.arange(n) >= 200)).sum())
    thr = calibrate_by_lang(probs, y, langs, labels, 0.95)
    for lang in ("en", "ur-roman"):
        m = (np.asarray(langs) == lang) & (y[:, c] == 1)
        assert (probs[m, c] >= thr[c]).mean() >= 0.95
    assert thr[labels.index("none")] == 0.5
    assert thr[labels.index("medical")] == 0.5  # no positives: untouched


def test_a_language_with_too_few_positives_does_not_set_the_threshold_alone():
    labels = list(CRISIS_LABELS)
    c = labels.index("self_harm")
    y = np.zeros((31, len(labels)))
    y[:, c] = 1
    probs = np.zeros((31, len(labels)))
    probs[:30, c] = 0.9
    probs[30:, c] = 0.01  # one 'ur' positive scored near zero
    langs = ["en"] * 30 + ["ur"]
    thr = calibrate_by_lang(probs, y, langs, labels, 0.95, min_positives=5)
    assert thr[c] == 0.9  # the pooled 95% point, not dragged to the floor by one row


def test_pos_weights_push_rare_labels_harder_and_stay_capped():
    items = [LabeledText(id=str(i), source="t", text="x", task="crisis", labels=["none"]) for i in range(90)]
    items += [LabeledText(id=f"s{i}", source="t", text="x", task="crisis", labels=["suicidal"]) for i in range(10)]
    w = pos_weights(items, list(CRISIS_LABELS))
    assert torch.isclose(w[1], torch.tensor(3.0))  # sqrt(90/10)
    assert w[CRISIS_LABELS.index("medical")] == 10.0  # no positives: the cap
    assert w[0] == 1.0  # 'none' is the majority: floor of 1


def test_class_lang_report_gives_recall_and_precision_per_language():
    rows = [
        {"lang": "en", "labels": ["suicidal"]},
        {"lang": "en", "labels": ["suicidal", "self_harm"]},
        {"lang": "en", "labels": ["none"]},
        {"lang": "ur", "labels": ["abuse"]},
        {"lang": "ur", "labels": ["none"]},
    ]
    pred = [{"suicidal"}, {"suicidal"}, {"suicidal"}, {"sexual_violence"}, set()]
    r = class_lang_report(rows, pred)
    assert r["en"]["labels"]["suicidal"] == {"n": 2, "recall": 1.0, "detect_recall": 1.0, "precision": 0.667, "fired": 3}
    assert r["en"]["labels"]["self_harm"]["recall"] == 0.0 and r["en"]["labels"]["self_harm"]["detect_recall"] == 1.0
    assert r["ur"]["labels"]["abuse"]["recall"] == 0.0 and r["ur"]["any_crisis"]["recall"] == 1.0
    assert r["en"]["any_crisis"]["false_alarm_rate"] == 1.0 and r["ur"]["any_crisis"]["false_alarm_rate"] == 0.0
    assert r["all"]["any_crisis"]["n"] == 3
