import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from therapylink_api import db, requestid
from therapylink_api.ratelimit import TokenBucket
from therapylink_api.routers import account_page, assessments, care, clinician, inference, journal, me, mood
from therapylink_api.settings import check_config, get_settings

log = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if get_settings().database_url.startswith("sqlite"):
        await db.create_all()
    yield
    await db.dispose()


def create_app() -> FastAPI:
    settings = get_settings()
    check_config(settings)
    app = FastAPI(title="TherapyLink API", version="0.1.0", lifespan=lifespan)
    app.state.chat_limiter = TokenBucket(settings.inference_rate_capacity, settings.inference_rate_period_s)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.middleware("http")(requestid.middleware)
    for r in (me, assessments, mood, journal, care, clinician, inference, account_page):
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


app = create_app()
