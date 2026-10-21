"""Refuse any training set that contains an item from the evaluation set.

The evaluation set is the Aegis 2.0 test split (nvidia/Aegis-AI-Content-Safety-Dataset-2.0, test.json),
in any language: IndicGuard (l3cube-pune/IndicGuard) translated the same ids, so its Urdu/test.json and
English/test.json are banned as well. Every banned prompt is hashed after normalisation (lowercase,
whitespace collapsed) and the hashes are committed in hashes/eval_exclusion.json, so CI can run the check
without the raw data. Banned ids are committed too.

    python -I guardian/data/exclusion.py --rebuild            # from raw/ (needs download.py to have run)
    python -I guardian/data/exclusion.py build/train.jsonl    # exit 1 if any row is banned

Hashing is one-way: the committed file does not reveal the test prompts.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
EXCLUSION = HERE / "hashes" / "eval_exclusion.json"

# Files whose every prompt is an evaluation item. Add a path here, never remove one.
EVAL_FILES = (
    "aegis2/test.json",
    "indicguard/English/test.json",
    "indicguard/Urdu/test.json",
)
_WS = re.compile(r"\s+")


def normalise(text: str) -> str:
    return _WS.sub(" ", text.strip().lower())


def text_hash(text: str) -> str:
    return hashlib.sha256(normalise(text).encode("utf-8")).hexdigest()


def _rows(path: Path) -> list[dict]:
    raw = path.read_text(encoding="utf-8")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return [json.loads(line) for line in raw.splitlines() if line.strip()]


def rebuild() -> dict:
    hashes: set[str] = set()
    ids: set[str] = set()
    per_file = {}
    for rel in EVAL_FILES:
        rows = _rows(RAW / rel)
        n = 0
        for r in rows:
            ids.add(str(r["id"]))
            for key in ("prompt", "response"):
                t = r.get(key)
                if t and t != "REDACTED":
                    hashes.add(text_hash(t))
                    n += 1
        per_file[rel] = {"rows": len(rows), "texts_hashed": n}
    out = {"files": per_file, "ids": sorted(ids), "text_sha256": sorted(hashes)}
    EXCLUSION.parent.mkdir(exist_ok=True)
    EXCLUSION.write_text(json.dumps(out, indent=0) + "\n", encoding="utf-8")
    return out


def load() -> tuple[set[str], set[str]]:
    d = json.loads(EXCLUSION.read_text(encoding="utf-8"))
    return set(d["ids"]), set(d["text_sha256"])


def banned(rows: list[dict], ids: set[str], hashes: set[str]) -> list[str]:
    """Row ids that are evaluation items, by id or by normalised text (prompt text or derived text)."""
    hits = []
    for r in rows:
        src_id = str(r.get("provenance", {}).get("source_id", r.get("id", "")))
        texts = [r.get("text", "")]
        src_text = r.get("provenance", {}).get("source_text")
        if src_text:
            texts.append(src_text)
        if src_id in ids or any(text_hash(t) in hashes for t in texts if t):
            hits.append(str(r.get("id")))
    return hits


def check_file(path: Path) -> None:
    ids, hashes = load()
    # split("\n"), not splitlines(): prompts can contain U+2028, which splitlines treats as a line break
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").split("\n") if line.strip()]
    hits = banned(rows, ids, hashes)
    if hits:
        raise SystemExit(f"{path}: {len(hits)} rows are evaluation items, e.g. {hits[:5]}. Refusing.")
    print(f"{path}: {len(rows)} rows, none banned")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--rebuild"]:
        out = rebuild()
        print({k: v for k, v in out["files"].items()}, "ids", len(out["ids"]), "hashes", len(out["text_sha256"]))
    else:
        for a in args:
            check_file(Path(a))
