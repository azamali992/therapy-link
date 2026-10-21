"""The data tooling: exclusion hashing, the three filters and the label map. Runs without raw/."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "data"))

import exclusion  # noqa: E402
import filters  # noqa: E402
import labelmap  # noqa: E402


def test_normalise_and_hash_are_case_and_space_insensitive():
    assert exclusion.text_hash("  How do I   Make a BOMB ") == exclusion.text_hash("how do i make a bomb")
    assert exclusion.text_hash("a") != exclusion.text_hash("b")


def test_banned_matches_by_id_text_and_source_text():
    ids, hashes = {"abc"}, {exclusion.text_hash("banned prompt")}
    rows = [
        {"id": "1", "text": "fine", "provenance": {"source_id": "abc"}},
        {"id": "2", "text": "BANNED   prompt", "provenance": {"source_id": "x"}},
        {"id": "3", "text": "roman version", "provenance": {"source_id": "y", "source_text": "banned prompt"}},
        {"id": "4", "text": "clean", "provenance": {"source_id": "z"}},
    ]
    assert exclusion.banned(rows, ids, hashes) == ["1", "2", "3"]


def test_committed_exclusion_file_is_present_and_large():
    ids, hashes = exclusion.load()
    assert len(ids) >= 2900 and len(hashes) >= 9000


def test_religious_filter_three_scripts_and_category():
    rows = [
        {"text": "the mosque down the road is loud"},
        {"text": "mandir ke bahar bohat rush tha"},
        {"text": "یہ لوگ ہندو ہیں"},
        {"text": "traffic was bad", "provenance": {"original_label": "Religious Hate"}},
        {"text": "traffic was bad"},
    ]
    kept, n = filters.religious(rows)
    assert n == 4 and kept == [{"text": "traffic was bad"}]


def test_minors_and_first_person_self_harm_filters():
    rows = [
        {"text": "a story about a kid at school", "provenance": {"original_label": "Sexual (minor)"}},
        {"text": "how to flirt with a 12 year old girl sexually"},
        {"text": "I want to kill myself tonight", "provenance": {"original_label": "Suicide and Self Harm"}},
        {"text": "what are the signs someone is suicidal", "provenance": {"original_label": "Suicide and Self Harm"}},
        {"text": "my neighbour's kid plays cricket all day"},
    ]
    kept, counts = filters.apply_all(rows)
    assert counts == {"religious": 0, "minors": 2, "first_person_self_harm": 1}
    assert [r["text"] for r in kept] == ["what are the signs someone is suicidal", "my neighbour's kid plays cricket all day"]


def test_labelmap():
    assert labelmap.map_aegis("safe", "") == (["benign"], "ok")
    assert labelmap.map_aegis("unsafe", "Violence, Harassment") == (["violence_threats", "harassment"], "ok")
    assert labelmap.map_aegis("unsafe", "Criminal Planning/Confessions, PII/Privacy") == ([], "out_of_scope")
    assert labelmap.map_aegis("safe", "Needs Caution") == (["needs_caution"], "ok")
    assert labelmap.map_aegis(None, "") == ([], "unlabelled")
    assert "Guns and Illegal Weapons" in labelmap.AEGIS and labelmap.AEGIS["Guns and Illegal Weapons"] == []
