"""Conversations written for this project to cover what no public dataset does.

None of the public sources shows a counsellor handling a crisis: acknowledging it, then pointing to
real help. v13 inherited that gap and got worse than the base model on safety. These examples fill
it, plus everyday-stress messages that must NOT get a helpline, so crisis handling doesn't turn
into over-reaction. Every line is checked against the eval safety rules by tests/test_authored.py.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path

from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import Conversation, Message, stable_id

AUTHORED_DIR = Path(__file__).resolve().parents[1] / "authored"

# Rows drafted but not yet signed off by the psychologist. They never reach a training corpus by
# accident: the loader skips them unless a build asks for them explicitly (tl-data build
# --include-pending), which is for inspection and dry runs, not for a model that ships.
PENDING = "pending_clinician"
REVIEW_STATUSES = frozenset({PENDING, "approved"})


def is_pending(row: dict) -> bool:
    return row.get("review_status") == PENDING


def rows(include_pending: bool = False) -> Iterator[dict]:
    for path in sorted(AUTHORED_DIR.glob("*.jsonl")):
        with path.open(encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                row = json.loads(line)
                if include_pending or not is_pending(row):
                    yield row


def load(include_pending: bool = False) -> Iterator[Conversation]:
    for r in rows(include_pending):
        yield Conversation(
            id=stable_id("tl_authored", r["id"]),
            source="tl_authored",
            lang=r["lang"],
            messages=[Message(role=m["role"], content=m["content"]) for m in r["messages"]],
            tags=[f"route:{r['route']}", f"category:{r['category']}"] + ([f"review:{PENDING}"] if is_pending(r) else []),
            quality=1.0,
            synthetic=True,
            notes=r.get("notes"),
        )


register(
    DatasetInfo(
        key="tl_authored",
        kind="conversation",
        license="CC-BY-4.0 (written for TherapyLink)",
        commercial_ok=True,
        location="ml/therapylink_ml/data/authored/*.jsonl",
        citation="TherapyLink project, 2026",
        loader=load,
        synthetic=True,
        notes=(
            "Crisis responses (acknowledge, then verified Pakistani helplines: Umang 0311-7786264, "
            "Rescue 1122, Madadgaar 1098) and everyday-stress hard negatives, in English, Roman Urdu "
            "and mixed. AI-drafted, checked against the eval safety rules; not paraphrased from probes."
        ),
        tags=("crisis", "roman-urdu"),
    )
)
