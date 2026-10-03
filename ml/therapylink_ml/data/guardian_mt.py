"""Machine-translated Guardian rows: English text → Urdu script (opus-mt-en-ur) → rough Roman Urdu.

The written batches have little Urdu-script text and few Roman Urdu suicide and self-harm rows, so
English rows with known labels are carried across with the repo's own translator
(therapylink_ml/urdu/translate.py) and stage-2 romaniser (urdu/transliterate.py). The labels come
from the English row; translation does not change who is at risk. The output is translationese and
the romanisation is crude on purpose, so these rows are marked `source: mt` and are never used for
validation or testing.

    python -m therapylink_ml.data.guardian_mt run            # resumable; writes data/guardian/mt/
"""

from __future__ import annotations

import json
import random
from pathlib import Path

import typer

from therapylink_ml.data.guardian_v1 import GUARDIAN_DIR, RAW, WRITTEN, crisis_labels
from therapylink_ml.schema import stable_id

MT_DIR = GUARDIAN_DIR / "mt"
app = typer.Typer(add_completion=False, no_args_is_help=True)


@app.callback()
def main() -> None:
    """Keeps `run` a named subcommand."""


def english_sources(n_mh_suicidal: int, n_mh_none: int, max_chars: int, seed: int) -> list[dict]:
    """English rows to translate: every written English row (its own labels), plus short mh_text
    posts. Long Reddit posts translate badly and cost the most, so only short ones are taken."""
    from therapylink_ml.data.guardian_v1 import batch_of
    from therapylink_ml.train.guardian import keyword_kind

    rows = []
    for path in sorted(WRITTEN.glob("t*.jsonl")):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                r = json.loads(line)
                if r["lang"] == "en":
                    rows.append({"text": r["text"], "labels": r["labels"], "from": f"written:{batch_of(path)}", "tag": r.get("tag", "")})
    rng = random.Random(seed)
    suicidal, none = [], []
    mh = RAW / "mh_text.crisis.jsonl"
    if mh.exists():
        for line in mh.read_text(encoding="utf-8").splitlines():
            r = json.loads(line)
            if r.get("split") == "test" or len(r["text"]) > max_chars or len(r["text"]) < 20:
                continue
            if r["labels"] == ["suicidal"]:
                suicidal.append(r["text"])
            elif keyword_kind(r["text"]) is None:
                none.append(r["text"])
    rng.shuffle(suicidal)
    rng.shuffle(none)
    rows += [{"text": t, "labels": ["suicidal"], "from": "mh_text", "tag": "reddit"} for t in suicidal[:n_mh_suicidal]]
    rows += [{"text": t, "labels": ["none"], "from": "mh_text", "tag": "reddit"} for t in none[:n_mh_none]]
    for r in rows:
        r["id"] = stable_id("guardian_mt", r["text"])
        if set(r["labels"]) - set(crisis_labels()):
            raise ValueError(f"bad labels {r['labels']}")
    return rows


@app.command()
def run(
    out: Path = MT_DIR / "translated.jsonl",
    n_mh_suicidal: int = 1500,
    n_mh_none: int = 1200,
    max_chars: int = 320,
    batch: int = 16,
    threads: int = 4,
    seed: int = 13,
) -> None:
    import torch

    from therapylink_ml.urdu.common import run_resumable
    from therapylink_ml.urdu.translate import Translator, _sentences
    from therapylink_ml.urdu.transliterate import romanise

    torch.set_num_threads(threads)
    rows = english_sources(n_mh_suicidal, n_mh_none, max_chars, seed)
    typer.echo(f"{len(rows)} English rows to translate")
    out.parent.mkdir(parents=True, exist_ok=True)
    translate = Translator(device="cpu")

    def fn(r: dict) -> dict:
        ur = " ".join(translate(_sentences(r["text"]), batch=batch))
        return {**r, "ur": ur, "roman": romanise(ur)}

    run_resumable(rows, out, fn, label="guardian en→ur")


if __name__ == "__main__":
    app()
