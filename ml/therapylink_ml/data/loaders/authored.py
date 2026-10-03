"""Conversations written for this project to cover what no public dataset does.

None of the public sources shows a counsellor handling a crisis: acknowledging it, then pointing to
real help. v13 inherited that gap and got worse than the base model on safety. These examples fill
it, plus everyday-stress messages that must NOT get a helpline, so crisis handling doesn't turn
into over-reaction. Every line is checked against the eval safety rules by tests/test_authored.py.

Review status of a row (`review_status`):

* ``approved``: signed off by a licensed clinician. Rows with no status are the older crisis set and
  count as approved, as they always have.
* ``ai_clinical_review``: reviewed (and where needed rewritten) by the AI team acting in the
  clinical-lead role, not by a licensed clinician. See docs/clinical/AI_REVIEW_LOG.md. These rows
  are held back exactly like pending ones unless the build opts in with the environment variable
  ``TL_ACCEPT_AI_CLINICAL_REVIEW=1``. Opting in is for internal-testing models only: a model
  trained on them cannot carry a clinician's name in ml/registry.json ``approved_by`` (QA gate
  MG-1) until a licensed clinician has signed the rows and they are moved to ``approved``.
* ``pending_clinician``: drafted, not reviewed. Never trained on.
"""

from __future__ import annotations

import json
import os
from collections.abc import Iterator
from pathlib import Path

from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import Conversation, Message, stable_id

AUTHORED_DIR = Path(__file__).resolve().parents[1] / "authored"

# Rows drafted but not yet signed off by the psychologist. They never reach a training corpus by
# accident: the loader skips them unless a build asks for them explicitly (tl-data build
# --include-pending), which is for inspection and dry runs, not for a model that ships.
PENDING = "pending_clinician"
# Rows the AI clinical review has passed. Not a human approval: held back unless the build sets
# ACCEPT_AI_REVIEW_ENV, and tagged so every corpus and model built from them can be traced.
AI_REVIEWED = "ai_clinical_review"
APPROVED = "approved"
REVIEW_STATUSES = frozenset({PENDING, AI_REVIEWED, APPROVED})
ACCEPT_AI_REVIEW_ENV = "TL_ACCEPT_AI_CLINICAL_REVIEW"


def accept_ai_review() -> bool:
    """Whether this build trains on rows that only the AI clinical review has passed."""
    return os.environ.get(ACCEPT_AI_REVIEW_ENV, "").strip().lower() in {"1", "true", "yes"}


def is_pending(row: dict) -> bool:
    """Held back from training: drafted and unreviewed, or AI-reviewed without the opt-in."""
    status = row.get("review_status")
    return status == PENDING or (status == AI_REVIEWED and not accept_ai_review())


def held_back_tags() -> frozenset[str]:
    """Conversation tags a trainer must drop, so a corpus built with --include-pending (or with the
    opt-in, then trained without it) still cannot put held-back rows into a model."""
    tags = {f"review:{PENDING}"}
    if not accept_ai_review():
        tags.add(f"review:{AI_REVIEWED}")
    return frozenset(tags)


def _review_tags(row: dict) -> list[str]:
    status = row.get("review_status")
    return [f"review:{status}"] if status in (PENDING, AI_REVIEWED) else []


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
            tags=[f"route:{r['route']}", f"category:{r['category']}"] + _review_tags(r),
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
            "Crisis responses (acknowledge, ask directly about safety, then Pakistani helplines by name "
            "and number only: Umang 0311-7786264, Rescue 1122, Madadgaar 1098) and everyday-stress hard "
            "negatives, in English, Roman Urdu and mixed. AI-drafted, checked against the eval safety "
            "rules; not paraphrased from probes. Red-line rows are AI-clinically reviewed only and train "
            f"only with {ACCEPT_AI_REVIEW_ENV}=1."
        ),
        tags=("crisis", "roman-urdu"),
    )
)
