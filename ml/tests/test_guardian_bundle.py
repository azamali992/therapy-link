import json
import re
from pathlib import Path

import numpy as np

from therapylink_ml.export import guardian_bundle as b
from therapylink_ml.train.guardian import CRISIS_LABELS, keyword_kind

ONNX_GUARDIAN = Path(__file__).resolve().parents[2] / "app" / "lib" / "core" / "ml" / "onnx_guardian.dart"


def test_the_bundle_ships_exactly_the_files_the_app_downloads_and_verifies():
    source = ONNX_GUARDIAN.read_text(encoding="utf-8")
    m = re.search(r"const _files = \[(.*?)\];", source)
    assert m, "onnx_guardian.dart no longer declares _files"
    assert tuple(re.findall(r"'([^']+)'", m.group(1))) == b.APP_FILES
    assert "const _verifiedMarker = 'verified.json'" in source


def test_dart_define_round_trips_through_the_apps_parser(tmp_path):
    hashes = {}
    for f in b.APP_FILES:
        (tmp_path / f).write_bytes(f.encode())
        hashes[f] = b.sha256(tmp_path / f)
    define = b.dart_define(hashes)
    # The parsing _parseHashes does in onnx_guardian.dart.
    parsed = {p[: p.index(":")].strip(): p[p.index(":") + 1 :].strip().lower() for p in define.split(",") if ":" in p}
    assert parsed == hashes
    assert all(len(h) == 64 for h in hashes.values())


def test_canaries_include_every_language_and_both_verdicts():
    assert {c["lang"] for c in b.CANARIES} == {"en", "ur-roman", "ur"}
    for lang in ("en", "ur-roman", "ur"):
        assert {c["crisis"] for c in b.CANARIES if c["lang"] == lang} == {True, False}
    # The app's own three canaries stay in the list, so the bundle checks what the app checks.
    source = ONNX_GUARDIAN.read_text(encoding="utf-8")
    for c in b.CANARIES[:3]:
        assert c["text"].replace("'", "") in source.replace("\\'", "").replace("'", "")


def test_the_keyword_floor_agrees_with_the_crisis_canaries():
    # A canary the floor already flags still tests the model: the bundle checks the model's verdict alone.
    for c in b.CANARIES:
        if not c["crisis"]:
            assert keyword_kind(c["text"]) is None, c["text"]


def test_sigmoid_and_label_order():
    assert np.allclose(b.sigmoid(np.array([0.0])), [0.5])
    assert len(CRISIS_LABELS) == 8 and CRISIS_LABELS[0] == "none"
    assert json.loads(json.dumps(b.CANARIES, ensure_ascii=False)) == b.CANARIES
