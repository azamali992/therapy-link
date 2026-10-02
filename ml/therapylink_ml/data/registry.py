from __future__ import annotations

from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from typing import Literal

from therapylink_ml.schema import Conversation, LabeledText

Kind = Literal["conversation", "labeled"]
Loader = Callable[[], Iterator[Conversation] | Iterator[LabeledText]]


@dataclass(frozen=True)
class DatasetInfo:
    key: str
    kind: Kind
    license: str
    commercial_ok: bool
    location: str
    citation: str
    loader: Loader
    lang: str = "en"
    synthetic: bool | None = None
    notes: str = ""
    tags: tuple[str, ...] = field(default_factory=tuple)


_REGISTRY: dict[str, DatasetInfo] = {}


def register(info: DatasetInfo) -> DatasetInfo:
    if info.key in _REGISTRY:
        raise ValueError(f"duplicate dataset key {info.key!r}")
    _REGISTRY[info.key] = info
    return info


def get(key: str) -> DatasetInfo:
    _ensure_loaded()
    return _REGISTRY[key]


def all_datasets(kind: Kind | None = None) -> list[DatasetInfo]:
    _ensure_loaded()
    items = list(_REGISTRY.values())
    return [d for d in items if kind is None or d.kind == kind]


def _ensure_loaded() -> None:
    if _REGISTRY:
        return
    from therapylink_ml.data import loaders  # noqa: F401  (registers on import)
