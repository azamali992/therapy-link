"""Per-uid rate limits. In memory for now: one process, lost on restart. Anything with a `take`
method can stand in, so a Redis-backed limiter can replace it when there is more than one instance."""

from __future__ import annotations

import time
from collections.abc import Callable
from typing import Protocol


class RateLimiter(Protocol):
    def take(self, key: str) -> float:
        """Spend one token for key. Returns 0 if allowed, else the seconds until a token is free."""
        ...


class TokenBucket:
    """`capacity` requests in a burst, refilled evenly so a key gets `capacity` per `period_s`."""

    # Past this many keys, forget the ones that have refilled completely: they are back to default.
    _PRUNE_AT = 10_000

    def __init__(self, capacity: int, period_s: float, clock: Callable[[], float] = time.monotonic):
        self.capacity = capacity
        self.rate = capacity / period_s
        self._clock = clock
        self._buckets: dict[str, tuple[float, float]] = {}  # key -> (tokens, updated_at)

    def _level(self, key: str, now: float) -> float:
        tokens, at = self._buckets.get(key, (self.capacity, now))
        return min(self.capacity, tokens + (now - at) * self.rate)

    def take(self, key: str) -> float:
        now = self._clock()
        tokens = self._level(key, now)
        if tokens < 1:
            self._buckets[key] = (tokens, now)
            return (1 - tokens) / self.rate
        self._buckets[key] = (tokens - 1, now)
        if len(self._buckets) > self._PRUNE_AT:
            self._buckets = {k: v for k, v in self._buckets.items() if self._level(k, now) < self.capacity}
        return 0.0
