from __future__ import annotations

import json
from collections.abc import Iterator
from typing import Any

from therapylink_ml.data.hf import load_hf
from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import Conversation, Message, clean_text, normalise_messages, stable_id

HF_ID = "thu-coai/esconv"

_SPEAKER_ROLE = {"seeker": "user", "usr": "user", "supporter": "assistant", "sys": "assistant"}


def _parse_row(row: dict[str, Any]) -> dict[str, Any] | None:
    if isinstance(row.get("text"), str):
        try:
            return json.loads(row["text"])
        except json.JSONDecodeError:
            return None
    if "dialog" in row:
        return row
    return None


def _strategy(turn: dict[str, Any]) -> str | None:
    ann = turn.get("annotation") or {}
    return ann.get("strategy") or turn.get("strategy")


def _messages(dialog: list[dict[str, Any]]) -> list[Message]:
    out: list[Message] = []
    for turn in dialog:
        role = _SPEAKER_ROLE.get(str(turn.get("speaker", "")).lower())
        text = clean_text(str(turn.get("content") or turn.get("text") or ""))
        if not role or not text:
            continue
        out.append(Message(role=role, content=text, strategy=_strategy(turn) if role == "assistant" else None))
    return normalise_messages(out)


def load() -> Iterator[Conversation]:
    ds = load_hf(HF_ID)
    for split_name in ds:
        for i, row in enumerate(ds[split_name]):
            data = _parse_row(dict(row))
            if not data:
                continue
            messages = _messages(data.get("dialog") or [])
            if len(messages) < 2:
                continue
            tags = [
                f"problem:{data.get('problem_type')}",
                f"emotion:{data.get('emotion_type')}",
            ]
            situation = clean_text(str(data.get("situation") or ""))
            if situation:
                messages[0] = Message(
                    role="user", content=f"{situation}\n\n{messages[0].content}"
                )
            yield Conversation(
                id=stable_id(HF_ID, split_name, str(i)),
                source="esconv",
                lang="en",
                messages=messages,
                tags=[t for t in tags if not t.endswith("None")],
                synthetic=False,
            )


register(
    DatasetInfo(
        key="esconv",
        kind="conversation",
        license="CC BY-NC 4.0",
        commercial_ok=False,
        location=f"hf:{HF_ID}",
        citation="Liu et al., Towards Emotional Support Dialog Systems, ACL 2021. arXiv:2106.01144",
        loader=load,
        synthetic=False,
        notes="1,300 multi-turn crowdworker dialogues; every supporter turn carries a Helping-Skills "
        "strategy label, preserved on Message.strategy.",
    )
)
