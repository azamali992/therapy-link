"""Shared bits for the training scripts: the smoke subset, multi-label targets, a dev scorer."""

from __future__ import annotations

import json
import random
from collections import defaultdict
from pathlib import Path

import numpy as np

from urduguard import taxonomy

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data" / "build"
TARGET_LABELS = [l for l in taxonomy.LABELS if l != "benign"]  # benign is the all-zero vector


def read(path: Path) -> list[dict]:
    return [json.loads(l) for l in path.read_text(encoding="utf-8").split("\n") if l.strip()]


def smoke_subset(rows: list[dict], n: int, seed: int = 13) -> list[dict]:
    """About n rows, spread evenly over (form, first label) cells so every label and form is present."""
    if n <= 0:  # every row, shuffled
        rows = list(rows)
        random.Random(seed).shuffle(rows)
        return rows
    cells: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for r in rows:
        cells[(r["form"], r["labels"][0])].append(r)
    rng = random.Random(seed)
    per = max(1, n // len(cells))
    out = []
    for k in sorted(cells):
        c = cells[k]
        rng.shuffle(c)
        out += c[:per]
    rng.shuffle(out)
    return out


def targets(rows: list[dict]) -> np.ndarray:
    y = np.zeros((len(rows), len(TARGET_LABELS)), dtype=np.float32)
    for i, r in enumerate(rows):
        for l in r["labels"]:
            if l in TARGET_LABELS:
                y[i, TARGET_LABELS.index(l)] = 1.0
    return y


def dev_report(rows: list[dict], probs: np.ndarray, threshold: float = 0.5) -> dict:
    """Per-form catch rate on protective rows and false-alarm rate on benign rows at one threshold,
    plus per-label F1. The eval harness is the real judge; this is the training-time glance."""
    y = targets(rows)
    pred = probs >= threshold
    prot_idx = [TARGET_LABELS.index(l) for l in taxonomy.PROTECTIVE]
    flagged = pred[:, prot_idx].any(axis=1)
    out: dict = {"per_form": {}, "per_label": {}}
    forms = sorted({r["form"] for r in rows})
    for f in forms:
        idx = [i for i, r in enumerate(rows) if r["form"] == f]
        prot = [i for i in idx if y[i, prot_idx].any()]
        ben = [i for i in idx if r_is_benign(rows[i])]
        out["per_form"][f] = {
            "n_protective": len(prot), "catch_rate": float(flagged[prot].mean()) if prot else None,
            "n_benign": len(ben), "false_alarm_rate": float(flagged[ben].mean()) if ben else None,
        }
    for j, l in enumerate(TARGET_LABELS):
        tp = float((pred[:, j] & (y[:, j] == 1)).sum())
        fp = float((pred[:, j] & (y[:, j] == 0)).sum())
        fn = float((~pred[:, j] & (y[:, j] == 1)).sum())
        p = tp / (tp + fp) if tp + fp else 0.0
        r = tp / (tp + fn) if tp + fn else 0.0
        out["per_label"][l] = {"n": int(y[:, j].sum()), "precision": round(p, 3), "recall": round(r, 3), "f1": round(2 * p * r / (p + r), 3) if p + r else 0.0}
    return out


def r_is_benign(r: dict) -> bool:
    return r["labels"] == ["benign"]
