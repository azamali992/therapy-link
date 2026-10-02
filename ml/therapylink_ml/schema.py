from __future__ import annotations

import hashlib
import re
from typing import Literal

from pydantic import BaseModel, Field

Role = Literal["system", "user", "assistant"]
Lang = Literal["en", "ur", "ur-roman", "mixed"]
Split = Literal["train", "val", "test"]

_WS = re.compile(r"[ \t ]+")
_NL = re.compile(r"\n{3,}")


def clean_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = _WS.sub(" ", text)
    text = "\n".join(line.strip() for line in text.split("\n"))
    text = _NL.sub("\n\n", text)
    return text.strip()


def stable_id(*parts: str) -> str:
    return hashlib.sha1("\x1f".join(parts).encode("utf-8")).hexdigest()[:16]


class Message(BaseModel):
    role: Role
    content: str
    strategy: str | None = None


def normalise_messages(messages: list[Message], max_turns: int | None = None) -> list[Message]:
    """Put a conversation in the one shape every consumer requires.

    Starts on user, strictly alternates user/assistant, ends on assistant. Chat templates reject
    anything else, and the failure only surfaces deep inside a training run — so this is enforced
    centrally rather than trusted to each loader. Consecutive same-role turns are merged rather
    than dropped, because a speaker's turn split across rows is one turn.
    """
    merged: list[Message] = []
    for m in messages:
        if not m.content.strip():
            continue
        if merged and merged[-1].role == m.role:
            prev = merged[-1]
            merged[-1] = Message(
                role=prev.role,
                content=f"{prev.content}\n{m.content}",
                strategy=prev.strategy or m.strategy,
            )
        else:
            merged.append(m)

    if max_turns is not None and len(merged) > max_turns:
        merged = merged[-max_turns:]
    while merged and merged[0].role != "user":
        merged.pop(0)
    while merged and merged[-1].role != "assistant":
        merged.pop()
    return merged


class Conversation(BaseModel):
    """One training example for Eve: a multi-turn exchange ending on an assistant turn."""

    id: str
    source: str
    lang: Lang = "en"
    messages: list[Message]
    tags: list[str] = Field(default_factory=list)
    quality: float | None = None
    synthetic: bool | None = None
    split: Split | None = None
    # Memory and summary notes the app folds in after the system prompt (prompts.MEMORY_HEADER /
    # SUMMARY_HEADER). Present on the few conversations written to teach the model to use them.
    notes: str | None = None

    def user_text(self) -> str:
        return "\n".join(m.content for m in self.messages if m.role == "user")

    def assistant_text(self) -> str:
        return "\n".join(m.content for m in self.messages if m.role == "assistant")

    def dedupe_key(self) -> str:
        return stable_id(
            clean_text(self.user_text()).lower()[:512],
            clean_text(self.assistant_text()).lower()[:512],
        )


Task = Literal["emotion", "crisis", "valence", "condition"]


class LabeledText(BaseModel):
    """One training example for Guardian: a text and its labels for a named task."""

    id: str
    source: str
    lang: Lang = "en"
    text: str
    task: Task
    labels: list[str]
    split: Split | None = None

    def dedupe_key(self) -> str:
        return stable_id(self.task, clean_text(self.text).lower()[:512])
