from __future__ import annotations

from collections.abc import Iterator

from therapylink_ml.data.hf import load_hf
from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import Conversation, Message, clean_text, stable_id

HF_ID = "ShenLab/MentalChat16K"


def load() -> Iterator[Conversation]:
    ds = load_hf(HF_ID, split="train")
    for i, row in enumerate(ds):
        user = clean_text(str(row.get("input") or ""))
        assistant = clean_text(str(row.get("output") or ""))
        if len(user) < 8 or len(assistant) < 20:
            continue
        yield Conversation(
            id=stable_id(HF_ID, str(i), user[:64]),
            source="mentalchat16k",
            lang="en",
            messages=[
                Message(role="user", content=user),
                Message(role="assistant", content=assistant),
            ],
            synthetic=None,
        )


register(
    DatasetInfo(
        key="mentalchat16k",
        kind="conversation",
        license="MIT",
        commercial_ok=True,
        location=f"hf:{HF_ID}",
        citation="Xu et al., MentalChat16K, KDD 2025. arXiv:2503.13509",
        loader=load,
        synthetic=None,
        notes="16,084 single-turn pairs: ~9.8k GPT-3.5-generated + ~6.3k from PISCES clinical-trial "
        "transcripts. Per-row provenance is not exposed, so synthetic is left unknown.",
    )
)
