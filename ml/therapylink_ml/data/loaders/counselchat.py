from __future__ import annotations

from collections.abc import Iterator

from therapylink_ml.data.hf import load_hf
from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import Conversation, Message, clean_text, stable_id

HF_ID = "nbertagnolli/counsel-chat"


def load() -> Iterator[Conversation]:
    ds = load_hf(HF_ID, split="train")
    for i, row in enumerate(ds):
        title = clean_text(str(row.get("questionTitle") or ""))
        body = clean_text(str(row.get("questionText") or ""))
        answer = clean_text(str(row.get("answerText") or ""))
        question = f"{title}\n\n{body}".strip() if body and body != title else (title or body)
        if len(question) < 8 or len(answer) < 40:
            continue
        upvotes = row.get("upvotes")
        yield Conversation(
            id=stable_id(HF_ID, str(row.get("questionID", i)), answer[:64]),
            source="counselchat",
            lang="en",
            messages=[
                Message(role="user", content=question),
                Message(role="assistant", content=answer),
            ],
            tags=[f"topic:{row.get('topic')}"] if row.get("topic") else [],
            quality=float(upvotes) if isinstance(upvotes, (int, float)) else None,
            synthetic=False,
        )


register(
    DatasetInfo(
        key="counselchat",
        kind="conversation",
        license="Scraped from counselchat.com — verify terms before redistribution",
        commercial_ok=False,
        location=f"hf:{HF_ID}",
        citation="Bertagnolli, Counsel Chat: Bootstrapping High-Quality Therapy Data, 2020",
        loader=load,
        synthetic=False,
        notes="Licensed-therapist answers to public questions. quality = upvotes.",
    )
)
