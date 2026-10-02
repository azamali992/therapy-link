from __future__ import annotations

from collections.abc import Iterator

import pandas as pd
from huggingface_hub import hf_hub_download, list_repo_files

from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import LabeledText, clean_text, stable_id

HF_ID = "ourafla/Mental-Health_Text-Classification_Dataset"

_CONDITION = {"suicidal": "suicidal", "depression": "depression", "anxiety": "anxiety", "normal": "normal"}
_TEXT_COLS = ("text", "statement", "post", "content")
_LABEL_COLS = ("status", "label", "class")


def _files() -> dict[str, str]:
    out: dict[str, str] = {}
    for f in list_repo_files(HF_ID, repo_type="dataset"):
        name = f.lower()
        if not name.endswith(".csv") or "feature" in name:
            continue
        out.setdefault("test" if "test" in name else "train", f)
    return out


def _columns(df: pd.DataFrame) -> tuple[str, str]:
    cols = {c.lower(): c for c in df.columns}
    text = next((cols[c] for c in _TEXT_COLS if c in cols), None)
    label = next((cols[c] for c in _LABEL_COLS if c in cols), None)
    if text is None or label is None:
        raise RuntimeError(f"unexpected columns in {HF_ID}: {list(df.columns)}")
    return text, label


def load() -> Iterator[LabeledText]:
    for split, name in _files().items():
        df = pd.read_csv(hf_hub_download(HF_ID, name, repo_type="dataset"))
        text_col, label_col = _columns(df)
        for i, row in df.iterrows():
            text = clean_text(str(row[text_col]))
            status = str(row[label_col]).strip().lower()
            if not text or status not in _CONDITION:
                continue
            rid = f"{name}:{i}"
            yield LabeledText(
                id=stable_id(HF_ID, "condition", rid), source="mh_text", lang="en", text=text,
                task="condition", labels=[_CONDITION[status]], split="test" if split == "test" else None,
            )
            yield LabeledText(
                id=stable_id(HF_ID, "crisis", rid), source="mh_text", lang="en", text=text,
                task="crisis", labels=["suicidal" if status == "suicidal" else "none"], split="test" if split == "test" else None,
            )


register(
    DatasetInfo(
        key="mh_text",
        kind="labeled",
        license="CC BY 4.0",
        commercial_ok=True,
        location=f"hf:{HF_ID}",
        citation="ourafla, Mental-Health Text Classification Dataset (aggregates Kaggle Suicide & Depression "
        "Detection, Sentiment Analysis for Mental Health, and Murarka et al.)",
        loader=load,
        synthetic=False,
        notes="~49k real Reddit posts labelled Suicidal / Depression / Anxiety / Normal, plus a balanced 992-row "
        "test set. Emitted twice: as the 4-class `condition` task and as a binary `crisis` task "
        "(suicidal vs none). Not per-utterance clinical annotation — labels come from the source "
        "subreddit or original dataset.",
    )
)
