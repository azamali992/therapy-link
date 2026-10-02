import json
from pathlib import Path

import pytest

from therapylink_ml.export.tokenizer_reference import EXTRA, PROBES, probe_texts

# Written by `tokenizer_reference dump` and copied into the app (gitignored, so often absent).
FIXTURE = Path(__file__).resolve().parents[2] / "app" / "test" / "fixtures" / "tokenizer_reference.json"


def _texts(path: Path) -> list[str]:
    with path.open(encoding="utf-8") as fh:
        return [json.loads(line)["text"] for line in fh if line.strip()]


def test_draft_probes_are_left_out():
    drafts = sorted(PROBES.glob("*_draft.jsonl"))
    assert drafts, "expected at least one draft probe file to exercise the filter"
    collected = set(probe_texts())
    for f in drafts:
        assert not collected & set(_texts(f)), f.name
    released = [t for f in sorted(PROBES.glob("*.jsonl")) if not f.name.endswith("_draft.jsonl") for t in _texts(f)]
    assert probe_texts() == released


def test_a_new_draft_file_does_not_change_the_texts(tmp_path):
    (tmp_path / "safety.jsonl").write_text(json.dumps({"text": "released"}) + "\n", encoding="utf-8")
    (tmp_path / "multiturn_draft.jsonl").write_text(json.dumps({"text": "draft"}) + "\n", encoding="utf-8")
    assert probe_texts(tmp_path) == ["released"]


@pytest.mark.skipif(not FIXTURE.exists(), reason="app/test/fixtures/tokenizer_reference.json not generated here")
def test_the_app_fixture_matches_the_released_probes():
    cases = json.loads(FIXTURE.read_text(encoding="utf-8"))["cases"]
    texts = [c["text"] for c in cases]
    assert texts[: len(EXTRA)] == EXTRA
    assert texts[len(EXTRA) :] == probe_texts()
