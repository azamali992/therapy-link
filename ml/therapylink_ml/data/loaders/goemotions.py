from __future__ import annotations

from collections.abc import Iterator

from therapylink_ml.data.hf import load_hf
from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import LabeledText, clean_text, stable_id

HF_ID = "google-research-datasets/go_emotions"


def load() -> Iterator[LabeledText]:
    ds = load_hf(HF_ID, "simplified")
    names = ds["train"].features["labels"].feature.names
    for split_name in ds:
        for row in ds[split_name]:
            text = clean_text(row["text"])
            if not text:
                continue
            yield LabeledText(
                id=stable_id(HF_ID, row["id"]),
                source="goemotions",
                lang="en",
                text=text,
                task="emotion",
                labels=[names[i] for i in row["labels"]],
                split={"validation": "val"}.get(split_name, split_name),
            )


register(
    DatasetInfo(
        key="goemotions",
        kind="labeled",
        license="Apache 2.0",
        commercial_ok=True,
        location=f"hf:{HF_ID}",
        citation="Demszky et al., GoEmotions, ACL 2020",
        loader=load,
        synthetic=False,
        notes="58k Reddit comments, 27 emotions + neutral, multi-label. Trains Guardian's emotion head.",
    )
)
