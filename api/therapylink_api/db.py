import uuid
from collections.abc import AsyncIterator

from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from therapylink_api.settings import get_settings


class Base(DeclarativeBase):
    pass


_engine = None
_sessionmaker: async_sessionmaker[AsyncSession] | None = None


def _sqlite_foreign_keys(dbapi_conn, _record) -> None:
    # sqlite ignores ON DELETE CASCADE unless each connection asks for it. Account deletion relies on it.
    cur = dbapi_conn.cursor()
    cur.execute("PRAGMA foreign_keys=ON")
    cur.close()


def make_engine(url: str, **kwargs) -> AsyncEngine:
    eng = create_async_engine(url, **kwargs)
    if eng.dialect.name == "sqlite":
        event.listen(eng.sync_engine, "connect", _sqlite_foreign_keys)
    return eng


def is_pooled(url: str) -> bool:
    """A PgBouncer-style pooler in transaction mode, such as Neon's -pooler endpoint."""
    return "-pooler." in url or "pgbouncer=true" in url.lower()


def engine_kwargs(url: str, pooled: bool | None = None) -> dict:
    kwargs: dict = {"pool_pre_ping": True}
    if url.startswith("postgresql+asyncpg") and (is_pooled(url) if pooled is None else pooled):
        # The pooler hands each transaction to any server connection, so a statement prepared on
        # one isn't there on the next ("prepared statement ... does not exist / already exists").
        # Turn off both caches and give every statement a unique name.
        kwargs["connect_args"] = {
            "statement_cache_size": 0,
            "prepared_statement_cache_size": 0,
            "prepared_statement_name_func": lambda: f"__tl_{uuid.uuid4().hex}__",
        }
        # The pooler does the real pooling; keep this side small so instances x pool fits Neon's limit.
        kwargs |= {"pool_size": 5, "max_overflow": 5}
    return kwargs


def engine():
    global _engine, _sessionmaker
    if _engine is None:
        s = get_settings()
        _engine = make_engine(s.database_url, **engine_kwargs(s.database_url, s.database_pooled))
        _sessionmaker = async_sessionmaker(_engine, expire_on_commit=False)
    return _engine


def sessionmaker() -> async_sessionmaker[AsyncSession]:
    engine()
    assert _sessionmaker is not None
    return _sessionmaker


async def get_session() -> AsyncIterator[AsyncSession]:
    async with sessionmaker()() as session:
        yield session


async def create_all() -> None:
    from therapylink_api import models  # noqa: F401

    async with engine().begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def dispose() -> None:
    global _engine, _sessionmaker
    if _engine is not None:
        await _engine.dispose()
        _engine, _sessionmaker = None, None
