"""The migrations, not create_all, build production. They must reach the models and come back down."""

import io
import io
from pathlib import Path

from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from sqlalchemy import create_engine

from alembic import command
from therapylink_api import models  # noqa: F401
from therapylink_api.db import Base
from therapylink_api.settings import get_settings

API = Path(__file__).resolve().parents[1]


def _alembic(monkeypatch, url: str) -> Config:
    monkeypatch.setenv("TL_DATABASE_URL", url)
    get_settings.cache_clear()
    cfg = Config()  # no ini file: env.py would otherwise reconfigure logging for the whole test run
    cfg.set_main_option("script_location", str(API / "alembic"))
    return cfg


def test_upgrade_matches_models_and_downgrades_cleanly(tmp_path, monkeypatch):
    path = tmp_path / "m.db"
    cfg = _alembic(monkeypatch, f"sqlite+aiosqlite:///{path.as_posix()}")
    command.upgrade(cfg, "head")

    sync = create_engine(f"sqlite:///{path.as_posix()}")
    with sync.connect() as conn:
        diff = compare_metadata(MigrationContext.configure(conn), Base.metadata)
    assert diff == [], f"models and migrations disagree: {diff}"

    command.downgrade(cfg, "base")
    with sync.connect() as conn:
        tables = conn.exec_driver_sql("SELECT name FROM sqlite_master WHERE type='table'").scalars().all()
    assert set(tables) <= {"alembic_version"}
    command.upgrade(cfg, "head")
    sync.dispose()


def test_data_migrations(tmp_path, monkeypatch):
    """Rows written under the old schema come through: links get a shared_from, BDI-II goes."""
    path = tmp_path / "d.db"
    cfg = _alembic(monkeypatch, f"sqlite+aiosqlite:///{path.as_posix()}")
    command.upgrade(cfg, "b2d4f6a81023")
    sync = create_engine(f"sqlite:///{path.as_posix()}")
    with sync.begin() as conn:
        for uid in ("p", "d"):
            conn.exec_driver_sql(f"INSERT INTO users (uid, role, locale) VALUES ('{uid}', 'patient', 'en')")
        conn.exec_driver_sql(
            "INSERT INTO care_links (id, patient_uid, clinician_uid, status, share_assessments, share_mood_trend, share_summaries, share_journal, created_at, updated_at)"
            " VALUES ('l1', 'p', 'd', 'active', 0, 0, 0, 1, '2026-01-01 00:00:00', '2026-01-01 00:00:00')"
        )
        for i, instrument in enumerate(("phq9", "bdi2")):
            conn.exec_driver_sql(
                f"INSERT INTO assessments (id, patient_uid, instrument, answers, score, band, flags) VALUES ('a{i}', 'p', '{instrument}', '[]', 0, 'minimal', '[]')"
            )

    command.upgrade(cfg, "head")
    with sync.connect() as conn:
        assert conn.exec_driver_sql("SELECT status, shared_from FROM care_links").one() == ("active", "2026-01-01 00:00:00")
        assert conn.exec_driver_sql("SELECT instrument FROM assessments").scalars().all() == ["phq9"]
        assert conn.exec_driver_sql("SELECT email_verified FROM users WHERE uid = 'p'").scalar() == 0
    sync.dispose()


def test_postgres_downgrade_removes_types_and_rules(monkeypatch):
    """Rendered offline, so no server is needed; CI's api-postgres job runs the real round trip.
    Enum types outlive their tables on Postgres and would break the next upgrade."""
    monkeypatch.setenv("TL_DATABASE_URL", "postgresql+asyncpg://tl:tl@localhost:5432/therapylink")
    get_settings.cache_clear()
    out = io.StringIO()
    cfg = Config(output_buffer=out)
    cfg.set_main_option("script_location", str(API / "alembic"))
    command.downgrade(cfg, "head:base", sql=True)
    sql = out.getvalue()
    for stmt in (
        "CREATE TYPE instrument AS ENUM ('phq9', 'gad7', 'bdi2')",
        "DROP RULE IF EXISTS access_log_no_update ON access_log",
        "DROP RULE IF EXISTS access_log_no_delete ON access_log",
        "DROP TYPE IF EXISTS role",
        "DROP TYPE IF EXISTS instrument",
        "DROP TYPE IF EXISTS linkstatus",
    ):
        assert stmt in sql
    # Rules go before their table, types after theirs.
    assert sql.index("DROP RULE IF EXISTS access_log_no_update") < sql.index("DROP TABLE access_log")
    assert sql.index("DROP TABLE users") < sql.index("DROP TYPE IF EXISTS role")
