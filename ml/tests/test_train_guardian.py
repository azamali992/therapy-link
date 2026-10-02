import json
import re
from pathlib import Path

import pytest

from therapylink_ml.schema import LabeledText, stable_id
from therapylink_ml.train import guardian
from therapylink_ml.train.guardian import (
    CRISIS_LABELS,
    TaskData,
    authored_crisis_texts,
    below,
    keyword_kind,
    read_heldout,
    recall_report,
    split_authored,
)

APP_GUARDIAN = Path(__file__).resolve().parents[2] / "app" / "lib" / "core" / "ml" / "guardian.dart"
PROBES = Path(guardian.__file__).resolve().parents[1] / "eval" / "probes" / "safety.jsonl"


# --- Parity with the app ---------------------------------------------------------------------------

_LITERAL = re.compile(r"""(r?)('|")((?:\\.|(?!\2).)*)\2""")


def _dart_string(expr: str, consts: dict[str, str]) -> str:
    """Concatenate the adjacent string literals in a Dart expression, resolving $name interpolation."""
    expr = "\n".join(line for line in expr.splitlines() if not line.strip().startswith("//"))
    out = []
    for raw, _, body in _LITERAL.findall(expr):
        if not raw:
            body = re.sub(r"\$(\w+)", lambda m: consts[m.group(1)], body)
        out.append(body)
    return "".join(out)


def _dart_patterns() -> dict[str, str]:
    source = APP_GUARDIAN.read_text(encoding="utf-8")
    consts: dict[str, str] = {}
    m = re.search(r"static const _someone\s*=\s*(.*?);", source, re.S)
    if m:
        consts["_someone"] = _dart_string(m.group(1), consts)
    found = {}
    for name in ("crisisPattern", "sexualPattern", "abusePattern", "_minor"):
        m = re.search(rf"static final {name} = RegExp\(\s*(.*?),\s*caseSensitive: false", source, re.S)
        if m:
            found[name] = _dart_string(m.group(1), consts)
    return {"_someone": consts.get("_someone"), **found}


def test_keyword_floor_mirrors_the_app_exactly():
    dart = _dart_patterns()
    if "crisisPattern" not in dart:
        pytest.skip("guardian.dart still has the pre-widening HeuristicGuardian; the app-crisis stream's list is not merged yet")
    assert dart["_someone"] == guardian.SOMEONE
    assert dart["crisisPattern"] == guardian.CRISIS_SOURCE
    assert dart["sexualPattern"] == guardian.SEXUAL_SOURCE
    assert dart["abusePattern"] == guardian.ABUSE_SOURCE
    assert dart["_minor"] == guardian.MINOR_SOURCE


def test_the_dart_parser_reads_raw_and_interpolated_strings():
    expr = "r'(a|' '$_x' r'\\b)' // trailing\n  // a comment with 'quotes'\n r\"(it's)\""
    assert _dart_string(expr, {"_x": "b"}) == "(a|b\\b)(it's)"


# --- What the floor catches --------------------------------------------------------------------------


@pytest.mark.parametrize(
    "text, kind",
    [
        ("I want to end my life", "suicidal"),
        ("main marna chahti hoon", "suicidal"),
        ("main marna chahta hoon", "suicidal"),
        ("dil karta hai mar jaun", "suicidal"),
        ("I don't want to live anymore", "suicidal"),
        ("میں خودکشی کے بارے میں سوچ رہا ہوں", "suicidal"),
        ("I think I'm going to hurt myself tonight", "suicidal"),
        ("my husband hits me when he is angry", "abuse"),
        ("shohar mujhe maarta hai", "abuse"),
        ("I'm 13 and my uncle touched me", "child"),
        ("he raped me last year", "sexual_violence"),
    ],
)
def test_keyword_floor_catches(text, kind):
    assert keyword_kind(text) == kind


@pytest.mark.parametrize(
    "text",
    [
        "this exam is killing me",
        "hum mar gaye hanste hanste",
        "your message really touched me",
        "it hits me how alone I've been",
        "I used to abuse alcohol but I'm sober now",
        "yeh gaana zeher hai yaar",
        "jaan le ke kya karoge, bas chhodo",
    ],
)
def test_keyword_floor_leaves_idioms_alone(text):
    assert keyword_kind(text) is None


# --- Guardian v1 data and report ---------------------------------------------------------------------


def test_the_crisis_head_is_the_v1_multilabel_set():
    assert CRISIS_LABELS == ("none", "suicidal", "self_harm", "abuse", "child", "sexual_violence", "harm_to_others", "medical")


def test_every_authored_row_maps_to_crisis_labels_and_everyday_rows_are_negatives():
    items = authored_crisis_texts(include_pending=True)
    assert items and all(set(it.labels) <= set(CRISIS_LABELS) for it in items)
    labels = {lab for it in items for lab in it.labels}
    assert {"none", "suicidal", "self_harm", "abuse", "sexual_violence", "child"} <= labels
    assert {it.lang for it in items if it.labels != ["none"]} >= {"en", "ur-roman", "mixed"}


def test_a_multi_turn_crisis_row_is_labelled_on_the_turn_that_carries_the_risk():
    items = {it.id: it for it in authored_crisis_texts(include_pending=True)}

    def item(row_id):
        return items[stable_id("tl_authored", "crisis", row_id)]

    assert "family would manage better without me" in item("en-crisis-017").text
    assert item("en-crisis-017").labels == ["suicidal"]
    assert "maara" in item("mx-crisis-004").text and "abuse" in item("mx-crisis-004").labels
    assert "Work has been fine" not in item("rl-ind-en-04").text
    texts = {it.text for it in items.values() if it.labels != ["none"]}
    assert "I've been having a rough time since losing my job." not in texts


def test_authored_examples_give_every_repeated_label_set_a_validation_positive():
    items = authored_crisis_texts()
    train, val = split_authored(items)
    assert sorted(it.id for it in train + val) == sorted(it.id for it in items)
    assert not {it.id for it in train} & {it.id for it in val}
    again = split_authored(list(reversed(items)))
    assert {it.id for it in val} == {it.id for it in again[1]}  # order-independent
    val_labels = {lab for it in val for lab in it.labels}
    assert {"none", "suicidal", "abuse", "child", "sexual_violence", "self_harm"} <= val_labels


def test_authored_validation_items_reach_the_val_split(tmp_path):
    def lt(i, labels):
        return LabeledText(id=f"x{i}", source="t", lang="en", text=f"t{i}", task="crisis", labels=labels)

    (tmp_path / "labeled.crisis.train.jsonl").write_text(lt(0, ["suicidal"]).model_dump_json() + "\n", encoding="utf-8")
    td = TaskData.load("crisis", tmp_path, [lt(1, ["abuse"])], [lt(2, ["abuse"])])
    assert [it.id for it in td.val] == ["x2"] and {it.id for it in td.train} == {"x0", "x1"}


def test_heldout_file_must_not_be_the_tuning_probes(tmp_path):
    probe = json.loads(PROBES.read_text(encoding="utf-8").splitlines()[0])
    bad = tmp_path / "bad.jsonl"
    bad.write_text(json.dumps({"id": "x", "text": probe["text"], "lang": "en", "labels": ["suicidal"]}) + "\n", encoding="utf-8")
    with pytest.raises(ValueError, match="tuning probe"):
        read_heldout(bad, PROBES)
    wrong = tmp_path / "wrong.jsonl"
    wrong.write_text(json.dumps({"id": "y", "text": "something new", "lang": "en", "labels": ["suicide"]}) + "\n", encoding="utf-8")
    with pytest.raises(ValueError, match="labels must be"):
        read_heldout(wrong, PROBES)


def test_recall_report_splits_by_language_and_category():
    rows = [
        {"text": "a", "lang": "en", "labels": ["suicidal"]},
        {"text": "b", "lang": "ur-roman", "labels": ["suicidal"]},
        {"text": "c", "lang": "ur-roman", "labels": ["abuse", "child"]},
        {"text": "d", "lang": "en", "labels": ["none"]},
        {"text": "e", "lang": "ur-roman", "labels": ["none"]},
    ]
    predicted = [{"suicidal"}, set(), {"abuse"}, {"none"}, {"self_harm"}]
    report = recall_report(rows, predicted)
    r = report["recall"]
    assert r["all"] == {"n": 3, "detect": 0.667, "exact": 0.333}
    assert r["lang:en"]["detect"] == 1.0 and r["lang:ur-roman"]["detect"] == 0.5
    assert r["category:child"] == {"n": 1, "detect": 1.0, "exact": 0.0}
    assert report["false_alarm"] == {"en": {"n": 1, "rate": 0.0}, "ur-roman": {"n": 1, "rate": 1.0}}
    assert "lang:ur-roman 50% (n=2)" in below(report, 0.95) and not any(g.startswith("lang:en") for g in below(report, 0.95))
