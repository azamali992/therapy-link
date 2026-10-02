import asyncio
import os
import sqlite3 as _sqlite3
from collections.abc import Mapping
from datetime import UTC, datetime
from pathlib import Path

SQLITE_MEMORY = "sqlite+aiosqlite:///:memory:"


def pick_test_database_url(env: Mapping[str, str]) -> str | None:
    """The Postgres database the suite should run against, or None for in-memory sqlite.
    Only TL_TEST_DATABASE_URL opts the suite into Postgres: TL_DATABASE_URL is the production
    URL and must never be accidentally wiped by the test runner."""
    url = env.get("TL_TEST_DATABASE_URL", "")
    if url.startswith("postgresql"):
        return url
    return None


def prepare_test_database(url: str, upgrade_fn) -> dict[str, int]:
    """Check whether the SQLite database at *url* has any data in non-alembic tables.

    If it does, this is someone's real database: return a {table: row_count} dict and do NOT
    call *upgrade_fn* (protecting real data).  If it is empty or schema-only, call *upgrade_fn*
    (which should run alembic upgrade head) and return {}.
    """
    # Strip the aiosqlite driver prefix to get the raw file path.
    if ":///" in url:
        path = url.split("///", 1)[1]
    else:
        path = url

    if path in (":memory:", ""):
        upgrade_fn()
        return {}

    _SKIP = {"alembic_version", "sqlite_sequence", "sqlite_master"}
    try:
        with _sqlite3.connect(path) as conn:
            tables = [
                r[0]
                for r in conn.execute(
                    "SELECT name FROM sqlite_master WHERE type='table'"
                ).fetchall()
                if r[0] not in _SKIP
            ]
            filled: dict[str, int] = {}
            for t in tables:
                try:
                    n = conn.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
                    if n:
                        filled[t] = n
                except Exception:
                    pass
            if filled:
                return filled
    except Exception:
        pass

    upgrade_fn()
    return {}


PG_URL = pick_test_database_url(os.environ)

# Settings keep reading sqlite even on a Postgres run: the dev auth bypass the tests sign in with is
# refused on any real database. Only the engine the app fixture installs points at Postgres.
os.environ["TL_DATABASE_URL"] = SQLITE_MEMORY
os.environ["TL_DEV_AUTH_BYPASS"] = "true"

import pytest  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import StaticPool, func, select, text, update  # noqa: E402
from sqlalchemy.ext.asyncio import async_sessionmaker  # noqa: E402

from therapylink_api import db  # noqa: E402
from therapylink_api.db import Base  # noqa: E402
from therapylink_api.main import create_app  # noqa: E402
from therapylink_api.models import ClinicianProfile  # noqa: E402
from therapylink_api.settings import get_settings  # noqa: E402


@pytest.fixture(autouse=True)
def _fresh_settings():
    # Tests that monkeypatch TL_* variables need the cached Settings rebuilt, before and after.
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


async def _row_counts(url: str) -> dict[str, int]:
    engine = db.make_engine(url)
    try:
        async with engine.connect() as conn:
            return {t.name: await conn.scalar(select(func.count()).select_from(t)) for t in Base.metadata.sorted_tables}
    finally:
        await engine.dispose()


async def _truncate(url: str) -> None:
    # Its own engine: a test may have disposed the app's.
    engine = db.make_engine(url)
    names = ", ".join(f'"{t.name}"' for t in Base.metadata.sorted_tables)
    try:
        async with engine.begin() as conn:
            await conn.execute(text(f"TRUNCATE {names} RESTART IDENTITY CASCADE"))
    finally:
        await engine.dispose()


@pytest.fixture(scope="session", autouse=True)
def _postgres_schema(pytestconfig):
    """On a Postgres run, build the schema the way production does (alembic, not create_all) once
    per session. Sync and session-scoped on purpose: env.py starts its own event loop."""
    if PG_URL is None:
        return
    from alembic.config import Config

    from alembic import command

    cfg = Config()  # no ini file: env.py would otherwise reconfigure logging for the whole run
    cfg.set_main_option("script_location", str(Path(__file__).resolve().parents[1] / "alembic"))
    mp = pytest.MonkeyPatch()
    mp.setenv("TL_DATABASE_URL", PG_URL)
    get_settings.cache_clear()
    try:
        command.upgrade(cfg, "head")
    finally:
        mp.undo()
        get_settings.cache_clear()
    # Every test ends by truncating every table. Rows already here mean this is someone's real
    # database, not a scratch one: stop rather than wipe it.
    filled = {name: n for name, n in asyncio.run(_row_counts(PG_URL)).items() if n}
    if filled:
        pytest.exit(f"test database {PG_URL.rsplit('@', 1)[-1]} is not empty ({filled}); point TL_TEST_DATABASE_URL at a scratch database", returncode=2)


@pytest.fixture
async def app():
    if PG_URL is None:
        db._engine = db.make_engine(SQLITE_MEMORY, poolclass=StaticPool, connect_args={"check_same_thread": False})
        db._sessionmaker = async_sessionmaker(db._engine, expire_on_commit=False)
        await db.create_all()
    else:
        db._engine = db.make_engine(PG_URL, **db.engine_kwargs(PG_URL))
        db._sessionmaker = async_sessionmaker(db._engine, expire_on_commit=False)
    yield create_app()
    await db.dispose()
    if PG_URL is not None:
        await _truncate(PG_URL)


@pytest.fixture
async def client(app):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


def as_user(uid: str) -> dict[str, str]:
    return {"X-Dev-Uid": uid}


async def verify_clinician(uid: str) -> None:
    async with db.sessionmaker()() as s:
        await s.execute(update(ClinicianProfile).where(ClinicianProfile.uid == uid).values(verified_at=datetime.now(UTC)))
        await s.commit()


async def verified_clinician(client, uid: str = "doc") -> str:
    """Register uid as a clinician, approve them, and return their invite code."""
    await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=as_user(uid))
    await verify_clinician(uid)
    return (await client.get("/me", headers=as_user(uid))).json()["invite_code"]


async def linked(client, patient: str, clinician: str = "doc", accept: bool = True, **share: bool) -> str:
    """A care link from patient to an approved clinician, accepted unless told otherwise, with the
    given share_* flags. Returns its id."""
    code = (await client.get("/me", headers=as_user(clinician))).json()["invite_code"] or await verified_clinician(client, clinician)
    r = await client.post("/care/links", json={"code": code}, headers=as_user(patient))
    assert r.status_code == 201, r.text
    link_id = r.json()["id"]
    if accept:
        assert (await client.post(f"/clinician/requests/{link_id}/accept", headers=as_user(clinician))).status_code == 200
    if share:
        await client.patch(f"/care/links/{link_id}/consent", json={f"share_{k}": v for k, v in share.items()}, headers=as_user(patient))
    return link_id
