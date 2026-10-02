from __future__ import annotations

import json
from collections.abc import Callable, Iterable, Iterator
from pathlib import Path

from rich.console import Console
from rich.progress import track

ML_ROOT = Path(__file__).resolve().parents[2]
URDU_DIR = ML_ROOT / "data" / "urdu"
PROCESSED = ML_ROOT / "data" / "processed"
console = Console()


def read_jsonl(path: Path) -> Iterator[dict]:
    with path.open(encoding="utf-8") as f:
        for line in f:
            if line.strip():
                yield json.loads(line)


def append_jsonl(path: Path, row: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def done_ids(path: Path, key: str = "id") -> set[str]:
    return {r[key] for r in read_jsonl(path)} if path.exists() else set()


def run_resumable(
    rows: Iterable[dict],
    out: Path,
    fn: Callable[[dict], dict | None],
    *,
    key: str = "id",
    label: str = "processing",
) -> tuple[int, int]:
    """Apply fn to each row not already present in `out`, appending results as they complete."""
    seen = done_ids(out, key)
    todo = [r for r in rows if r[key] not in seen]
    done = skipped = 0
    for row in track(todo, description=label):
        result = fn(row)
        if result is None:
            skipped += 1
            continue
        append_jsonl(out, result)
        done += 1
    console.print(f"{label}: {done} written, {skipped} skipped, {len(seen)} already present → {out}")
    return done, skipped
