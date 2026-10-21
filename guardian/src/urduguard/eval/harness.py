"""Run any guardrail over a manifest-format file and write per-form rates, gaps, intervals and verdicts.

    python -m urduguard.eval.harness --backend hf:Qwen/Qwen3Guard-Gen-0.6B --data build/train.jsonl \
        --forms en --limit 300 --out runs/eval/qwen3guard-0.6b-en

The data file is JSONL rows {id, text, form, labels, provenance{source_id, ...}}. Output: report.json
(rates, gaps, verdicts, counts, backend name, data hash) and report.md. Predictions are written as
{id: flagged} only, never with the text, so a run directory can be shared.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import time
from datetime import date
from pathlib import Path

from . import backends, metrics
from .. import taxonomy


def load_rows(path: Path, forms: list[str] | None, limit: int | None, seed: int = 13) -> list[dict]:
    rows = [json.loads(l) for l in path.read_text(encoding="utf-8").split("\n") if l.strip()]
    if forms:
        rows = [r for r in rows if r["form"] in forms]
    rows = [r for r in rows if metrics.is_protective(r) or metrics.is_benign(r)]  # the gate's two populations
    if limit and len(rows) > limit:
        # keep the pairing: sample item ids, then take every form of each sampled id
        ids = sorted({str(r.get("provenance", {}).get("source_id", r["id"])) for r in rows})
        random.Random(seed).shuffle(ids)
        keep = set(ids[: max(1, limit // max(1, len(forms or [1])))])
        rows = [r for r in rows if str(r.get("provenance", {}).get("source_id", r["id"])) in keep]
    return rows


def run(backend: backends.Backend, rows: list[dict], previous: dict | None = None, resamples: int = 2000) -> dict:
    if isinstance(backend, backends.FixtureBackend):
        backend.ids = [r["id"] for r in rows]
    t0 = time.perf_counter()
    preds = backend.predict([r["text"] for r in rows])
    seconds = time.perf_counter() - t0
    flagged = {r["id"]: p.flagged for r, p in zip(rows, preds)}
    per_form = metrics.rates(rows, flagged)
    gap = metrics.gaps(rows, flagged, resamples=resamples) if "en" in per_form else {}
    per_label = {}
    for label in taxonomy.PROTECTIVE + taxonomy.DESCRIPTIVE:
        pos = [(r, p) for r, p in zip(rows, preds) if label in r["labels"]]
        if pos:
            per_label[label] = {"n": len(pos), "caught_any": sum(p.flagged for _, p in pos) / len(pos),
                                "caught_same_label": sum(label in p.labels for _, p in pos) / len(pos)}
    return {
        "backend": backend.name, "date": date.today().isoformat(), "rows": len(rows), "seconds": round(seconds, 1),
        "per_form": per_form, "gaps": gap, "verdicts": metrics.verdicts(per_form, gap, previous), "per_label": per_label,
        "predictions": flagged, "taxonomy_version": taxonomy.TAXONOMY_VERSION,
    }


def markdown(report: dict) -> str:
    L = [f"# {report['backend']}", "", f"{report['rows']} rows, {report['seconds']} s, {report['date']}.", "",
         "| Form | n protective | catch rate | CI95 | n benign | false-alarm rate | CI95 |", "|---|---:|---:|---|---:|---:|---|"]
    for f, v in report["per_form"].items():
        c, fa = v["catch_rate"], v["false_alarm_rate"]
        L.append(f"| {f} | {v['n_protective']} | {_pct(c['value'])} | {_ci(c['ci95'])} | {v['n_benign']} | {_pct(fa['value'])} | {_ci(fa['ci95'])} |")
    if report["gaps"]:
        L += ["", "| Form | R(EN) - R(f) | CI95 | F(f) - F(EN) | CI95 | R1 | R2 | R3 | R4 |", "|---|---:|---|---:|---|---|---|---|---|"]
        for f, g in report["gaps"].items():
            v = report["verdicts"][f]
            L.append(f"| {f} | {_pts(g['catch_gap']['value'])} | {_ci(g['catch_gap']['ci95'], pts=True)} | {_pts(g['false_alarm_gap']['value'])} | "
                     f"{_ci(g['false_alarm_gap']['ci95'], pts=True)} | {v['R1']['status']} | {v['R2']['status']} | {v['R3']['status']} | {v['R4']['status']} |")
    if report["per_label"]:
        L += ["", "| Label | n | flagged (any) | flagged with the same label |", "|---|---:|---:|---:|"]
        for l, v in report["per_label"].items():
            L.append(f"| {l} | {v['n']} | {_pct(v['caught_any'])} | {_pct(v['caught_same_label'])} |")
    return "\n".join(L) + "\n"


def _pct(x):
    return "n/a" if x is None else f"{100 * x:.1f}%"


def _pts(x):
    return "n/a" if x is None else f"{x:+.1f}"


def _ci(ci, pts=False):
    if ci is None or ci[0] is None or ci[0] != ci[0]:
        return "n/a"
    return f"[{ci[0]:+.1f}, {ci[1]:+.1f}]" if pts else f"[{100 * ci[0]:.1f}, {100 * ci[1]:.1f}]"


def main(argv: list[str] | None = None) -> dict:
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", required=True)
    ap.add_argument("--data", required=True)
    ap.add_argument("--forms", nargs="*")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--out", required=True)
    ap.add_argument("--previous", help="report.json of the last tagged release, for R4")
    ap.add_argument("--resamples", type=int, default=2000)
    a = ap.parse_args(argv)
    rows = load_rows(Path(a.data), a.forms, a.limit)
    previous = json.loads(Path(a.previous).read_text(encoding="utf-8"))["per_form"] if a.previous else None
    report = run(backends.make(a.backend), rows, previous, a.resamples)
    report["data"] = {"path": a.data, "sha256": hashlib.sha256(Path(a.data).read_bytes()).hexdigest()}
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "report.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    (out / "report.md").write_text(markdown(report), encoding="utf-8")
    print(markdown(report))
    return report


if __name__ == "__main__":
    main()
