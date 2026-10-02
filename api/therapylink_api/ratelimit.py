"""Rate limiters for TherapyLink.

In-memory default (single-process, resets on restart).  When TL_REDIS_URL is set the same
limiters use Redis so state is shared across workers and survives restarts.

Usage pattern in route handlers:
    wait = _take(limiter, key)   # or await _atake(limiter, key) for async limiters
    if wait:
        raise HTTPException(429, ..., headers={"Retry-After": str(math.ceil(wait))})
"""

from __future__ import annotations

import inspect
import time
from collections.abc import Callable
from typing import Protocol


# ---------------------------------------------------------------------------
# Protocols
# ---------------------------------------------------------------------------

class RateLimiter(Protocol):
    def take(self, key: str) -> float:
        """Spend one token for key. Returns 0 if allowed, else the seconds until a token is free."""
        ...


# ---------------------------------------------------------------------------
# In-memory token bucket
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Dual-window in-memory inference limiter (short window + daily cap)
# ---------------------------------------------------------------------------

class DualTokenBucket:
    """Enforces two independent token buckets simultaneously.

    A call is allowed only when *both* buckets have capacity.  On success a token is taken from
    each; on failure only the wait time is returned (no token consumed).
    """

    def __init__(self, short: TokenBucket, daily: TokenBucket):
        self._short = short
        self._daily = daily

    def take(self, key: str) -> float:
        now = self._short._clock()
        # Peek without consuming.
        short_level = self._short._level(key + ":s", now)
        daily_level = self._daily._level(key + ":d", now)
        if short_level < 1:
            return (1 - short_level) / self._short.rate
        if daily_level < 1:
            return (1 - daily_level) / self._daily.rate
        # Both have capacity: consume atomically (same event loop tick → no real race).
        self._short.take(key + ":s")
        self._daily.take(key + ":d")
        return 0.0


# ---------------------------------------------------------------------------
# Redis-backed sliding window (async)
# ---------------------------------------------------------------------------

class RedisRateLimiter:
    """Sliding-window rate limiter backed by Redis ZADD/ZCARD.

    Works across processes and survives app restarts.  Falls back gracefully if Redis is
    unavailable: logs a warning and allows the request (fail-open).
    """

    def __init__(self, redis_client, capacity: int, window_s: int, name: str = "rl"):
        self._redis = redis_client
        self.capacity = capacity
        self.window_s = window_s
        self._name = name

    async def take(self, key: str) -> float:
        import logging
        log = logging.getLogger(__name__)
        redis_key = f"tl:{self._name}:{key}"
        now = time.time()
        cutoff = now - self.window_s
        try:
            pipe = self._redis.pipeline()
            pipe.zremrangebyscore(redis_key, 0, cutoff)
            pipe.zcard(redis_key)
            pipe.zadd(redis_key, {f"{now:.6f}": now})
            pipe.expire(redis_key, self.window_s * 2)
            results = await pipe.execute()
            count_before = results[1]  # card before adding this request
            if count_before >= self.capacity:
                # Roll back: remove the entry we just added.
                await self._redis.zrem(redis_key, f"{now:.6f}")
                return float(self.window_s)
            return 0.0
        except Exception as e:
            log.warning("Redis rate-limit check failed for %s: %s — allowing request (fail-open)", key, e)
            return 0.0


class RedisDualLimiter:
    """Two Redis rate limiters that must both allow a request."""

    def __init__(self, short: RedisRateLimiter, daily: RedisRateLimiter):
        self._short = short
        self._daily = daily

    async def take(self, key: str) -> float:
        # Peek the short window: zcard without adding yet.
        short_key = f"tl:{self._short._name}:{key}:s"
        daily_key = f"tl:{self._daily._name}:{key}:d"
        now = time.time()
        import logging
        log = logging.getLogger(__name__)
        try:
            pipe = self._short._redis.pipeline()
            pipe.zremrangebyscore(short_key, 0, now - self._short.window_s)
            pipe.zcard(short_key)
            pipe.zremrangebyscore(daily_key, 0, now - self._daily.window_s)
            pipe.zcard(daily_key)
            results = await pipe.execute()
            short_count = results[1]
            daily_count = results[3]
            if short_count >= self._short.capacity:
                return float(self._short.window_s)
            if daily_count >= self._daily.capacity:
                return float(self._daily.window_s)
            # Both under limit: add to both.
            pipe2 = self._short._redis.pipeline()
            member = f"{now:.6f}"
            pipe2.zadd(short_key, {member: now})
            pipe2.expire(short_key, self._short.window_s * 2)
            pipe2.zadd(daily_key, {member: now})
            pipe2.expire(daily_key, self._daily.window_s * 2)
            await pipe2.execute()
            return 0.0
        except Exception as e:
            log.warning("Redis dual rate-limit check failed: %s — allowing request (fail-open)", e)
            return 0.0


# ---------------------------------------------------------------------------
# Helper: call sync or async limiter uniformly from an async context
# ---------------------------------------------------------------------------

async def atake(limiter, key: str) -> float:
    """Call take() on either a sync (TokenBucket) or async (Redis) limiter."""
    if inspect.iscoroutinefunction(limiter.take):
        return await limiter.take(key)
    return limiter.take(key)
