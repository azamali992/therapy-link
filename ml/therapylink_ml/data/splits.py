from __future__ import annotations

import hashlib
from collections import defaultdict
from collections.abc import Iterable, Sequence
from typing import Protocol, TypeVar

from therapylink_ml.schema import Split


class _Splittable(Protocol):
    id: str
    source: str
    split: Split | None

    def dedupe_key(self) -> str: ...


T = TypeVar("T", bound=_Splittable)


def dedupe(items: Iterable[T]) -> tuple[list[T], int]:
    seen: set[str] = set()
    kept: list[T] = []
    dropped = 0
    for item in items:
        key = item.dedupe_key()
        if key in seen:
            dropped += 1
            continue
        seen.add(key)
        kept.append(item)
    return kept, dropped


def _bucket(seed: int, item_id: str) -> int:
    digest = hashlib.sha1(f"{seed}:{item_id}".encode()).hexdigest()
    return int(digest[:12], 16)


def assign_splits(
    items: Sequence[T],
    *,
    val_frac: float = 0.03,
    test_frac: float = 0.03,
    min_per_split: int = 5,
    seed: int = 13,
    respect_existing: bool = True,
) -> list[T]:
    """Deterministic, per-source stratified split. Items that already carry a split keep it."""
    by_source: dict[str, list[T]] = defaultdict(list)
    for item in items:
        if respect_existing and item.split:
            continue
        by_source[item.source].append(item)

    for source_items in by_source.values():
        source_items.sort(key=lambda it: _bucket(seed, it.id))
        n = len(source_items)
        n_test = max(min_per_split, round(n * test_frac)) if n >= min_per_split * 4 else 0
        n_val = max(min_per_split, round(n * val_frac)) if n >= min_per_split * 4 else 0
        for i, item in enumerate(source_items):
            item.split = "test" if i < n_test else "val" if i < n_test + n_val else "train"

    return list(items)
