"""Stage 5: human naturalness rating — blinded sheet out, Krippendorff's α back in."""

from __future__ import annotations

import csv
import json
import random
import statistics
from pathlib import Path

import typer

from therapylink_ml.urdu.common import URDU_DIR, console, read_jsonl

app = typer.Typer(add_completion=False)


@app.command("make-sheet")
def make_sheet(
    source: Path = URDU_DIR / "stage4_verified.jsonl",
    out_dir: Path = URDU_DIR / "rating",
    n: int = 300,
    seed: int = 13,
    include_seed_stage: bool = typer.Option(True, help="Mix in stage-2 seeds as a blind control"),
) -> None:
    """One CSV for raters (text only) and one key file that maps items back to their origin."""
    rng = random.Random(seed)
    turns = [
        (r["id"], i, m)
        for r in read_jsonl(source)
        if r.get("kept")
        for i, m in enumerate(r["messages"])
        if len(m["ur_roman"].split()) >= 4
    ]
    rng.shuffle(turns)
    items: list[dict] = []
    for conv_id, i, m in turns[:n]:
        items.append({"conv_id": conv_id, "turn": i, "stage": "restyled", "text": m["ur_roman"]})
        if include_seed_stage and rng.random() < 0.2:
            items.append({"conv_id": conv_id, "turn": i, "stage": "seed", "text": m["ur_roman_seed"]})
    rng.shuffle(items)
    out_dir.mkdir(parents=True, exist_ok=True)
    with (out_dir / "rating_sheet.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["item", "text", "naturalness_1_to_5", "meaning_clear_yes_no", "comment"])
        for k, it in enumerate(items, 1):
            w.writerow([f"R{k:04d}", it["text"], "", "", ""])
    (out_dir / "rating_key.json").write_text(
        json.dumps({f"R{k:04d}": {k2: v for k2, v in it.items() if k2 != "text"} for k, it in enumerate(items, 1)}, indent=2),
        encoding="utf-8",
    )
    console.print(f"{len(items)} items → {out_dir / 'rating_sheet.csv'} (give each rater their own copy; keep rating_key.json private)")


@app.command()
def alpha(
    sheets: list[Path] = typer.Argument(..., help="One filled rating_sheet.csv per rater"),
    key: Path = URDU_DIR / "rating" / "rating_key.json",
    out: Path = URDU_DIR / "rating" / "results.json",
) -> None:
    """Krippendorff's α (ordinal) across raters plus mean naturalness per stage."""
    import krippendorff
    import numpy as np

    key_map = json.loads(key.read_text(encoding="utf-8"))
    ratings: dict[str, list[float]] = {}
    for sheet in sheets:
        with sheet.open(encoding="utf-8") as f:
            for row in csv.DictReader(f):
                v = row.get("naturalness_1_to_5", "").strip()
                ratings.setdefault(row["item"], []).append(float(v) if v else np.nan)
    items = sorted(ratings)
    n_raters = max(len(v) for v in ratings.values())
    matrix = np.array([[*ratings[i], *([np.nan] * (n_raters - len(ratings[i])))] for i in items]).T
    a = float(krippendorff.alpha(reliability_data=matrix, level_of_measurement="ordinal"))

    by_stage: dict[str, list[float]] = {}
    for i in items:
        vals = [v for v in ratings[i] if not np.isnan(v)]
        if vals:
            by_stage.setdefault(key_map[i]["stage"], []).append(statistics.mean(vals))
    result = {
        "raters": len(sheets),
        "items": len(items),
        "krippendorff_alpha_ordinal": round(a, 3),
        "mean_naturalness": {s: round(statistics.mean(v), 2) for s, v in by_stage.items()},
        "n_per_stage": {s: len(v) for s, v in by_stage.items()},
    }
    out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    console.print(result)


if __name__ == "__main__":
    app()
