from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterator

from therapylink_ml.data.hf import load_hf
from therapylink_ml.data.registry import DatasetInfo, register
from therapylink_ml.schema import Conversation, Message, clean_text, normalise_messages, stable_id

HF_ID = "facebook/empathetic_dialogues"


def _fix(text: str) -> str:
    return clean_text(text.replace("_comma_", ","))


def load() -> Iterator[Conversation]:
    ds = load_hf(HF_ID)
    for split_name in ds:
        convs: dict[str, list[dict]] = defaultdict(list)
        for row in ds[split_name]:
            convs[row["conv_id"]].append(row)
        for conv_id, rows in convs.items():
            rows.sort(key=lambda r: r["utterance_idx"])
            messages = [
                Message(
                    role="user" if r["utterance_idx"] % 2 == 1 else "assistant",
                    content=_fix(r["utterance"]),
                )
                for r in rows
                if _fix(r["utterance"])
            ]
            # Roles come from utterance_idx parity, so dropping an empty utterance both shifts the
            # opening speaker and leaves two same-role turns adjacent.
            messages = normalise_messages(messages)
            if len(messages) < 2:
                continue
            yield Conversation(
                id=stable_id(HF_ID, split_name, conv_id),
                source="empathetic_dialogues",
                lang="en",
                messages=messages,
                tags=[f"emotion:{rows[0]['context']}"],
                synthetic=False,
            )


register(
    DatasetInfo(
        key="empathetic_dialogues",
        kind="conversation",
        license="CC BY-NC 4.0",
        commercial_ok=False,
        location=f"hf:{HF_ID}",
        citation="Rashkin et al., Towards Empathetic Open-domain Conversation Models, ACL 2019",
        loader=load,
        synthetic=False,
        notes="~25k crowdworker dialogues grounded in one of 32 emotion labels. Listener turns are "
        "empathetic but not clinical — breadth, not technique.",
    )
)
