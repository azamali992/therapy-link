from __future__ import annotations

import csv
import io
from collections import defaultdict
from collections.abc import Iterator

import requests

from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import Conversation, Message, clean_text, normalise_messages, stable_id

CSV_URL = "https://raw.githubusercontent.com/uccollab/AnnoMI/main/AnnoMI-full.csv"

_ROLE = {"therapist": "assistant", "client": "user"}


def _fetch_rows() -> list[dict[str, str]]:
    resp = requests.get(CSV_URL, timeout=60)
    resp.raise_for_status()
    return list(csv.DictReader(io.StringIO(resp.text)))


def load() -> Iterator[Conversation]:
    by_transcript: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in _fetch_rows():
        by_transcript[row["transcript_id"]].append(row)

    for tid, rows in by_transcript.items():
        rows.sort(key=lambda r: int(r.get("utterance_id") or 0))
        messages: list[Message] = []
        for r in rows:
            role = _ROLE.get(r.get("interlocutor", "").strip().lower())
            text = clean_text(r.get("utterance_text") or "")
            if not role or not text:
                continue
            strategy = (r.get("main_therapist_behaviour") or "").strip() or None
            messages.append(Message(role=role, content=text, strategy=strategy if role == "assistant" else None))
        messages = normalise_messages(messages)
        if len(messages) < 2:
            continue
        mi_quality = (rows[0].get("mi_quality") or "").strip().lower()
        topic = (rows[0].get("topic") or "").strip()
        yield Conversation(
            id=stable_id(CSV_URL, tid),
            source="annomi",
            lang="en",
            messages=messages,
            tags=[f"topic:{topic}"] if topic else [],
            quality={"high": 1.0, "low": 0.0}.get(mi_quality),
            synthetic=False,
        )


register(
    DatasetInfo(
        key="annomi",
        kind="conversation",
        license="CC BY 4.0",
        commercial_ok=True,
        location=CSV_URL,
        citation="Wu et al., AnnoMI: A Dataset of Expert-Annotated Counselling Dialogues, ICASSP 2022",
        loader=load,
        synthetic=False,
        notes="133 motivational-interviewing transcripts rated high/low quality (quality=1.0/0.0). "
        "Low-quality transcripts are the rejected side of DPO pairs, not noise to drop.",
    )
)
