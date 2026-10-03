import json
import logging
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api import db, requestid
from therapylink_api.ratelimit import DualTokenBucket, RedisDualLimiter, RedisRateLimiter, TokenBucket
from therapylink_api.routers import account_page, assessments, care, clinician, guardian, inference, journal, me, mood
from therapylink_api.routers import admin as admin_router
from therapylink_api.routers.inference import _InferenceTracker
from therapylink_api.settings import check_config, get_settings

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# JSON log formatter
# ---------------------------------------------------------------------------


class _JsonFormatter(logging.Formatter):
    """Emit every log record as a single JSON line — no bodies, no raw UIDs."""

    def format(self, record: logging.LogRecord) -> str:
        doc = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        # Structured extras set by the logging middleware.
        for key in ("request_id", "method", "route", "status", "latency_ms", "uid_hash"):
            if key in record.__dict__:
                doc[key] = record.__dict__[key]
        if record.exc_info:
            doc["exc"] = self.formatException(record.exc_info)
        return json.dumps(doc, default=str)


def _configure_json_logging() -> None:
    fmt = _JsonFormatter()
    root = logging.getLogger()
    if not root.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(fmt)
        root.addHandler(handler)
    else:
        for h in root.handlers:
            h.setFormatter(fmt)
    root.setLevel(logging.INFO)


# ---------------------------------------------------------------------------
# Lifespan & app factory
# ---------------------------------------------------------------------------


@asynccontextmanager
async def lifespan(app: FastAPI):
    if get_settings().database_url.startswith("sqlite"):
        await db.create_all()
    yield
    # Close any Redis connection pool we opened.
    redis = getattr(app.state, "_redis_client", None)
    if redis is not None:
        await redis.aclose()
    await db.dispose()


def _make_limiters(settings):
    """Return (inference_limiter, write_limiter, ip_limiter).

    When TL_REDIS_URL is set, all three are Redis-backed and shared across workers.
    Otherwise they are in-memory token buckets (per worker, reset on restart).
    """
    if settings.redis_url:
        import redis.asyncio as aioredis

        client = aioredis.from_url(settings.redis_url, decode_responses=True)
        inference_limiter = RedisDualLimiter(
            short=RedisRateLimiter(
                client, settings.inference_rate_capacity, int(settings.inference_rate_period_s), "inf"
            ),
            daily=RedisRateLimiter(client, settings.inference_daily_cap, 86400, "inf_day"),
        )
        write_limiter = RedisRateLimiter(client, settings.write_rate_capacity, 60, "write")
        ip_limiter = RedisRateLimiter(client, 60, 60, "ip")
        return inference_limiter, write_limiter, ip_limiter, client
    else:
        inference_limiter = DualTokenBucket(
            short=TokenBucket(settings.inference_rate_capacity, settings.inference_rate_period_s),
            daily=TokenBucket(settings.inference_daily_cap, 86400.0),
        )
        write_limiter = TokenBucket(settings.write_rate_capacity, 60.0)
        ip_limiter = TokenBucket(60, 60.0)
        return inference_limiter, write_limiter, ip_limiter, None


def create_app() -> FastAPI:
    settings = get_settings()
    check_config(settings)
    _configure_json_logging()

    app = FastAPI(title="TherapyLink API", version="0.1.0", lifespan=lifespan)
    inference_limiter, write_limiter, ip_limiter, redis_client = _make_limiters(settings)
    app.state.chat_limiter = inference_limiter
    app.state.write_limiter = write_limiter
    app.state.ip_limiter = ip_limiter
    if redis_client is not None:
        app.state._redis_client = redis_client
    app.state.inference_tracker = _InferenceTracker(
        settings.inference_max_inflight,
        settings.inference_max_queue,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.middleware("http")(requestid.middleware)
    app.middleware("http")(_ip_rate_limit_middleware)
    app.middleware("http")(_logging_middleware)

    for r in (me, assessments, mood, journal, care, clinician, inference, account_page, guardian, admin_router):
        app.include_router(r.router)

    @app.get("/health", tags=["ops"])
    async def health():
        """Liveness: the process answers. Says nothing about the database."""
        return {"ok": True}

    @app.get("/ready", tags=["ops"])
    async def ready(session: AsyncSession = Depends(db.get_session)):
        """Readiness, for uptime checks: the database answers. Cloud inference is reported as
        configured or not, never called, so a checker can't spend GPU time."""
        try:
            await session.execute(text("SELECT 1"))
        except Exception:
            log.exception("readiness check failed [request %s]", requestid.current())
            return JSONResponse({"ok": False, "db": False}, status_code=503)
        return {"ok": True, "db": True, "cloud_inference": bool(get_settings().inference_base_url)}

    return app


# ---------------------------------------------------------------------------
# Middlewares
# ---------------------------------------------------------------------------

_EXEMPT_IP_PATHS = {"/health", "/ready"}


async def _ip_rate_limit_middleware(request, call_next):
    """Rate-limit unauthenticated requests by IP (no Authorization header).

    Lets monitoring probes through; blocks scanners and brute-force attempts before any
    auth code runs.  Authenticated requests are not affected here — they get per-uid limits.
    """
    auth = request.headers.get("authorization", "")
    path = request.url.path
    if not auth.lower().startswith("bearer ") and path not in _EXEMPT_IP_PATHS:
        ip_limiter = getattr(request.app.state, "ip_limiter", None)
        if ip_limiter is not None:
            ip = request.client.host if request.client else "unknown"
            from therapylink_api.ratelimit import atake

            wait = await atake(ip_limiter, ip)
            if wait:
                import math

                return JSONResponse(
                    {"detail": "too many requests"},
                    status_code=429,
                    headers={"Retry-After": str(math.ceil(wait))},
                )
    return await call_next(request)


async def _logging_middleware(request, call_next):
    """Emit one structured JSON log line per request.

    Logs route template (not actual path), status, latency, and a hashed uid.
    Never logs request or response bodies.
    """
    start = time.monotonic()
    response = await call_next(request)
    latency_ms = round((time.monotonic() - start) * 1000, 1)

    route = request.scope.get("route")
    template = getattr(route, "path", request.url.path)
    uid_hash = getattr(request.state, "uid_hash", None)

    log.info(
        "%s %s %s",
        request.method,
        template,
        response.status_code,
        extra={
            "request_id": requestid.current(),
            "method": request.method,
            "route": template,
            "status": response.status_code,
            "latency_ms": latency_ms,
            "uid_hash": uid_hash,
        },
    )
    return response


app = create_app()
