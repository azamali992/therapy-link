import importlib.util
from pathlib import Path

import pytest
from firebase_admin import auth as firebase_auth
from sqlalchemy import func, select

from therapylink_api import auth, db, firebase
from therapylink_api.auth import _ensure_user
from therapylink_api.db import engine_kwargs
from therapylink_api.models import ClinicianProfile, User
from therapylink_api.settings import get_settings

BEARER = {"Authorization": "Bearer t"}


@pytest.fixture
def token(monkeypatch):
    """Stand-in for Firebase: the claims the next verified token carries, or the error it raises."""
    claims = {"uid": "fb1", "email": "doc@example.com", "email_verified": False}

    def verify(tok, app=None):
        if isinstance(claims.get("raise"), Exception):
            raise claims["raise"]
        return claims

    monkeypatch.setattr(firebase, "app", lambda: None)
    monkeypatch.setattr(firebase_auth, "verify_id_token", verify)
    return claims


async def test_firebase_token_signs_in_and_tracks_email_verification(client, token):
    r = await client.get("/me", headers=BEARER)
    assert r.status_code == 200 and r.json()["uid"] == "fb1"
    async with db.sessionmaker()() as s:
        assert (await s.get(User, "fb1")).email_verified is False
    token["email_verified"] = True
    await client.get("/me", headers=BEARER)
    async with db.sessionmaker()() as s:
        assert (await s.get(User, "fb1")).email_verified is True


async def test_token_errors_map_to_401_and_cert_outages_to_503(client, token):
    token["raise"] = firebase_auth.InvalidIdTokenError("bad signature")
    assert (await client.get("/me", headers=BEARER)).json() == {"detail": "invalid token"}
    token["raise"] = ValueError("Illegal ID token provided")
    assert (await client.get("/me", headers=BEARER)).status_code == 401
    token["raise"] = firebase_auth.CertificateFetchError("certs unreachable", cause=None)
    r = await client.get("/me", headers=BEARER)
    assert r.status_code == 503 and "certs" not in r.text
    assert (await client.get("/me")).status_code == 401  # no header at all


async def test_auto_approval_waits_for_a_verified_email(client, token, monkeypatch):
    monkeypatch.setenv("TL_DEV_AUTO_VERIFY_CLINICIANS", "true")
    get_settings.cache_clear()
    r = await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=BEARER)
    assert r.status_code == 201 and r.json()["clinician_verified"] is False
    token["email_verified"] = True
    r = await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=BEARER)
    assert r.json()["clinician_verified"] is True


def _script():
    path = Path(__file__).resolve().parents[1] / "scripts" / "verify_clinician.py"
    spec = importlib.util.spec_from_file_location("verify_clinician", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


async def test_approval_script_refuses_an_unverified_email(client, token, capsys):
    await client.post("/me/clinician", json={"license_no": "PMC-1"}, headers=BEARER)
    script = _script()
    assert await script._set("doc@example.com", revoke=False) == 1
    assert "not verified their email" in capsys.readouterr().err
    token["email_verified"] = True
    await client.get("/me", headers=BEARER)
    assert await script._set("doc@example.com", revoke=False) == 0
    async with db.sessionmaker()() as s:
        assert (await s.get(ClinicianProfile, "fb1")).verified_at is not None


async def test_user_insert_tolerates_a_race(app):
    async with db.sessionmaker()() as s:
        await _ensure_user(s, "u1", None, None, False)
        await _ensure_user(s, "u1", "late@example.com", None, True)  # the loser of a race: no error
        assert await s.scalar(select(func.count()).select_from(User)) == 1


def test_pooled_postgres_disables_prepared_statement_caches():
    neon = "postgresql+asyncpg://u:p@ep-cool-123-pooler.ap-southeast-1.aws.neon.tech/db?ssl=require"
    kw = engine_kwargs(neon)
    assert kw["connect_args"]["statement_cache_size"] == 0 and kw["connect_args"]["prepared_statement_cache_size"] == 0
    names = {kw["connect_args"]["prepared_statement_name_func"]() for _ in range(3)}
    assert len(names) == 3
    assert "connect_args" not in engine_kwargs(neon.replace("-pooler", ""))
    assert "connect_args" in engine_kwargs("postgresql+asyncpg://u:p@db/x", pooled=True)
    assert "connect_args" not in engine_kwargs("sqlite+aiosqlite:///x.db", pooled=True)


async def test_ready_checks_the_database(app, client):
    r = await client.get("/ready")
    assert r.status_code == 200 and r.json() == {"ok": True, "db": True, "cloud_inference": False}

    class Down:
        async def execute(self, *a, **kw):
            raise OSError("connection refused to db.internal")

    async def broken():
        yield Down()

    app.dependency_overrides[db.get_session] = broken
    r = await client.get("/ready")
    assert r.status_code == 503 and r.json() == {"ok": False, "db": False}
    assert (await client.get("/health")).status_code == 200


def test_verify_goes_through_the_admin_sdk(monkeypatch):
    seen = {}
    monkeypatch.setattr(firebase, "app", lambda: "the-app")
    monkeypatch.setattr(
        firebase_auth, "verify_id_token", lambda tok, app=None: seen.update(tok=tok, app=app) or {"uid": "x"}
    )
    assert auth._verify("abc") == {"uid": "x"} and seen == {"tok": "abc", "app": "the-app"}
