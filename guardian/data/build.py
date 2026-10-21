"""Build the training mix from the downloaded sources and write the manifest.

    python -I guardian/data/build.py                 # writes build/{train,val}.jsonl, build/stats.json, MANIFEST.md
    python -I guardian/data/build.py --no-roman      # skip the transliterated Roman Urdu rows

Order of operations, fixed on purpose:
  load raw rows -> map labels (labelmap.py) -> filters (religious, minors, first-person self-harm) ->
  Aegis-test exclusion (exclusion.py) -> dedupe -> Roman Urdu from Urdu script (translit.py) -> write.
Nothing is written to build/ until the filters and the exclusion check have run, so no file on disk ever
holds a filtered row. Every row carries a provenance block.
"""

from __future__ import annotations

import hashlib
import json
import sys
from collections import Counter
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "src"))

import exclusion  # noqa: E402
import filters  # noqa: E402
import labelmap  # noqa: E402
from urduguard import taxonomy  # noqa: E402
from urduguard.forms import detect  # noqa: E402

RAW = HERE / "raw"
BUILD = HERE / "build"
SOURCES = json.loads((HERE / "sources.json").read_text(encoding="utf-8"))
SEED = 13


def _rows(path: Path) -> list[dict]:
    raw = path.read_text(encoding="utf-8")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return [json.loads(line) for line in raw.splitlines() if line.strip()]


def _id(*parts: str) -> str:
    return hashlib.sha256("\x1f".join(parts).encode("utf-8")).hexdigest()[:16]


def _row(text: str, labels: list[str], *, source: str, split: str, original: str, labels_from: str, urdu_from: str,
         source_id: str, translator: str | None = None, source_text: str | None = None, form: str | None = None) -> dict:
    taxonomy.validate(labels)
    prov = {
        "source": source, "split": split, "licence": SOURCES[source.split(":")[0]]["licence"], "original_label": original,
        "labels_from": labels_from, "urdu_from": urdu_from, "source_id": source_id,
    }
    if translator:
        prov["translator"] = translator
    if source_text:
        prov["source_text"] = source_text
    return {"id": _id(source, split, source_id, text), "text": text, "form": form or detect(text).form, "labels": labels, "provenance": prov}


def load_aegis(split: str, drops: Counter) -> list[dict]:
    """Aegis prompts only. Responses are model output and not what a guardrail sees first."""
    out = []
    for r in _rows(RAW / "aegis2" / f"{split}.json"):
        if r["prompt"] == "REDACTED" or not r["prompt"].strip():
            drops["aegis2:redacted_or_empty"] += 1
            continue
        labels, why = labelmap.map_aegis(r["prompt_label"], r["violated_categories"])
        if why != "ok":
            drops[f"aegis2:{why}"] += 1
            continue
        out.append(_row(r["prompt"], labels, source="aegis2", split=split, original=r["violated_categories"] or "safe",
                        labels_from="human", urdu_from="none", source_id=r["id"]))
    return out


def load_indicguard_urdu(split: str, drops: Counter) -> list[dict]:
    """IndicGuard Urdu prompts: Google-translated Aegis (Generic) and Hindi-sourced Culture_adaptive rows.
    Jailbreaking rows are dropped (no jailbreak detector). Labels are inherited from the English source."""
    out = []
    for r in _rows(RAW / "indicguard" / "Urdu" / f"{split}.json"):
        if r.get("tag", "").lower().startswith("jail"):
            drops["indicguard:jailbreak"] += 1
            continue
        if not r.get("prompt") or r["prompt"] == "REDACTED" or r.get("prompt_label") is None:
            drops["indicguard:redacted_or_unlabelled"] += 1
            continue
        labels, why = labelmap.map_aegis(r["prompt_label"], r["violated_categories"])
        if why != "ok":
            drops[f"indicguard:{why}"] += 1
            continue
        out.append(_row(r["prompt"], labels, source="indicguard:urdu", split=split, original=r["violated_categories"] or "safe",
                        labels_from="inherited", urdu_from="machine", source_id=str(r["id"]), translator="google-translate", form="ur"))
    return out


def dedupe(rows: list[dict], drops: Counter) -> list[dict]:
    seen, out = set(), []
    for r in rows:
        h = exclusion.text_hash(r["text"])
        if h in seen:
            drops["duplicate_text"] += 1
            continue
        seen.add(h)
        out.append(r)
    return out


def romanise(rows: list[dict], drops: Counter) -> list[dict]:
    """One Roman Urdu row per Urdu-script row, made by translit.make_roman, with full provenance."""
    try:
        import translit
    except ImportError:
        drops["roman:translit_missing"] += 1
        return []
    out = []
    for i, r in enumerate(rows):
        if r["form"] != "ur":
            continue
        made = translit.make_roman(r["text"], seed=SEED + i)
        if not made["text"].strip():
            drops["roman:empty"] += 1
            continue
        prov = dict(r["provenance"], urdu_from="transliterated", source_text=r["text"], **{"translit": made["provenance"]})
        out.append({"id": _id(r["id"], "roman"), "text": made["text"], "form": "roman_ur", "labels": r["labels"], "provenance": prov})
    return out


def stats(rows: list[dict]) -> dict:
    by = Counter()
    for r in rows:
        for l in r["labels"]:
            by[(r["provenance"]["source"], r["form"], l)] += 1
    return {"rows": len(rows), "cells": {"|".join(k): v for k, v in sorted(by.items())}}


def manifest(split_stats: dict, drops: Counter, filter_counts: dict) -> str:
    lines = ["# Data manifest", "", f"Generated by `data/build.py` on {date.today().isoformat()}. Counts only; no row text appears here.", ""]
    lines += ["## Sources", "", "| Source | Licence | Used for | Urdu produced by | Labels from |", "|---|---|---|---|---|"]
    lines += ["| Aegis 2.0 train + validation prompts (`nvidia/Aegis-AI-Content-Safety-Dataset-2.0`) | CC BY 4.0 | train / val | none (English) | human |",
              "| IndicGuard Urdu train + valid prompts (`l3cube-pune/IndicGuard`) | CC BY 4.0 | train / val | Google Translate (machine) | inherited from the English source |",
              "| Roman Urdu rows | derived | train / val | rule transliteration of the IndicGuard Urdu rows (`data/translit.py`) | inherited |", ""]
    lines += ["## Removed before any file was written", "", "| Filter | Rows removed |", "|---|---:|"]
    lines += [f"| {k} | {v} |" for k, v in filter_counts.items()]
    lines += ["", "| Drop reason | Rows |", "|---|---:|"] + [f"| {k} | {v} |" for k, v in sorted(drops.items())] + [""]
    for split, st in split_stats.items():
        lines += [f"## {split}: {st['rows']} rows", "", "| Source | Form | Label | Rows |", "|---|---|---|---:|"]
        lines += [f"| {k.replace('|', ' | ')} | {v} |" for k, v in st["cells"].items()]
        lines.append("")
    lines += ["## Not in this build", "", "- Aegis 2.0 test split and IndicGuard test splits: evaluation only, hashed in `hashes/eval_exclusion.json`.",
              "- Aegis responses: only prompts are used.", "- Any row the religious, minors or first-person self-harm filter matched.",
              "- Any row whose only categories are out of scope (criminal planning, PII, drugs, profanity, fraud, malware, weapons, advice).",
              "- IndicGuard jailbreak rows.", "- No human-written Roman Urdu exists in this build yet. Every Roman Urdu row is transliterated and says so in `provenance.urdu_from`.", ""]
    return "\n".join(lines)


def build(with_roman: bool = True) -> None:
    drops: Counter = Counter()
    splits = {
        "train": load_aegis("train", drops) + load_indicguard_urdu("train", drops),
        "val": load_aegis("validation", drops) + load_indicguard_urdu("valid", drops),
    }
    filter_counts: Counter = Counter()
    ids, hashes = exclusion.load()
    for name in splits:
        rows, counts = filters.apply_all(splits[name])
        filter_counts.update(counts)
        # Upstream Aegis 2.0 ships 243 train prompts whose text also appears in its test split under other
        # ids. They are evaluation items, so they are dropped here and counted; the final file is checked again.
        hits = set(exclusion.banned(rows, ids, hashes))
        drops[f"{name}:eval_duplicate"] += len(hits)
        rows = [r for r in rows if r["id"] not in hits]
        rows = dedupe(rows, drops)
        if with_roman:
            roman = romanise(rows, drops)
            roman, rc = filters.apply_all(roman)  # the filters run again on the derived text
            filter_counts.update({f"roman:{k}": v for k, v in rc.items()})
            if exclusion.banned(roman, ids, hashes):
                raise SystemExit("transliterated rows matched an evaluation item; refusing")
            rows += roman
        if exclusion.banned(rows, ids, hashes):
            raise SystemExit(f"{name}: evaluation items still present after dropping; refusing to write")
        splits[name] = rows
    BUILD.mkdir(exist_ok=True)
    split_stats = {}
    for name, rows in splits.items():
        with (BUILD / f"{name}.jsonl").open("w", encoding="utf-8") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        split_stats[name] = stats(rows)
        print(f"{name}: {len(rows)} rows")
    (BUILD / "stats.json").write_text(json.dumps({"splits": split_stats, "drops": dict(drops), "filters": dict(filter_counts)}, indent=1), encoding="utf-8")
    (HERE / "MANIFEST.md").write_text(manifest(split_stats, drops, dict(filter_counts)), encoding="utf-8")
    print("filters", dict(filter_counts))
    print("drops", dict(drops))


if __name__ == "__main__":
    build(with_roman="--no-roman" not in sys.argv)
