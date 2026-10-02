"""Which database the suite runs on: Postgres when one is named, in-memory sqlite otherwise."""

import sqlite3

from conftest import pick_test_database_url, prepare_test_database

PG = "postgresql+asyncpg://tl:tl@localhost:5432/therapylink"


def test_unset_means_sqlite():
    assert pick_test_database_url({}) is None
    assert pick_test_database_url({"TL_TEST_DATABASE_URL": "", "TL_DATABASE_URL": ""}) is None


def test_sqlite_urls_mean_sqlite():
    assert pick_test_database_url({"TL_DATABASE_URL": "sqlite+aiosqlite:///./dev.db"}) is None
    assert pick_test_database_url({"TL_TEST_DATABASE_URL": "sqlite+aiosqlite:///:memory:"}) is None


def test_postgres_test_url_is_used():
    assert pick_test_database_url({"TL_TEST_DATABASE_URL": PG}) == PG
    other = "postgresql+asyncpg://tl:tl@localhost:5432/other"
    assert pick_test_database_url({"TL_TEST_DATABASE_URL": PG, "TL_DATABASE_URL": other}) == PG


def test_app_database_url_never_opts_in():
    # A shell with the production URL exported must not have the suite migrate and wipe it.
    assert pick_test_database_url({"TL_DATABASE_URL": PG}) is None
    assert pick_test_database_url({"TL_TEST_DATABASE_URL": "sqlite+aiosqlite:///x.db", "TL_DATABASE_URL": PG}) is None


def _database(tmp_path, *statements: str) -> str:
    path = tmp_path / "t.db"
    with sqlite3.connect(path) as conn:
        for sql in statements:
            conn.execute(sql)
    return f"sqlite+aiosqlite:///{path.as_posix()}"


def test_a_database_with_rows_is_refused_before_any_migration(tmp_path):
    url = _database(
        tmp_path,
        "CREATE TABLE assessments (id INTEGER)",
        "INSERT INTO assessments VALUES (1)",
        "CREATE TABLE users (id INTEGER)",
    )
    upgrades = []
    assert prepare_test_database(url, lambda: upgrades.append(1)) == {"assessments": 1}
    assert upgrades == []


def test_an_empty_or_scratch_database_is_migrated(tmp_path):
    # A fresh database has no tables; a scratch one from the last run keeps only its alembic_version row.
    upgrades = []
    assert prepare_test_database(_database(tmp_path), lambda: upgrades.append(1)) == {}
    url = _database(
        tmp_path,
        "CREATE TABLE alembic_version (version_num TEXT)",
        "INSERT INTO alembic_version VALUES ('head')",
        "CREATE TABLE users (id INTEGER)",
    )
    assert prepare_test_database(url, lambda: upgrades.append(1)) == {}
    assert upgrades == [1, 1]
