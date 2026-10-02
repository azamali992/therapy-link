from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path

import pandas as pd
import requests

from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import LabeledText, clean_text, stable_id

ZENODO_RECORD = "19232922"
API = f"https://zenodo.org/api/records/{ZENODO_RECORD}"
CACHE = Path(__file__).resolve().parents[3] / "data" / "raw" / "urdu_mh"

_LABELS = {"anxiety": "anxiety", "depression": "depression", "depressed": "depression", "neutral": "normal", "normal": "normal"}


def _download() -> list[Path]:
    CACHE.mkdir(parents=True, exist_ok=True)
    rec = requests.get(API, timeout=60)
    rec.raise_for_status()
    paths = []
    for f in rec.json().get("files", []):
        name = f["key"]
        if not name.lower().endswith((".csv", ".xlsx", ".xls", ".tsv", ".json")):
            continue
        dest = CACHE / name
        if not dest.exists():
            with requests.get(f["links"]["self"], stream=True, timeout=300) as r:
                r.raise_for_status()
                with dest.open("wb") as fh:
                    for chunk in r.iter_content(1 << 20):
                        fh.write(chunk)
        paths.append(dest)
    if not paths:
        raise RuntimeError(f"no tabular files found in Zenodo record {ZENODO_RECORD}")
    return paths


def _read_table(path: Path) -> pd.DataFrame:
    suffix = path.suffix.lower()
    if suffix in (".xlsx", ".xls"):
        return pd.read_excel(path)
    if suffix == ".json":
        return pd.read_json(path)
    return pd.read_csv(path, sep="\t" if suffix == ".tsv" else ",", encoding="utf-8", on_bad_lines="skip")


def _pick_columns(df: pd.DataFrame) -> tuple[str, str]:
    label_col = next(
        (c for c in df.columns if df[c].astype(str).str.strip().str.lower().isin(_LABELS).mean() > 0.9),
        None,
    )
    if label_col is None:
        raise RuntimeError(f"no label column with values {sorted(_LABELS)} in {list(df.columns)}")
    text_col = max(
        (c for c in df.columns if c != label_col and pd.api.types.is_string_dtype(df[c])),
        key=lambda c: df[c].astype(str).str.len().mean(),
    )
    return text_col, label_col


def load() -> Iterator[LabeledText]:
    for path in _download():
        df = _read_table(path)
        text_col, label_col = _pick_columns(df)
        for i, row in df.iterrows():
            text = clean_text(str(row[text_col]))
            label = _LABELS.get(str(row[label_col]).strip().lower())
            if not text or not label:
                continue
            yield LabeledText(
                id=stable_id("zenodo", ZENODO_RECORD, path.name, str(i)),
                source="urdu_mh",
                lang="ur",
                text=text,
                task="condition",
                labels=[label],
            )


register(
    DatasetInfo(
        key="urdu_mh",
        kind="labeled",
        license="CC BY 4.0",
        commercial_ok=True,
        location=f"zenodo:{ZENODO_RECORD}",
        citation="A large-scale annotated Urdu corpus and deep learning benchmark for mental health "
        "classification, Scientific Reports 2026. doi:10.5281/zenodo.19232922",
        loader=load,
        lang="ur",
        synthetic=None,
        notes="36,000 tweets in Urdu (Nastaliq) script: anxiety 12,833 / depression 11,617 / neutral 12,543. "
        "~97% is English social-media text machine-translated with opus-mt-en-ur, only ~1,000 are "
        "natively written and expert-annotated. Treat as translationese; Guardian's Urdu-script "
        "recall numbers from it are optimistic until validated on the hand-written eval set.",
    )
)
